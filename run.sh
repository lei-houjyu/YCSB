if [ $# -lt 4 ]; then
    echo "Usage: bash run.sh workload ip:port(replicator) shard_num status.interval"
    exit
fi

./bin/ycsb.sh run rocksdb -s -P workloads/workload$1 -p rocksdb.dir=null -p replicator=$2 -p shard=$3 -p status.interval=$4 -threads 8
