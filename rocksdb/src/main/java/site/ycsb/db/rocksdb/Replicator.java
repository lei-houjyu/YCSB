package site.ycsb.db.rocksdb;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import io.grpc.Server;
import io.grpc.ServerBuilder;
import io.grpc.stub.StreamObserver;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;

import site.ycsb.*;
import site.ycsb.ReplicationServiceGrpc.ReplicationServiceStub;

import java.util.Properties;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;
import java.io.IOException;

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
  private final ReplicationServiceStub[] headStub;
  private final ReplicationServiceStub[] tailStub;
  private final ExecutorService threadPoolExecutor = Executors.newFixedThreadPool(16);
  private static final Logger LOGGER = LoggerFactory.getLogger(Replicator.class);
  
  public Replicator() throws IOException {
    this.shardNum = Integer.parseInt(props.getProperty("shard"));
    String[] headNode = new String[shardNum];
    String[] tailNode = new String [shardNum];
    this.headChannel = new ManagedChannel[shardNum];
    this.tailChannel = new ManagedChannel[shardNum];
    this.headStub = new ReplicationServiceStub[shardNum];
    this.tailStub = new ReplicationServiceStub[shardNum];
    this.port = Integer.parseInt(props.getProperty("port"));
    ServerBuilder serverBuilder = ServerBuilder.forPort(port).addService(new ReplicationService());
    this.server = serverBuilder.executor(threadPoolExecutor).build();
    for (int i = 0; i < shardNum; i++) {
      headNode[i] = props.getProperty("head"+(i+1));
      tailNode[i] = props.getProperty("tail"+(i+1));
      this.headChannel[i] = ManagedChannelBuilder.forTarget(headNode[i]).usePlaintext().build();
      this.tailChannel[i] = ManagedChannelBuilder.forTarget(tailNode[i]).usePlaintext().build();
      this.headStub[i] = ReplicationServiceGrpc.newStub(this.headChannel[i]);
      this.tailStub[i] = ReplicationServiceGrpc.newStub(this.tailChannel[i]);
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

  private class ReplicationService extends ReplicationServiceGrpc.ReplicationServiceImplBase {
    ReplicationService() {}

    @Override
    public StreamObserver<Request> doOp(final StreamObserver<Reply> responseObserver) {
      return new StreamObserver<Request>() { 
        @Override
        public void onNext(Request request) {
          //LOGGER.info("send read request to tail");
          int shard = (int)(Long.parseLong(request.getKey(0).substring(4)) % shardNum);
          ReplicationServiceStub stub =
              request.getType(0) == OpType.READ ? tailStub[shard] : headStub[shard];
          StreamObserver<Request> observer =
              stub.doOp(new StreamObserver<Reply>() {
                  @Override
                  public void onNext(Reply reply) {
                    //LOGGER.info("receive read reply from tail " + reply.getStatus(0) + " " + reply.getContent(0));
                    //LOGGER.info("reply to YCSB");
                    responseObserver.onNext(reply);
                  }

                  @Override
                  public void onError(Throwable t) {
                    LOGGER.error("error in read", t);
                  }

                  @Override
                  public void onCompleted() {
                    //LOGGER.info("onCompleted from tail");
                    //LOGGER.info("onCompleted to YCSB");
                    responseObserver.onCompleted();
                  }
              });
          observer.onNext(request);
          observer.onCompleted();
        }

        @Override
        public void onError(Throwable t) {
          LOGGER.error("Encountered error in read", t);
        }

        @Override
        public void onCompleted() {
          //LOGGER.info("onCompleted to tail");
        }
      };
    }
  }
}