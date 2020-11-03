#! /bin/bash

d() { sleep 1000; }
for i in $(seq 1 100)
do
    echo "sleep $i\n"
    d&
done

