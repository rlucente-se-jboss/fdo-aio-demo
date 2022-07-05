##!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -eq 0 ]] && exit_on_error "Do not run as root"

##
## Create containerized httpd application version 1
##

CTR_ID=$(buildah from registry.access.redhat.com/ubi8/ubi:latest)
buildah run $CTR_ID -- dnf -y install httpd
cat <<'EOF1' > index.html
 ____                           _
/ ___|  ___ _ ____   _____ _ __| | ___  ___ ___
\___ \ / _ \ '__\ \ / / _ \ '__| |/ _ \/ __/ __|
 ___) |  __/ |   \ V /  __/ |  | |  __/\__ \__ \
|____/ \___|_|    \_/ \___|_|  |_|\___||___/___/
             with Podman and Systemd
                                                          
EOF1
buildah copy $CTR_ID index.html /var/www/html/index.html
buildah config --cmd "/usr/sbin/httpd -D FOREGROUND" $CTR_ID
buildah config --port 80 $CTR_ID
buildah commit $CTR_ID $FDO_SERVER:5000/httpd:v1

podman push $FDO_SERVER:5000/httpd:v1

##
## Tag the image as "prod" in the local insecure registry
##

podman tag $FDO_SERVER:5000/httpd:v1 $FDO_SERVER:5000/httpd:prod
podman push $FDO_SERVER:5000/httpd:prod

##
## Create containerized httpd application version 2
##

CTR_ID=$(buildah from $FDO_SERVER:5000/httpd:v1)
cat <<'EOF2' >> index.html
 ________________________________ 
( Podman auto-update is awesome! )
 -------------------------------- 
   o
    o
        .--.
       |o_o |
       |:_/ |
      //   \ \
     (|     | )
    /'\_   _/`\
    \___)=(___/
EOF2
buildah copy $CTR_ID index.html /var/www/html/index.html
buildah commit $CTR_ID $FDO_SERVER:5000/httpd:v2

podman push $FDO_SERVER:5000/httpd:v2
