package site.ycsb.db.rocksdb;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import io.grpc.Server;
import io.grpc.ServerBuilder;
import io.grpc.stub.StreamObserver;
import io.grpc.stub.ClientCallStreamObserver;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;

import site.ycsb.*;
import site.ycsb.RubbleKvStoreServiceGrpc.RubbleKvStoreServiceStub;
import site.ycsb.RubbleKvStoreServiceGrpc.RubbleKvStoreServiceBlockingStub;

import java.util.Properties;
import java.util.concurrent.Executors;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.TimeUnit;
import java.io.IOException;
import java.util.concurrent.atomic.LongAccumulator;
import java.util.List;
import java.sql.Timestamp;


/**
 * Replicator in chain replication.
 *
 * @author Haoyu Li.
 */
public class Replicator {
  private final int shardNum;
  private final int clientNum;
  private static Properties props;
  private final int port;
  private final Server server;
  private final ManagedChannel[] headChannel;
  private final ManagedChannel[] tailChannel;
  private static RubbleKvStoreServiceStub[] headStub; // added static
  private static RubbleKvStoreServiceStub[] tailStub;
  private final StreamObserver[][][] observerMap; // keys are [shardIdx][clientIdx][isWrite]
  private final ExecutorService threadPoolExecutor = Executors.newFixedThreadPool(16);
  private static final Logger LOGGER = LoggerFactory.getLogger(Replicator.class);

  // HEARTBEAT
  private static List<List<ManagedChannel>> channels;
  private static int[] replicationFactor;
  private static long needRestart = 0;
  private final LongAccumulator opssent = new LongAccumulator(Long::sum, 0L); 
  private final LongAccumulator maxThreads = new LongAccumulator(Long::sum, 0L);
  private final Thread[] recoverThreads;
  // HEARTBEAT
  
  public Replicator() throws IOException {
    this.shardNum = Integer.parseInt(props.getProperty("shard"));
    this.clientNum = Integer.parseInt(props.getProperty("client"));
    String[] headNode = new String[shardNum];
    String[] tailNode = new String [shardNum];
    this.headChannel = new ManagedChannel[shardNum];
    this.tailChannel = new ManagedChannel[shardNum];
    this.headStub = new RubbleKvStoreServiceStub[shardNum];
    this.tailStub = new RubbleKvStoreServiceStub[shardNum];
    this.observerMap = new StreamObserver[shardNum][clientNum][2];
    this.port = Integer.parseInt(props.getProperty("port"));
    ServerBuilder serverBuilder = ServerBuilder.forPort(port).addService(new RubbleKvStoreService());
    serverBuilder.maxInboundMessageSize(128 * 1024 * 1024);
    this.server = serverBuilder.build();
    this.recoverThreads = new Thread[shardNum];
    for (int i = 0; i < shardNum; i++) {
      headNode[i] = props.getProperty("head"+i);
      tailNode[i] = props.getProperty("tail"+i);
      
      this.headChannel[i] = ManagedChannelBuilder.forTarget(headNode[i]).usePlaintext().build();
      this.tailChannel[i] = ManagedChannelBuilder.forTarget(tailNode[i]).usePlaintext().build();
      this.headStub[i] = RubbleKvStoreServiceGrpc.newStub(this.headChannel[i]);
      this.tailStub[i] = RubbleKvStoreServiceGrpc.newStub(this.tailChannel[i]);

      // We only support tail recovery right now
      // TODO: support head and middle failures
      this.recoverThreads[i] = new Thread(new RecoverThread(i, tailNode[i]));
    }
  }

