#!/bin/bash

WORKSPACE="$(cd $(dirname $0) && pwd)"

LOG_PATH="$WORKSPACE/aleo-miner.log"
APP_PATH="$WORKSPACE/aleo-miner"
IP_PORT=$1
ACCOUNTNAME=$2
CPU_SPAN=$3

if [[ "$IP_PORT" == "" ]]; then
    echo "error: Expect 1 argument"
    exit 1
fi

if [[ "$ACCOUNTNAME" == "" ]]; then
    echo "error: Expect 2 argument"
    exit 1
fi

pkill -9 aleo-miner

gpu_exists=$(nvidia-smi topo -m 2>/dev/null) && "1"
cpu_cores=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
physical_cores=$(( cpu_cores / 2 ))
if [[ "$CPU_SPAN" == "" ]]; then
    CPU_SPAN=16
fi
unset TASTSET_CPU_CORES

if [[ $gpu_exists == "1" ]]; then
    nohup $APP_PATH -d 0 -u $IP_PORT -w $ACCOUNTNAME >> $LOG_PATH 2>&1 &
    echo "nohup $APP_PATH -d 0 -u $IP_PORT -w $ACCOUNTNAME >> $LOG_PATH 2>&1 &"
elif [[ $cpu_cores -le $((CPU_SPAN * 2)) ]]; then
    cpu_list="0-$((cpu_cores - 1))"
    export TASTSET_CPU_CORES=$cpu_list && nohup taskset -c $cpu_list $APP_PATH -u $IP_PORT -w $ACCOUNTNAME >> $LOG_PATH 2>&1 &
    echo "nohup taskset -c $cpu_list $APP_PATH -u $IP_PORT -w $ACCOUNTNAME >> $LOG_PATH 2>&1 &"
else
    for index in $(seq 0 $CPU_SPAN $((physical_cores - 1))); do
        echo "index $index CPU_SPAN $CPU_SPAN physical_cores $physical_cores"
        cpu_list="$index-$((index + CPU_SPAN - 1)),$((index + physical_cores))-$((index + physical_cores + CPU_SPAN - 1))"
        export TASTSET_CPU_CORES=$cpu_list && nohup taskset -c $cpu_list $APP_PATH -u $IP_PORT -w $ACCOUNTNAME >> $LOG_PATH 2>&1 &
        echo "nohup taskset -c $cpu_list $APP_PATH -u $IP_PORT -w $ACCOUNTNAME >> $LOG_PATH 2>&1 &"
        sleep 2
    done
fi