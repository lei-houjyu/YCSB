package site.ycsb.db.rocksdb;

import site.ycsb.*;
import site.ycsb.Status;
import org.rocksdb.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.*;
import java.nio.file.*;
import java.util.*;

import io.grpc.Server;
import io.grpc.ServerBuilder;
import io.grpc.stub.StreamObserver;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import site.ycsb.ReplicationServiceGrpc.ReplicationServiceStub;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

import static java.nio.charset.StandardCharsets.UTF_8;

/**
 * ChainNode's implementation in Rubble.
 *
 * @author Haoyu Li.
 */
public class ChainNode {
  private static DB db;
  private static Properties props;
  private final int port;
  private final Server server;
  private static final Logger LOGGER = LoggerFactory.getLogger(ChainNode.class);
  private final String table;
  private final String nodeType;
  private final ManagedChannel nextChannel;
  private final ReplicationServiceStub nextStub;
  private static final String HEAD = "head";
  private static final String MID  = "mid";
  private static final String TAIL = "tail";

  public ChainNode() {
    this.port = Integer.parseInt(props.getProperty("port"));
    this.nodeType = props.getProperty("node.type");
    if (nodeType.equals(TAIL)) {
      this.nextChannel = null;
      this.nextStub = null;
    } else {
      String nextNode = props.getProperty("next.node");
      this.nextChannel = ManagedChannelBuilder.forTarget(nextNode).usePlaintext().build();
      this.nextStub = ReplicationServiceGrpc.newStub(this.nextChannel);
    }
    this.server = ServerBuilder.forPort(port).addService(new ReplicationService()).build();
    this.table = props.getProperty("table", "usertable");
    String dbname = props.getProperty("db", "site.ycsb.BasicDB");

    try {
      ClassLoader classLoader = DBFactory.class.getClassLoader();
      Class dbclass = classLoader.loadClass(dbname);
      db = (DB) dbclass.newInstance();
      db.setProperties(props);
      db.init();
    } catch (Exception e) {
      e.printStackTrace();
    }
  }

  /** Start serving requests. */
  public void start() throws IOException {
    server.start();
    LOGGER.info("Server started, listening on " + port);
    Runtime.getRuntime().addShutdownHook(new Thread() {
      @Override
      public void run() {
        System.err.println("*** shutting down gRPC server since JVM is shutting down");
        try {
          ChainNode.this.stop();
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
    if (nextChannel != null) {
      nextChannel.shutdownNow().awaitTermination(5, TimeUnit.SECONDS);
    }
  }

  private void blockUntilShutdown() throws InterruptedException {
    if (server != null) {
      server.awaitTermination();
    }
  }

  public static void main(String[] args) throws Exception {
    props = Client.parseArguments(args);
    ChainNode server = new ChainNode();
    server.start();
    server.blockUntilShutdown();
  }

  private class ReplicationService extends ReplicationServiceGrpc.ReplicationServiceImplBase {
    ReplicationService() {}

    @Override
    public StreamObserver<Request> read(final StreamObserver<Reply> responseObserver) {
      return new StreamObserver<Request>() {
        public Status processRead(Request request, int i) {
          Request.OpType type = request.getType(i);
          String key = request.getKey(i);
          Map<String, ByteIterator> values = new HashMap<>();
          switch (type) {
            case READ:
              return db.read(table, key, null, values);

            case SCAN:
            default:
              System.err.println("Unsupported op type: " + type);
              break;
          }

          return Status.ERROR;
        }

        @Override
        public void onNext(Request request) {
          //LOGGER.info("receive request from previous node");
          Reply.Builder builder = Reply.newBuilder();
          int batchSize = request.getBatchSize();
          builder.setBatchSize(batchSize);

          for (int i = 0; i < batchSize; i++) {
            Status res = processRead(request, i);
            if (!res.isOk() && !res.equals(Status.NOT_FOUND)) {
              LOGGER.error("Some request failed!");
            }
            builder.addStatus(res.getName());
            builder.addContent(res.getDescription());
          }

          //LOGGER.info("reply to replicator");
          responseObserver.onNext(builder.build());
        }

        @Override
        public void onError(Throwable t) {
          LOGGER.error("Encountered error in read", t);
        }

        @Override
        public void onCompleted() {
          responseObserver.onCompleted();
        }
      };
    }

    @Override
    public StreamObserver<Request> write(final StreamObserver<Reply> responseObserver) {
      return new StreamObserver<Request>() {
        public Status processWrite(Request request, int i) {
          Request.OpType type = request.getType(i);
          String key = request.getKey(i);
          String value = null;
          Map<String, ByteIterator> values = new HashMap<>();
          switch (type) {
            case INSERT:
              value = request.getValue(i);
              RocksDBClient.deserializeValues(value.getBytes(UTF_8), null, values);
              return db.insert(table, key, values);

            case UPDATE:
              value = request.getValue(i);
              RocksDBClient.deserializeValues(value.getBytes(UTF_8), null, values);
              return db.update(table, key, values);
        
            default:
              System.err.println("Unsupported op type: " + type);
              break;
          }

          return Status.ERROR;
        }

        @Override
        public void onNext(Request request) {
          //LOGGER.info("receive request from previous node");
          Reply.Builder builder = Reply.newBuilder();
          int batchSize = request.getBatchSize();
          builder.setBatchSize(batchSize);

          for (int i = 0; i < batchSize; i++) {
            Status res = processWrite(request, i);
            if (!res.isOk() && !res.equals(Status.NOT_FOUND)) {
              LOGGER.error("Some request failed!");
            }
            builder.addStatus(res.getName());
            builder.addContent(res.getDescription());
          }

          if (nodeType.equals(TAIL)) {
            //LOGGER.info("reply to replicator");
            responseObserver.onNext(builder.build());
            responseObserver.onCompleted();
          } else {
            //LOGGER.info("forward to next node");
            StreamObserver<Request> requestObserver = nextStub.write(responseObserver);
            requestObserver.onNext(request);
            requestObserver.onCompleted();
          }
        }

        @Override
        public void onError(Throwable t) {
          LOGGER.error("Encountered error in write", t);
        }

        @Override
        public void onCompleted() {
        }
      };
    }
  }
}