if [ $# -lt 6 ]; then
    echo "Usage: bash run.sh workload ip:port(replicator) shard_num status_interval target_rate thread_num"
    exit
fi

rm -rf null
./bin/ycsb.sh run rocksdb -s -P workloads/workload$1 -p rocksdb.dir=null -p replicator=$2 -p shard=$3 -p status.interval=$4 -p target=$5 -threads $6
