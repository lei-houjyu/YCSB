rm -r ~/tmp/rocksdb
cp -r ~/tmp/rocksdb-backup ~/tmp/rocksdb
./bin/ycsb.sh run rocksdb -s -P workloads/workloada -p rocksdb.dir=/users/haoyuli/tmp/rocksdb -threads 8
