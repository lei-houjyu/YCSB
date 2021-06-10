if [ $# -lt 5 ]; then
    echo "Usage: bash node.sh rocksdb_dir port node_type ip:port(next node) statusIntervalMS"
    echo "Attention: should copy the rocksdb database at first"
    exit
fi

pid=`cat $1-pid.txt`
tail --pid=$pid -f /dev/null
# rm -rf $1
# cp -r $1-backup $1
./bin/ycsb.sh node rocksdb -s -P workloads/workloada -p rocksdb.optionsfile=rocksdb.ini -p rocksdb.dir=$1 -p port=$2 -p node.type=$3 -p next.node=$4 -p status.interval=$5
