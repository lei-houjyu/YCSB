package site.ycsb.db.rocksdb;

import site.ycsb.*;
// import site.ycsb.Status;
// import net.jcip.annotations.GuardedBy;
import org.rocksdb.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.*;
// import java.nio.ByteBuffer;
import java.nio.file.*;
import java.util.*;
// import java.util.concurrent.ConcurrentHashMap;
// import java.util.concurrent.ConcurrentMap;
// import java.util.concurrent.locks.Lock;
// import java.util.concurrent.locks.ReentrantLock;

import io.grpc.Server;
import io.grpc.ServerBuilder;
import io.grpc.stub.StreamObserver;
import java.io.IOException;
// import java.net.URL;
// import java.util.ArrayList;
// import java.util.Collection;
// import java.util.Collections;
// import java.util.List;
import java.util.concurrent.TimeUnit;

// import static java.nio.charset.StandardCharsets.UTF_8;

/**
 * Replicator's implementation in Rubble.
 *
 * @author Haoyu Li.
 */
public class Replicator {
  private final int port;
  private final Server server;
  private static final Logger LOGGER = LoggerFactory.getLogger(Replicator.class);

  public Replicator(int port) throws IOException {
    this(ServerBuilder.forPort(port), port);
  }
  
  public Replicator(ServerBuilder<?> serverBuilder, int port) {
    this.port = port;
    this.server = serverBuilder.addService(new ReplicationService()).build();
  }

  /** Start serving requests. */
  public void start() throws IOException {
    server.start();
    LOGGER.info("Server started, listening on " + port);
    Runtime.getRuntime().addShutdownHook(new Thread() {
      @Override
      public void run() {
        // Use stderr here since the logger may have been reset by its JVM shutdown hook.
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

  /** Stop serving requests and shutdown resources. */
  public void stop() throws InterruptedException {
    if (server != null) {
      server.shutdown().awaitTermination(30, TimeUnit.SECONDS);
    }
  }

  /**
   * Await termination on the main thread since the grpc library uses daemon threads.
   */
  private void blockUntilShutdown() throws InterruptedException {
    if (server != null) {
      server.awaitTermination();
    }
  }

  /**
   * Main method.  This comment makes the linter happy.
   */
  public static void main(String[] args) throws Exception {
    Replicator server = new Replicator(8980);
    server.start();
    server.blockUntilShutdown();
  }

  private static class ReplicationService extends ReplicationServiceGrpc.ReplicationServiceImplBase {
    ReplicationService() {}

    @Override
    public StreamObserver<Request> send(final StreamObserver<Reply> responseObserver) {
      return new StreamObserver<Request>() {
        @Override
        public void onNext(Request request) {
          Reply reply = Reply.newBuilder()
                     .setStatus("OK")
                     .setContent(request.getKeyCount() + " keys from " + request.getKey(0))
                     .build();
        //   LOGGER.info("Key: " + request.getKey(0) + " Value: " + request.getValue(0));
          responseObserver.onNext(reply);
        }

        @Override
        public void onError(Throwable t) {
          LOGGER.info("Encountered error in send");
        }

        @Override
        public void onCompleted() {
          responseObserver.onCompleted();
        }
      };
    }
  }
}