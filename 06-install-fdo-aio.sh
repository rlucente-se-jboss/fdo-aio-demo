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

# make sure the local registry is ready
systemctl restart container-registry.service

# generate systemd file for edge device container application
podman create --rm --name howsmysalute \
    --security-opt label=disable --device /dev/video0 -p 8080:8080 \
    --label io.containers.autoupdate=registry $FDO_SERVER:5000/howsmysalute:prod
podman generate systemd --files --new --name howsmysalute
cp container-howsmysalute.service /etc/device0/cfg/etc/systemd/system/
podman rm -f howsmysalute

##
## Disable TPM on edge device
##

AIO_CONFIG=/etc/fdo/aio/aio_configuration
sed -i.bak 's/\(manufacturing_disable_key_storage_tpm:\) false/\1 true/g' $AIO_CONFIG

##
## Remove unnecessary IP addresses in FDO AIO configuration files
##

for ipaddr in $(grep IpAddr $AIO_CONFIG | awk '{print $3}' | sed 's/"//g' | \
    grep -v $FDO_SERVER | sort -u)
do
    sed -i '/'$ipaddr'/d' $AIO_CONFIG
    sed -i '/'$ipaddr'/d' /etc/fdo/aio/configs/owner_onboarding_server.yml

    # This awk expression removes the line before the pattern, the
    # pattern, and two lines after the pattern
    # See https://red.ht/3amgyAt.

    awk '/'$ipaddr'/{for(x=NR-1;x<=NR+2;x++)d[x];}{a[NR]=$0}END{for(i=1;i<=NR;i++)if(!(i in d))print a[i]}' \
        /etc/fdo/aio/configs/manufacturing_server.yml > tmp.out
    mv tmp.out /etc/fdo/aio/configs/manufacturing_server.yml
done

##
## Fix SELinux contexts
##

restorecon -vFr /etc

##
## Restart the FDO all-in-one service
##

systemctl restart fdo-aio