  public void start() throws IOException {
    server.start();
    LOGGER.info("Server started, listening on " + port);

    for (int i = 0; i < shardNum; i++) {
      recoverThreads[i].start();
    }

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
        private boolean isWrite;
        private int shardIdx = -1;
        private int clientIdx = -1;
        private int isWriteInt = -1;

        private String logString(String prefix) {
          Timestamp timestamp = new Timestamp(System.currentTimeMillis());
          return prefix + " shard: " + shardIdx + " client: " + clientIdx + " write:" + isWrite + " " + timestamp;
        }

        @Override
        public void onNext(OpReply reply) {
          if (shardIdx == -1) {
            shardIdx   = reply.getShardIdx();
            clientIdx  = reply.getClientIdx();
            isWrite    = reply.getReplies(0).getType() != OpType.GET &&
              reply.getReplies(0).getType() != OpType.SCAN;
            isWriteInt = isWrite ? 1 : 0;
          }
          assert(shardIdx  == reply.getShardIdx());
          assert(clientIdx == reply.getClientIdx());
          assert(isWrite   == (reply.getReplies(0).getType() != OpType.GET &&
            reply.getReplies(0).getType() != OpType.SCAN));
          observerMap[shardIdx][clientIdx][isWriteInt].onNext(reply);
        }

        @Override
        public void onError(Throwable t) {
          System.out.println(logString("sendReply.onError"));
          LOGGER.error("Encountered error in sendReply", t);
        }

        @Override
        public void onCompleted() {
          observerMap[shardIdx][clientIdx][isWriteInt].onCompleted();
          responseObserver.onCompleted();
          System.out.println(logString("sendReply.onCompleted"));
        }
      };
    }

    @Override
    public StreamObserver<Op> doOp(final StreamObserver<OpReply> responseObserver) {
      return new StreamObserver<Op>() {
        private boolean isWrite;
        private int shardIdx = -1;
        private int clientIdx = -1;
        private int isWriteInt = -1;

        private StreamObserver<Op> headObserver = null;
        private StreamObserver<Op> tailObserver = null;
        private StreamObserver<OpReply> headReplyObserver = null;
        private StreamObserver<OpReply> tailReplyObserver = null;
        private ClientCallStreamObserver<Op> headCallObserver = null;
        private ClientCallStreamObserver<Op> tailCallObserver = null;

        private String logString(String prefix) {
          Timestamp timestamp = new Timestamp(System.currentTimeMillis());
          return prefix + " shard: " + shardIdx + " client: " + clientIdx + " write:" + isWrite + " " + timestamp;
        }

        private void buildObserver(boolean isHead) {
          StreamObserver<OpReply> observer = new StreamObserver<OpReply>() {
              private int shard = shardIdx;
              private int client = clientIdx;
              private boolean write = isHead;

              private String logString(String prefix) {
                Timestamp timestamp = new Timestamp(System.currentTimeMillis());
                return prefix + " shard: " + shard + " client: " + client + " write:" + write + " " + timestamp;
              }
                          
              @Override
              public void onNext(OpReply reply) {
                LOGGER.error("[dumbObserver.onNext] should not reach here");
              }

              @Override
              public void onError(Throwable t) {
                System.out.println(logString("dumbObserver.onError"));
              }

              @Override
              public void onCompleted() {
                System.out.println(logString("dumbObserver.onCompleted"));
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
          if (shardIdx == -1) {
            shardIdx   = request.getShardIdx();
            clientIdx  = request.getClientIdx();
            isWrite    = request.getOps(0).getType() != OpType.GET &&
              request.getOps(0).getType() != OpType.SCAN;
            isWriteInt = isWrite ? 1 : 0;
          }
          assert(shardIdx  == request.getShardIdx());
          assert(clientIdx == request.getClientIdx());
          assert(isWrite   == (request.getOps(0).getType() != OpType.GET &&
            request.getOps(0).getType() != OpType.SCAN));

          if (responseObserver != observerMap[shardIdx][clientIdx][isWriteInt]) {
            System.out.println("observerMap[" + shardIdx + "] " + "[" + clientIdx + "] " + "[" + isWriteInt + "] " +
                "changes from " + observerMap[shardIdx][clientIdx][isWriteInt] + " to " + responseObserver);
            observerMap[shardIdx][clientIdx][isWriteInt] = responseObserver;
          }

          if (!isWrite) {
            if (tailObserver == null) {
              buildObserver(isWrite);
              tailObserver = tailStub[shardIdx].doOp(tailReplyObserver);
              tailCallObserver = (ClientCallStreamObserver<Op>)tailObserver;
              observerAccumulator.accumulate(1);
              if (observerAccumulator.longValue() > maxThreads.longValue()) {
                maxThreads.accumulate(1);
              }
              System.out.println("observerAccumulator " + observerAccumulator.longValue() + " shard " + shardIdx);
            }
            while (!tailCallObserver.isReady()) {
              try {
                Thread.sleep(1);
              } catch (InterruptedException e) {
                e.printStackTrace();
              }
            }
            tailObserver.onNext(request);
          } else {
            if (headObserver == null) {
              buildObserver(isWrite);
              headObserver = headStub[shardIdx].doOp(headReplyObserver);
              headCallObserver = (ClientCallStreamObserver<Op>)headObserver;
              observerAccumulator.accumulate(1);
              if (observerAccumulator.longValue() > maxThreads.longValue()) {
                maxThreads.accumulate(1);
              }
              System.out.println("observerAccumulator " + observerAccumulator.longValue() + " shard " + shardIdx);
            }

            if (needRestart > 0) {
              buildObserver(true);
              headObserver = headStub[shardIdx].doOp(headReplyObserver);
              needRestart--;
              System.out.println("Restarting head observer");
            }

            while (!headCallObserver.isReady()) {
              try {
                Thread.sleep(1);
              } catch (InterruptedException e) {
                e.printStackTrace();
              }
            }
            headObserver.onNext(request);
            opssent.accumulate(request.getOpsCount());
          }

          // also send termination message to the head to clean all buffered requests in
          // secondaries because read threads don't buffer anything
          if (request.getId() == -1) {
            if (request.getOps(0).getType() == OpType.GET && headObserver != null) {
              synchronized (headObserver) {
                headObserver.onNext(request);
              }
            } 
          }
        }

        @Override
        public void onError(Throwable t) {
          System.out.println(logString("doOp.onError"));
          LOGGER.error("Encountered error in doOp", t);
        }

        @Override
        public void onCompleted() {
          if (tailObserver != null) {
            tailObserver.onCompleted();
            System.out.println(logString("tailObserver.onCompleted"));
          }
          if (headObserver != null) {
            headObserver.onCompleted();
            System.out.println(logString("headObserver.onCompleted"));
          }
        }
      };
    }
  }

  private class RecoverThread implements Runnable {
    private final int rf;
    private final int sid;
    private final String ip;
    private ManagedChannel newTailChannel = null;
    private ManagedChannel newHeadChannel = null;
    private RubbleKvStoreServiceBlockingStub newTailStub = null;
    private RubbleKvStoreServiceBlockingStub newHeadStub = null;


    public RecoverThread(int sid, String ip) {
      this.sid = sid;
      int idx = ip.indexOf(':');
      this.ip = ip.substring(0, idx); 
      this.rf = Integer.parseInt(Replicator.props.getProperty("replica"));
    }

    public void run() {
      while (true) {
        detect(true);
        detect(false);
        recover();
      }
    }

    private void detect(boolean alive) {
      try{
        String neg = alive ? "" : "!";

        String cmd = "ssh root@" + ip + " " +
            "\"while true; do " +
            "    if " + neg + " ps aux | grep 'db_node 5005" + sid + "' | grep -v grep > /dev/null; then " + 
            "      break; " +
            "    fi; " +
            "    sleep 1; " +
            "done\"";

        System.out.println("Detecting " + cmd);

        ProcessBuilder builder = new ProcessBuilder("sh", "-c", cmd);
        builder.redirectErrorStream(true);
        Process process = builder.start();
        
        int exitCode = process.waitFor();

        System.out.println("Detected shard " + sid + " alive " + alive + " on " + ip + " with code " + exitCode);
      } catch (IOException | InterruptedException e) {
        e.printStackTrace();
      }
    }

    private void initStub() {
      if (newTailChannel == null) {
        String newTailAddr = getAddr(rf - 2);
        newTailChannel = ManagedChannelBuilder.forTarget(newTailAddr).usePlaintext().build();
      }
      if (newTailStub == null) {
        newTailStub = RubbleKvStoreServiceGrpc.newBlockingStub(newTailChannel);
      }
      if (newHeadChannel == null) {
        String newHeadAddr = Replicator.props.getProperty("head"+sid);
        newHeadChannel = ManagedChannelBuilder.forTarget(newHeadAddr).usePlaintext().build();
      }
      if (newHeadStub == null) {
        newHeadStub = RubbleKvStoreServiceGrpc.newBlockingStub(newHeadChannel);
      }
    }

    private void recover() {
      initStub();
      removeTail();
      insertTail();
    }

    String getAddr(int rid) {
      String a = "10.10.1." + (2 + (sid + rid) % rf);
      String p = "5005" + sid;

      if (rid == 0) {
        System.out.println("[getPrimaryAddr] " + a + ":" + p);
      } else if (rid == rf - 2) {
        System.out.println("[getNewTailAddr] " + a + ":" + p);
      } else {
        System.err.println("Should not reach here: sid = " + sid + " rid = " + rid);
      }
      return a + ":" + p;
    }

    private void removeTail() {
      // 0. Prepare the recover message
      RecoverRequest request = RecoverRequest.newBuilder()
          .setAction(Action.REMOVE_TAIL)
          .setMemId(-1)
          .build();

      // 1. Tell the second last node to be the new tail
      newTailStub.recover(request);
      System.out.println("[removeTail] Tell new tail to remove the failed tail");

      // 2. Tell the primary not to ship SST to the old tail
      newHeadStub.recover(request);
      System.out.println("[removeTail] Tell new head to remove the failed tail");
    }

    private void launchTail() {
      try {        
        String dbDir = "/mnt/data/db/shard-" + sid;
        String rubbleDir = "/mnt/data/rocksdb/rubble";
        String cgroupOpts = "cgexec -g cpuset:rubble-cpu -g memory:rubble-mem";
        String log = "shard-" + sid + ".out";
        String listenPort = "5005" + sid;
        String targetAddr = "10.10.1.1:50040";
        String primaryIp = getAddr(0);
        int rid = rf - 1;

        String cmd = "ssh root@" + ip + " " +
            "\"cd " + dbDir + "; " +
            "rm -rf db/* sst_dir/* shard-" + sid + ".out; " +
            "cd " + rubbleDir + "; " +
            "rm -rf log/* core*; " +
            "ulimit -n 999999; ulimit -c unlimited; " +
            "nohup sudo " + cgroupOpts + 
            " ./db_node " + listenPort + " " + targetAddr + " " + sid + " " + rid + " " + rf + " " + primaryIp + 
            " > " + log + " 2>&1 &\"";

        System.out.println("Launching new tail " + cmd);

        ProcessBuilder builder = new ProcessBuilder("sh", "-c", cmd);
        builder.redirectErrorStream(true);
        Process process = builder.start();
        
        int exitCode = process.waitFor();

        System.out.println("Launched new tail for shard " + sid + " on " + ip + " with code " + exitCode);
      } catch (IOException | InterruptedException e) {
        e.printStackTrace();
      }
    }

    private void insertTail() {
      // 0. Prepare the recover message
      RecoverRequest request = RecoverRequest.newBuilder()
          .setAction(Action.INSERT_TAIL)
          .setMemId(-1)
          .build();

      // 1. Launch a fresh node as the new tail
      launchTail();

      // 2. Tell the old tail to sync with the new tail
      newTailStub.recover(request);
      System.out.println("[insertTail] Tell old tail to insert the new tail");

      // 3. Tell the primary to sync the SST bit map
      // newHeadStub.recover(request);
    }
  }
}