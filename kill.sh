#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: bash kill.sh ip_0 ip_1"
    exit
fi

sudo killall java
ssh ${USER}@$1 "sudo killall java"
ssh ${USER}@$2 "sudo killall java"