#!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -eq 0 ]] && exit_on_error "Do not run as root"

##
## Generate ssh keys for edge user
##

ssh-keygen -f $HOME/.ssh/id_$EDGE_USER -t rsa -P "" \
           -C $EDGE_USER@localhost.localdomain
cp $HOME/.ssh/id_$EDGE_USER.pub .

##
## Create the edge blueprint file
##

cat > edge-blueprint.toml <<EOF
name = "Edge"
description = ""
version = "0.0.1"

[[packages]]
name = "container-tools"
version = "*"

[[customizations.user]]
name = "$EDGE_USER"
description = "default edge user"
key = "$(cat id_$EDGE_USER.pub)"
home = "/var/home/$EDGE_USER/"
shell = "/usr/bin/bash"

[[customizations.sshkey]]
user = "$EDGE_USER"
key = "$(cat id_$EDGE_USER.pub)"
EOF

##
## Create the simplified installer blueprint for FDO
##

cat > simplified-installer.toml <<EOF
name = "SimplifiedInstall"
description = "A rhel-edge simplified-installer image"
version = "0.0.1"
packages = []
modules = []
groups = []
distro = ""

[customizations]
installation_device = "$EDGE_STORAGE_DEV"

[customizations.fdo]
manufacturing_server_url = "http://$FDO_SERVER:8080"
diun_pub_key_insecure = "true"
EOF

