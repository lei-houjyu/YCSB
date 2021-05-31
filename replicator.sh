if [ $# -lt 5 ]; then
    echo "Usage: bash replicator.sh replicator_port ip:port(head0) ip:port(tail0) ip:port(head1) ip:port(tail1)"
    exit
fi

./bin/ycsb.sh replicator rocksdb -s -P workloads/workloada -p port=$1 -p head0=$2 -p tail0=$3 -p head1=$4 -p tail1=$5
