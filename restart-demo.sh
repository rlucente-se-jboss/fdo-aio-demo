##!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -ne 0 ]] && exit_on_error "Must run as root"

##
## Cleanly restart the demo
##

systemctl restart container-howsmysalute && pkill firefox

