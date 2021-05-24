if [ $# -lt 4 ]; then
    echo "Usage: bash node.sh rocksdb_dir port node_type ip:port(next node)"
    exit
fi

rm -rf $1
./bin/ycsb.sh node rocksdb -s -P workloads/workloada -p rocksdb.dir=$1 -p port=$2 -p node.type=$3 -p next.node=$4
