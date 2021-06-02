#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: bash update-nodes.sh ip_0 ip_1"
    exit
fi

sudo killall java
ssh ${USER}@$1 "cd YCSB-head; git reset --hard HEAD; git pull origin lhy_dev; bash build.sh"
ssh ${USER}@$1 "cd YCSB-tail; git reset --hard HEAD; git pull origin lhy_dev; bash build.sh"
ssh ${USER}@$2 "cd YCSB-head; git reset --hard HEAD; git pull origin lhy_dev; bash build.sh"
ssh ${USER}@$2 "cd YCSB-tail; git reset --hard HEAD; git pull origin lhy_dev; bash build.sh"