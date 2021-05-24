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
import java.util.concurrent.TimeUnit;
import java.io.IOException;

/**
 * Replicator in chain replication.
 *
 * @author Haoyu Li.
 */
public class Replicator {
  private static Properties props;
  private final int port;
  private final Server server;
  private final ManagedChannel headChannel;
  private final ManagedChannel tailChannel;
  private final ReplicationServiceStub headStub;
  private final ReplicationServiceStub tailStub;
  private static final Logger LOGGER = LoggerFactory.getLogger(Replicator.class);
  
  public Replicator() throws IOException {
    String headNode = props.getProperty("head");
    String tailNode = props.getProperty("tail");
    this.port = Integer.parseInt(props.getProperty("port"));
    this.server = ServerBuilder.forPort(port).addService(new ReplicationService()).build();
    this.headChannel = ManagedChannelBuilder.forTarget(headNode).usePlaintext().build();
    this.tailChannel = ManagedChannelBuilder.forTarget(tailNode).usePlaintext().build();
    this.headStub = ReplicationServiceGrpc.newStub(this.headChannel);
    this.tailStub = ReplicationServiceGrpc.newStub(this.tailChannel);
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
      server.shutdown().awaitTermination(30, TimeUnit.SECONDS);
    }
    if (headChannel != null) {
      headChannel.shutdownNow().awaitTermination(5, TimeUnit.SECONDS);
    }
    if (tailChannel != null) {
      tailChannel.shutdownNow().awaitTermination(5, TimeUnit.SECONDS);
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
    public StreamObserver<Request> read(final StreamObserver<Reply> responseObserver) {
      return new StreamObserver<Request>() {
        private final StreamObserver<Request> tailObserver = 
            tailStub.read(new StreamObserver<Reply>() {
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
            
        @Override
        public void onNext(Request request) {
          //LOGGER.info("send read request to tail");
          tailObserver.onNext(request);
        }

        @Override
        public void onError(Throwable t) {
          LOGGER.error("Encountered error in read", t);
        }

        @Override
        public void onCompleted() {
          //LOGGER.info("onCompleted to tail");
          tailObserver.onCompleted();
        }
      };
    }

    @Override
    public StreamObserver<Request> write(final StreamObserver<Reply> responseObserver) {
      return new StreamObserver<Request>() {
        private final StreamObserver<Request> headObserver = 
            headStub.write(new StreamObserver<Reply>() {
                @Override
                public void onNext(Reply reply) {
                  //LOGGER.info("receive write reply from tail " + reply.getStatus(0) + " " + reply.getContent(0));
                  //LOGGER.info("reply to YCSB");
                  responseObserver.onNext(reply);
                }

                @Override
                public void onError(Throwable t) {
                  LOGGER.error("error in write", t);
                }

                @Override
                public void onCompleted() {
                  //LOGGER.info("onCompleted from tail");
                  //LOGGER.info("onCompleted to YCSB");
                  responseObserver.onCompleted();
                }
            });

        @Override
        public void onNext(Request request) {
          //LOGGER.info("send write request to head");
          headObserver.onNext(request);
        }

        @Override
        public void onError(Throwable t) {
          LOGGER.error("Encountered error in write", t);
        }

        @Override
        public void onCompleted() {
          //LOGGER.info("onCompleted to head");
          headObserver.onCompleted();
        }
      };
    }
  }
}