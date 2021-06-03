if [ $# -lt 2 ]; then
    echo "Usage: bash load.sh workload ip:port(replicator) shard"
    exit
fi

./bin/ycsb.sh load rocksdb -s -P workloads/workload$1 -p rocksdb.dir=null -p replicator=$2 -p shard=$3 -threads 8
