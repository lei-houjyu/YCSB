if [ $# -lt 3 ]; then
    echo "Usage: bash replicator.sh replicator_port ip:port(head) ip:port(tail)"
    exit
fi

./bin/ycsb.sh replicator rocksdb -s -P workloads/workloada -p port=$1 -p head=$2 -p tail=$3
