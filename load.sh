rm -rf ~/tmp/rocksdb-backup/*
./bin/ycsb.sh load rocksdb -s -P workloads/workloada -p rocksdb.dir=/users/haoyuli/tmp/rocksdb-backup -threads 8
