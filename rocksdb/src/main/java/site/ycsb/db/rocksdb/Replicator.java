package site.ycsb.db.rocksdb;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import io.grpc.Server;
import io.grpc.ServerBuilder;
import io.grpc.stub.StreamObserver;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;

import site.ycsb.*;
import site.ycsb.RubbleKvStoreServiceGrpc.RubbleKvStoreServiceStub;

import java.util.Properties;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;
import java.io.IOException;
import java.util.concurrent.atomic.LongAccumulator;

/**
 * Replicator in chain replication.
 *
 * @author Haoyu Li.
 */
public class Replicator {
  private final int shardNum;
  private static Properties props;
  private final int port;
  private final Server server;
  private final ManagedChannel[] headChannel;
  private final ManagedChannel[] tailChannel;
  private final RubbleKvStoreServiceStub[] headStub;
  private final RubbleKvStoreServiceStub[] tailStub;
  private final StreamObserver[] observerArray;
  private final ExecutorService threadPoolExecutor = Executors.newFixedThreadPool(16);
  private static final Logger LOGGER = LoggerFactory.getLogger(Replicator.class);
  
  public Replicator() throws IOException {
    this.shardNum = Integer.parseInt(props.getProperty("shard"));
    String[] headNode = new String[shardNum];
    String[] tailNode = new String [shardNum];
    this.headChannel = new ManagedChannel[shardNum];
    this.tailChannel = new ManagedChannel[shardNum];
    this.headStub = new RubbleKvStoreServiceStub[shardNum];
    this.tailStub = new RubbleKvStoreServiceStub[shardNum];
    this.observerArray = new StreamObserver[shardNum];
    this.port = Integer.parseInt(props.getProperty("port"));
    ServerBuilder serverBuilder = ServerBuilder.forPort(port).addService(new RubbleKvStoreService());
    this.server = serverBuilder.build();
    for (int i = 0; i < shardNum; i++) {
      headNode[i] = props.getProperty("head"+(i+1));
      tailNode[i] = props.getProperty("tail"+(i+1));
      this.headChannel[i] = ManagedChannelBuilder.forTarget(headNode[i]).usePlaintext().build();
      this.tailChannel[i] = ManagedChannelBuilder.forTarget(tailNode[i]).usePlaintext().build();
      this.headStub[i] = RubbleKvStoreServiceGrpc.newStub(this.headChannel[i]);
      this.tailStub[i] = RubbleKvStoreServiceGrpc.newStub(this.tailChannel[i]);
    }
  }

  public void start() throws IOException {
    server.start();
    LOGGER.info("Server started, listening on " + port);
    Runtime.getRuntime().addShutdownHook(new Thread() {
      @Override
      public void run() {
        System.err.println("*** shutting down gRPC server since JVM is shutting down");
        try {
          Replicator.this.stop();
        } catch (InterruptedException e) {
          e.printStackTrace(System.err);
        }
        System.err.println("*** server shut down");
      }
    });
  }

  public void stop() throws InterruptedException {
    if (server != null) {
      threadPoolExecutor.shutdownNow();
      server.shutdown().awaitTermination(30, TimeUnit.SECONDS);
    }
    for (int i = 0; i < shardNum; i++) {
      if (headChannel[i] != null) {
        headChannel[i].shutdownNow().awaitTermination(5, TimeUnit.SECONDS);
      }
      if (tailChannel[i] != null) {
        tailChannel[i].shutdownNow().awaitTermination(5, TimeUnit.SECONDS);
      }
    }
  }

  private void blockUntilShutdown() throws InterruptedException {
    if (server != null) {
      server.awaitTermination();
    }
  }
  
  public static void main(String[] args) throws Exception {
    //LOGGER.info("Replicator started");
    props = Client.parseArguments(args);
    Replicator server = new Replicator();
    server.start();
    server.blockUntilShutdown();
  }

  private class RubbleKvStoreService extends RubbleKvStoreServiceGrpc.RubbleKvStoreServiceImplBase {
    private final LongAccumulator observerAccumulator = new LongAccumulator(Long::sum, 0L);
    RubbleKvStoreService() {}

    @Override
    public StreamObserver<OpReply> sendReply(final StreamObserver<Reply> responseObserver) {
      return new StreamObserver<OpReply>() {
        private int idx = -1;

        @Override
        public void onNext(OpReply reply) {
          idx = reply.getClientIdx();
          synchronized (observerArray[idx]) {
            observerArray[idx].onNext(reply);
          }
        }

        @Override
        public void onError(Throwable t) {
          LOGGER.error("Encountered error in sendReply", t);
        }

        @Override
        public void onCompleted() {
          observerAccumulator.accumulate(-1);
          System.out.println("observerAccumulator " + observerAccumulator.longValue());
          if (observerAccumulator.longValue() == 0) {
            System.out.println("observerArray[" + idx + "].onCompleted() " + observerArray[idx]);
            observerArray[idx].onCompleted();
          }
          responseObserver.onCompleted();
        }
      };
    }

    @Override
    public StreamObserver<Op> doOp(final StreamObserver<OpReply> responseObserver) {
      return new StreamObserver<Op>() {
        private StreamObserver<Op> headObserver = null;
        private StreamObserver<Op> tailObserver = null;
        private StreamObserver<OpReply> headReplyObserver = null;
        private StreamObserver<OpReply> tailReplyObserver = null;

        private void buildObserver(boolean isHead) {
          StreamObserver<OpReply> observer = new StreamObserver<OpReply>() {
              @Override
              public void onNext(OpReply reply) {
                LOGGER.error("[dumbObserver.onNext] should not reach here");
              }

              @Override
              public void onError(Throwable t) {
                LOGGER.error("error in dumbObserver", t);
              }

              @Override
              public void onCompleted() {
                System.out.println("dumbObserver.onCompleted()");
              }
          };

          if (isHead) {
            headReplyObserver = observer;
          } else {
            tailReplyObserver = observer;
          }
        }

        @Override
        public void onNext(Op request) {
          //LOGGER.info("send read request to tail");
          int shard = request.getClientIdx();
          if (responseObserver != observerArray[shard]) {
            System.out.println("observerArray[" + shard + "] changes from " + 
                observerArray[shard] + " to " + responseObserver);
          }
          observerArray[shard] = responseObserver;
          if (request.getOps(0).getType() == OpType.GET) {
            if (tailObserver == null) {
              buildObserver(false);
              tailObserver = tailStub[shard].doOp(tailReplyObserver);
              observerAccumulator.accumulate(1);
              System.out.println("observerAccumulator " + observerAccumulator.longValue());
            }
            tailObserver.onNext(request);
          } else {
            if (headObserver == null) {
              buildObserver(true);
              headObserver = headStub[shard].doOp(headReplyObserver);
              observerAccumulator.accumulate(1);
              System.out.println("observerAccumulator " + observerAccumulator.longValue());
            }
            headObserver.onNext(request);
          }
        }

        @Override
        public void onError(Throwable t) {
          LOGGER.error("Encountered error in doOp", t);
        }

        @Override
        public void onCompleted() {
          if (tailObserver != null) {
            tailObserver.onCompleted();
            System.out.println("tailObserver.onCompleted()");
          }
          if (headObserver != null) {
            headObserver.onCompleted();
            System.out.println("headObserver.onCompleted()");
          }
        }
      };
    }
  }
}