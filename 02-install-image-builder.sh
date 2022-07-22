#!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -ne 0 ]] && exit_on_error "Must run as root"

##
## Install the packages
##

dnf -y install osbuild-composer composer-cli cockpit-composer jq \
    bash-completion

grep VERSION_ID /etc/os-release | grep -q '9\.' && \
    dnf -y install container-tools || \
    dnf -y module install container-tools

##
## Start the socket listeners
##

systemctl enable --now osbuild-composer.socket cockpit.socket

##
## Add user to weldr group
##

[[ ! -z "$SUDO_USER" ]] && usermod -aG weldr $SUDO_USER

