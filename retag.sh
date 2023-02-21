#!/usr/bin/env bash

REPOID="192.168.8.100:5000/howsmysalute"

podman pull --all-tags $REPOID

podman tag $REPOID:$1 $REPOID:prod
podman push $REPOID:prod

TICKS=45

echo
for i in $(seq 1 $TICKS)
do
    VAL=$(( i / 10 % 10 ))
    ((i % 10 )) && echo -n "." || echo -n $VAL
    sleep 1
done
echo
echo
