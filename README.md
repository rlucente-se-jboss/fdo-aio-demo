# fdo-aio-demo
This demonstrates FIDO Device Onboarding (FDO) using the FDO
all-in-one packages.

## Demo setup
Edit `demo.conf`
Run the scripts

    cd ~/fdo-aio-demo
    sudo ./01-setup-rhel.sh
    sudo ./02-install-image-builder.sh

    ./03-prep-image-build.sh

    sudo ./04-install-fdo-aio.sh

## Create the ostree image
Create the base image

    composer-cli blueprints push edge-blueprint.toml
    composer-cli compose start-ostree Edge edge-container

Wait for about six minutes

## Build the ISO installer image
Download the container and import into local container storage

    composer-cli compose image <TAB>
    skopeo copy oci-archive:<UUID>-container.tar containers-storage:localhost/rfe-mirror:latest

Run the container image

    podman run --rm -p 8000:8080 rfe-mirror

While that's running, in another terminal window create the installer
ISO

    composer-cli blueprints push simplified-installer.toml
    composer-cli compose start-ostree SimplifiedInstall edge-simplified-installer \
                 --url http://$FDO_AIO_SERVER_IP:8000/repo/ 

Wait for about four minutes
When complete, use CTRL-C to stop the podman instance. Identify the
desired ISO installer and download it

    composer-cli compose status
    composer-cli compose image <UUID of ISO>

The ISO can be used to install an edge device. After installation
the device will use FDO to be provisioned.

