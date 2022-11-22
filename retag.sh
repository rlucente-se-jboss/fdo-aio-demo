#!/usr/bin/env bash

REPOID="192.168.8.100:5000/howsmysalute"

podman pull --all-tags $REPOID

podman tag $REPOID:$1 $REPOID:prod
podman push $REPOID:prod

echo
for i in {1..45}
do
    echo -n "."
    sleep 1
done
echo
echo

