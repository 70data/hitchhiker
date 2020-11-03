#!/bin/bash

dockerpid=$1
pid=`docker inspect -f '{{.State.Pid}}' $dockerpid`

nsenter --target $pid --mount --uts --ipc --net --pid  


