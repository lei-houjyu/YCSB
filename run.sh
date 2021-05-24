if [ $# -lt 2 ]; then
    echo "Usage: bash run.sh workload ip:port(replicator)"
    exit
fi

./bin/ycsb.sh run rocksdb -s -P workloads/workload$1 -p rocksdb.dir=null -p replicator=$2 -threads 8
