#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: bash kill.sh ip_0 ... ip_N"
    exit
fi

# kill YCSB clients and the replicator
sudo killall java

for ip in $*
do
    # kill RocksDB instances and iostat
    ssh ${USER}@${ip} "sudo killall primary_node tail_node iostat"

    # umount local and remote disks
    ssh ${USER}@${ip} "sudo bash /mnt/sdb/my_rocksdb/rubble/kill-busy-procs.sh"
    ssh ${USER}@${ip} "sudo umount /dev/nvme0n1p4"
    ssh ${USER}@${ip} "sudo umount /dev/nvme1n1p4"
done

# correct local file systems
for ip in $*
do
    ssh ${USER}@${ip} "sudo fsck -p /dev/nvme0n1p4"
    ssh ${USER}@${ip} "sudo mount /dev/nvme0n1p4 /mnt/sdb"
done

# mount remote devices
for ip in $*
do
    ssh ${USER}@${ip} "sudo mount /dev/nvme1n1p4 /mnt/remote"
done