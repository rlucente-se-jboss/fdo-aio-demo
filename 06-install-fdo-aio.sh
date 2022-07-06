#!/usr/bin/env bash

. $(dirname $0)/demo.conf

[[ $EUID -ne 0 ]] && exit_on_error "Must run as root"

##
## Install the packages
##

dnf -y install fdo-admin-cli

##
## Open firewall ports for FDO
##

firewall-cmd --permanent --add-port=8000/tcp --add-port=8080-8083/tcp
firewall-cmd --reload

##
## Start FDO all-in-one services
##

systemctl enable --now fdo-aio

##
## Set edge device configuration
##

SERVICE_API_SERVER="/etc/fdo/aio/configs/serviceinfo_api_server.yml"

while [[ ! -f $SERVICE_API_SERVER ]]; do sleep 1; done

export SERVICE_AUTH_TOKEN="$(grep service_info_auth_token $SERVICE_API_SERVER | awk '{print $2}')"
export ADMIN_AUTH_TOKEN="$(grep admin_auth_token $SERVICE_API_SERVER | awk '{print $2}')"

envsubst < serviceinfo_api_server.yml.template > serviceinfo_api_server.yml

mv -f serviceinfo_api_server.yml $SERVICE_API_SERVER

cp -r device0 /etc

# configure edge device to use insecure registry

mkdir -p /etc/device0/cfg/etc/containers/registries.conf.d

cat <<EOF > /etc/device0/cfg/etc/containers/registries.conf.d/999-insecure-registry.conf
[[registry]]
insecure = true
location = "$FDO_SERVER:5000"
EOF

# generate systemd file for edge device container application

podman create --rm --name httpd -p 8080:80 \
    --label io.containers.autoupdate=registry $FDO_SERVER:5000/httpd:prod
podman generate systemd --files --new --name httpd
cp container-httpd.service /etc/device0/cfg/etc/systemd/system/
podman rm -f httpd

# fix SELinux contexts

restorecon -vFr /etc

##
## Disable TPM on edge device
##

AIO_CONFIG=/etc/fdo/aio/aio_configuration
sed -i.bak 's/\(manufacturing_disable_key_storage_tpm:\) false/\1 true/g' $AIO_CONFIG

##
## Restart the FDO all-in-one service
##

systemctl restart fdo-aio

