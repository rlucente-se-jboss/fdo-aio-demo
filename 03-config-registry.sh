##!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -ne 0 ]] && exit_on_error "Must run as root"

##
## Setup for a local insecure registry
##

firewall-cmd --permanent --add-port=5000/tcp
firewall-cmd --reload

mkdir -p /var/lib/registry /etc/containers/registries.conf.d

cat <<EOF > /etc/containers/registries.conf.d/999-insecure-registry.conf
[[registry]]
insecure = true
location = "$FDO_SERVER:5000"
EOF

restorecon -vFr /var/lib/registry /etc/containers

##
## Create systemd unit files for registry service
##

CTR_ID=$(podman run --rm --privileged -d --name registry -p 5000:5000 -v /var/lib/registry:/var/lib/registry:z docker.io/library/registry:2)
podman generate systemd --new --files --name $CTR_ID

##
## Clean up running containers
##

podman stop --all
podman rm -f --all

##
## Enable registry service
##

cp container-registry.service /etc/systemd/system
restorecon -vFr /etc/systemd/system
systemctl daemon-reload
systemctl enable --now container-registry.service

