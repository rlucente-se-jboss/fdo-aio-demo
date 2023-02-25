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
## Create the edge blueprint file for an edge device in kiosk mode
##

cat > edge-blueprint.toml <<EOF
name = "Edge"
description = "Edge in kiosk mode"
version = "0.0.1"

EOF

if grep VERSION_ID /etc/os-release | grep -q '9\.'
then
    cat >> edge-blueprint.toml <<EOF
[[packages]]
name = "container-tools"
version = "*"
EOF
else
    # all of these packages mirror the container-tools module per 2023-02-24
    cat >> edge-blueprint.toml <<EOF
[[packages]]
name = "aardvark-dns"
version = "*"

[[packages]]
name = "buildah"
version = "*"

[[packages]]
name = "cockpit-podman"
version = "*"

[[packages]]
name = "conmon"
version = "*"

[[packages]]
name = "container-selinux"
version = "*"

[[packages]]
name = "containernetworking-plugins"
version = "*"

[[packages]]
name = "containers-common"
version = "*"

[[packages]]
name = "criu"
version = "*"

[[packages]]
name = "crun"
version = "*"

[[packages]]
name = "fuse-overlayfs"
version = "*"

[[packages]]
name = "libslirp"
version = "*"

[[packages]]
name = "netavark"
version = "*"

[[packages]]
name = "podman"
version = "*"

[[packages]]
name = "python3-podman"
version = "*"

[[packages]]
name = "runc"
version = "*"

[[packages]]
name = "skopeo"
version = "*"

[[packages]]
name = "slirp4netns"
version = "*"

[[packages]]
name = "toolbox"
version = "*"

[[packages]]
name = "udica"
version = "*"

EOF
fi

cat >> edge-blueprint.toml <<EOF
# kiosk mode GUI tools
[[packages]]
name = "gdm"
version = "*"

[[packages]]
name = "gnome-session-kiosk-session"
version = "*"

[[packages]]
name = "liberation-narrow-fonts.noarch"
version = "*"

[[packages]]
name = "liberation-sans-fonts.noarch"
version = "*"

[[packages]]
name = "firefox"
version = "*"

[[customizations.user]]
name = "$EDGE_USER"
description = "default edge user"
password = "$(openssl passwd -6 $EDGE_PASS)"
key = "$(cat id_$EDGE_USER.pub)"
home = "/home/$EDGE_USER/"
shell = "/usr/bin/bash"
groups = [ "wheel" ]

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
