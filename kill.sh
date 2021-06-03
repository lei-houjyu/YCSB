#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: bash kill.sh ip_0 ... ip_N"
    exit
fi

sudo killall java
for ip in $*
do
    ssh ${USER}@${ip} "sudo killall java"
done