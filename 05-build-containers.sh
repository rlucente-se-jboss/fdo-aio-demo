##!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -eq 0 ]] || exit_on_error "Must run as root"

##
## Install required tooling
##

dnf -y install git

##
## Create containerized HowsMySalute application for USMC salute
##

REPO_ID=$FDO_SERVER:5000/howsmysalute

git clone https://github.com/tedbrunell/HowsMySalute.git
podman build --layers=false -t $REPO_ID:usmc .
podman push $REPO_ID:usmc

##
## Tag the image as "prod" in the local insecure registry
##

podman tag $REPO_ID:usmc $REPO_ID:prod
podman push $REPO_ID:prod

