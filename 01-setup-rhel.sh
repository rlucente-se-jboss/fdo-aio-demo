#!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -ne 0 ]] && exit_on_error "Must run as root"

##
## Register the system using simple content access
##

subscription-manager register \
    --username "$RHSM_USER" --password "$RHSM_PASS" \
    || exit_on_error "Unable to register subscription"
subscription-manager role --set="Red Hat Enterprise Linux Server"
subscription-manager service-level --set="Self-Support"
subscription-manager usage --set="Development/Test"
subscription-manager attach

##
## Update the system
##

dnf -y update
dnf -y clean all

