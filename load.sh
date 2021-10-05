if [ $# -lt 6 ]; then
    echo "Usage: bash load.sh workload ip:port(replicator) shard_num status_interval target_rate thread_num"
    exit
fi

./bin/ycsb.sh load rocksdb -s -P workloads/workload$1 -p rocksdb.dir=null -p replicator=$2 -p shard=$3 -p status.interval=$4 -p target=$5 -threads $6
