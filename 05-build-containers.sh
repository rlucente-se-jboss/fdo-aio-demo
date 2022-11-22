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

git clone https://github.com/tedbrunell/HowsMySalute.git -b usmc
cd HowsMySalute
podman build --layers=false -t $REPO_ID:usmc .
podman push $REPO_ID:usmc

git checkout navy
podman build --layers=false -t $REPO_ID:navy .
podman push $REPO_ID:navy

git checkout army
podman build --layers=false -t $REPO_ID:army .
podman push $REPO_ID:army

git checkout usaf
podman build --layers=false -t $REPO_ID:usaf .
podman push $REPO_ID:usaf

git checkout ussf
podman build --layers=false -t $REPO_ID:ussf .
podman push $REPO_ID:ussf

##
## Tag the image as "prod" in the local insecure registry
##

podman tag $REPO_ID:army $REPO_ID:prod
podman push $REPO_ID:prod

