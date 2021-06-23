# Overview

This tutorial shows how to run the experiments with one YCSB, one replicator, and three key shards. Each key shard is a chain replication group consisting of three nodes, namely head, mid, and tail.

You can get the same setting by starting a CloudLab experiment with four linked `m510` machines or using our [profile](https://www.cloudlab.us/p/3d6452a6-c413-11eb-b1eb-e4434b2381fc).

Once the experiment is up, you will see four nodes indexed from 0 to 3, whose IPs are `10.10.1.1`, `10.10.1.2`, `10.10.1.3`, and `10.10.1.4`.

We have the YCSB and replicator on `node-0` and the rest RocksDB instances on `node-1` to `node-3`.

The topology is:

* node-0: YCSB and replicator

* node-1: tail-1, mid-3, head-2

* node-2: tail-2, mid-1, head-3

* node-3: tail-3, mid-2, head-1

# Preparation

The commands in this section need to be executed on every node.

```bash
# Install dependencies
$ sudo apt install maven openjdk-11-jdk libsnappy-dev libbz2-dev liblz4-dev libzstd-dev dstat

# Get YCSB source code
$ git clone https://github.com/cc4351/YCSB.git
$ cd YCSB
$ git fetch origin lhy_dev
$ git checkout lhy_dev
$ cd ..
$ for i in {1..3}; do cp -r YCSB YCSB-$i; cd YCSB-$i; bash build.sh; cd -; done

# Mount NVMe devices
$ sudo mkfs.ext4 /dev/nvme0n1p4
$ sudo mkdir /mnt/sdb
$ sudo mount /dev/nvme0n1p4 /mnt/sdb/
$ sudo chown -R $USER:lsm-rep-PG0 /mnt/sdb/
```

# Build and run

You only need to run the following command on `node-0`, where the YCSB and replicator sit. 

```bash
$ bash build.sh 
```

Before we run the experiment, we need to load the database. Basically, the command starts the YCSB and runs the replicator on port `8980`. It tells the YCSB to `load` the database according to the config file `workloads/workloada`. Following is a target request rate of `30000` and the IP addresses of the other three nodes.

```bash
$ bash eval.sh 8980 load a 30000 10.10.1.1 10.10.1.3 10.10.1.4
```

Next, we need to backup the database to avoid redundant loading. Run the next command on nodes 1 to 3.

```bash
$ for i in {1..3}; do mv /mnt/sdb/rocksdb-$i /mnt/sdb/rocksdb-$i-backup; done
```

Finally, we can run the experiment by simply replacing `load` to `run`. Replicator and YCSB's output are `replicator.out` and `ycsb.out`, respectively.

```bash
$ bash eval.sh 8980 run a 30000 10.10.1.1 10.10.1.3 10.10.1.4
```
