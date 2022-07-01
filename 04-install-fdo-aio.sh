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

firewall-cmd --permanent --add-port=8000/tcp --add-port=8080/tcp \
             --add-port=8081/tcp --add-port=8082/tcp --add-port=8083/tcp
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
tar -zxC /etc -f device0.tgz
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

