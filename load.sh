if [ $# -lt 1 ]; then
    echo "Usage: bash load.sh ip:port(replicator)"
    exit
fi

./bin/ycsb.sh load rocksdb -s -P workloads/workloada -p rocksdb.dir=null -p replicator=$1 -threads 8
