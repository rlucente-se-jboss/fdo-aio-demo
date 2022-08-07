# fdo-aio-demo
This demonstrates FIDO Device Onboarding (FDO) using the FDO
all-in-one packages on RHEL 8/9. This demonstration will build an
ISO installer for an edge device and then leverage the FDO protocol
to provision the device with the [How's My Salute](https://github.com/tedbrunell/HowsMySalute)
application and a timer to periodically check for application
updates. After FDO provisioning, the edge device will run the
application in kiosk mode. You'll need an external USB webcam and
monitor for this demonstration.

## Install a RHEL instance for the FDO server
Start with a minimal install of RHEL 8 or 9. Make sure this repository
is copied to your RHEL host. You'll run two virtual or physical
machines. If running virtual machines on the same host for this
demo, please ensure that there are adequate resources for them. My
personal laptop has 32 GB of memory and 8 cores (16 hyperthreads)
so I allocate the following to the guest VMs:

* RHEL guest for image-builder, registry, and FDO server: 10 GB, 6 vCPUs
* Edge RHEL guest: 6 GB, 2 vCPUs

The two VMs will collectively consume half the resources for my
laptop.

The two VMs will need to communicate with one another. Only the FDO
server RHEL guest needs outside connectivity. How you do this depends
on your virtualization solution. I use VirtualBox on my OSX laptop
so I configure networking like so:

* FDO Server RHEL guest: one NAT interface and one host-only interface
* Edge RHEL guest: one host-only interface

During the FDO server RHEL installation, configure a regular user
with `sudo` privileges.

### Adjust demo settings
These instructions assume that the `fdo-aio-demo` git repository
is copied to your own home directory on the RHEL FDO server.

You'll need to customize the settings in the `demo.conf` script to
include your Red Hat Subscription Manager (RHSM) credentials to
login to the [customer support portal](https://access.redhat.com)
to pull updated content. The `FDO_SERVER` setting should be an
address that the edge device will use to communicate with the FDO
server. On my laptop, this is the IP address assigned to the host-only
network interface on the FDO server. The `EDGE_USER`, `EDGE_PASS`,
and `EDGE_STORAGE_DEV` parameters define the login information for
the virtual edge device as well as the base storage device. The
default storage device is correct for VirtualBox but may be different
for another solution. Finally, the EDGE_CLIENT is the IP address
for the edge device itself. My VirtualBox host-only DHCP server is
configured to give predictable IP addresses to both the FDO server
and the Edge client. Make sure to do something similar for your
environment and/or adjust both the `FDO_SERVER` and `EDGE_CLIENT`
settings in the `demo.conf` file.

## Configure the FDO server
The shell scripts included in this repository handle setting up all
the dependencies to support the demo. To begin, go to the directory
hosting this repository.

    cd ~/fdo-aio-demo

The first script registers with the [Red Hat Customer Portal](https://access.redhat.com)
using the credentials provided in the `demo.conf` file. All packages
are updated. It's a good idea to reboot after as the kernel may
have been updated.

    sudo ./01-setup-rhel.sh
    reboot

The second script installs several packages including the rpm-ostree
image builder as well as enabling the web console with the image
builder plugin. The web console can be accessed via the
https://YOUR-FDO-SERVER-IP-ADDR-OR-NAME:9090 URL. The current user
is added to the `weldr` group to support use of image builder within
the web console. Please make sure to log out and then log in again
to update the group memberships for your session.

    cd ~/fdo-aio-demoa
    sudo ./02-install-image-builder.sh
    exit

The third script configures a docker v2 registry to enable edge
devices to pull container images without requiring external network
access.  Once this demo is installed, I can easily run it using the
host-only network features of virtualbox without external connectivity.

    sudo ./03-config-registry.sh

Test that the container registry is up and running using the following
command:

    curl -s http://YOUR-FDO-SERVER-IP-ADDR-OR-NAME:5000/v2/_catalog | jq

The fourth script generates the blueprint files needed to create
the rpm-ostree image and then later package it as an ISO installer.

    ./04-prep-image-build.sh

The fifth script builds the [How's My Salute](https://github.com/tedbrunell/HowsMySalute)
demo as a containerized application. The USMC version is tagged as
`prod` with the intent of moving that tag from one version to another
to trigger application updates on the edge device. This is discussed
later.

    sudo ./05-build-containers.sh

Verify that the application is in the registry using the following
command:

    curl -s http://YOUR-FDO-SERVER-IP-ADDR-OR-NAME:5000/v2/_catalog | jq

The sixth and final script installs and configures the FDO all-in-one
service. To configure the edge device, the script relies on the
files in the `device0` folder as well as the
`serviceinfo_api_server.yml.template` file for the installation
commands.

NB: Generating the systemd service file for the application requires
creating a container. The container creation will fail if no webcam
device is attached to the FDO server. Make sure when running this
script that a webcam is attached and the `/dev/video0` device exists.

Run the script to install and configure the FDO all-in-one components
and setup the edge device FDO configuration files..

    sudo ./06-install-fdo-aio.sh

After the script is run, you can review the content of the files
used to configure the edge device.

    find /etc/device0/cfg -type f -print -exec cat {} \; | less
    less /etc/fdo/aio/configs/serviceinfo_api_server.yml

At this point, the needed software components have been installed
to support the demo.

## Create the rpm-ostree image
Now, we'll use the instructions in the `edge-blueprint` file to
create the rpm-ostree image for the edge device. The rpm-ostree
image will be packaged within an OCI container with an associated
web application so that we can easily serve the content to the next
stage in the build to create the ISO installer. Let's first push
the blueprint to the image builder and then start the compose.

    composer-cli blueprints push edge-blueprint.toml
    composer-cli compose start-ostree Edge edge-container

On my laptop, the compose takes about six minutes to complete but
your mileage may vary. You can watch the status of the submitted
job using:

    watch composer-cli compose status

When the status is `FINISHED`, use CTRL-C to stop the above command.

## Build the ISO installer image
Next, we'll download the rpm-ostree image packaged inside an OCI
container and then run the container application to support the
creation of the ISO installer.

If there are multiple rpm-ostree image on your host, use the
following command to identify the correct one.

    composer-cli compose status

On my system, the output looks like the following where the UUID
is the first column:

    $ composer-cli compose status
    c11e41be-b6f0-4813-8eb4-a6094de1eb86 FINISHED Thu Jul 7 19:15:40 2022 Edge            0.0.1 edge-container

If there's only one rpm-ostree image, you can simply hit tab on the
following command to autofill the UUID of the image to download.

    composer-cli compose image <TAB>

We'll copy the compressed OCI container to our local container
storage and then run the container to provide rpm-ostree content
to support the creation of the ISO installer.

    skopeo copy oci-archive:<UUID>-container.tar containers-storage:localhost/rfe-mirror:latest
    podman run --rm -p 8000:8080 rfe-mirror

Once the container is running, in a separate terminal window go
ahead and kickoff the ISO installer build. The build will use the
simplified installer to create the ISO installer. The simplified
installer will simply copy content directly to the edge device
storage device without the need for a kickstart file.

To start the build, push the blueprint to the image builder service
and then launch the compose as shown below.

    composer-cli blueprints push simplified-installer.toml
    composer-cli compose start-ostree SimplifiedInstall edge-simplified-installer \
                 --url http://YOUR-FDO-SERVER-IP-ADDR-OR-NAME:8000/repo/

The compose for the ISO installer takes around four minutes on my
laptop. Again, your mileage may vary. You can monitor the build
using the command:

    watch composer-cli compose status

When the status is `FINISHED`, use CTRL-C to stop the above command.
In the other terminal window, use CTRL-C to stop the podman instance.

## Download the ISO installer
Identify the ISO installer image using the command:

    composer-cli compose status

On my system, the output looks like the following where the UUID
is the first column:

    $ composer-cli compose status
    c11e41be-b6f0-4813-8eb4-a6094de1eb86 FINISHED Thu Jul 7 19:15:40 2022 Edge            0.0.1 edge-container
    580f7278-2e06-43c2-bd4f-2957d66df0d6 FINISHED Thu Jul 7 19:27:10 2022 SimplifiedInstall 0.0.1 edge-simplified-installer 10737418240

Download the ISO installer using the command:

    composer-cli compose image <INSTALLER-UUID>

The ISO can now be used to install an edge device. I subsequently
downloaded this ISO file from the RHEL host VM to my laptop so I
could use it to install a second VM for the edge device.

## Demonstrate FIDO Device Onboarding (FDO)
The process and steps necessary for FDO are explained in the
[Red Hat Enterprise Linux documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/composing_installing_and_managing_rhel_for_edge_images/assembly_automatically-provisioning-and-onboarding-rhel-for-edge-devices_composing-installing-managing-rhel-for-edge-images#doc-wrapper).
The above setup has reached step 9 in
[7.2. Automatically provisioning and onboarding RHEL for Edge devices](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/composing_installing_and_managing_rhel_for_edge_images/assembly_automatically-provisioning-and-onboarding-rhel-for-edge-devices_composing-installing-managing-rhel-for-edge-images#con_automatically-provisioning-and-onboarding-rhel-for-edge-devices_assembly_automatically-provisioning-and-onboarding-rhel-for-edge-devices)
of the FDO process description.

### Monitor the server processes
It's helpful to watch the various components of the FDO process
interact during device initialization and then onboarding. Open a
terminal window to your FDO server and type the following commands:

    cd /etc/fdo/aio/logs
    sudo truncate -s 0 *.log
    watch ls -lat

You'll now be monitoring the logs of the various FDO applications
and you'll be able to see when they are updated during the process.

### Create and boot a virtual edge device
You'll need to create and boot a virtual or a physical edge device
that can reach your FDO server. I create a virtual edge device using
VirtualBox on my Mac laptop for this and there's too much to describe
here on how to create and launch a virtual machine. For this demo,
the edge device (physical or virtual) must meet the following
criteria:

* Available network connectivity between the FDO server and the edge device
* Ability to monitor the edge device during installation and reboot (a virtual console or monitor for physical device)
* The ISO installer is accessible to the edge device (on VirtualBox it's a bootable virtual CD/DVD)

The above conditions are invaluable to determine where a problem
lies if the edge device does not provision.

NB: These instructions have not been tested with a physical device
(yet).

### Observe the FDO process during edge device initial boot
When the edge device is first booted, the simplified ISO installer
will copy the rpm-ostree image contents directly to the edge device
storage. A short handshake will occur between the edge device and
the manufacturing server to perform the initial device credential
exchange. The edge device will then poweroff. The manufacturing
server, onboarding server, and rendezvous server will also have
those keys set to support provisioning the device when it is rebooted.

The FDO onboarding process supports "late binding" where the edge
device can be given just enough configuration at time of manufacture
to support full on-boarding once it arrives at its intended
destination. It's not necessary to fully provision the device all
at once and the provisioning instructions can be changed between
the time of manufacture and the first boot in the field, giving a
lot of flexibility to the eventual device owner. FDO also supports,
via the use of certs and keys, the ability to do Device Initialization
over Untrusted Networks (DIUN). This demo does not show DIUN.

### Boot and provision the edge device
Modify the edge device to remove the ISO installer. On VirtualBox,
I simply remove the file from the virtual CD/DVD. Take whatever
action is appropriate for your scenario.

Next, if the `watch` command from above is still running on the FDO
server, terminate it using CTRL-C and then truncate the logs and
restart monitoring on the FDO server using the commands:

    cd /etc/fdo/aio/logs
    sudo truncate -s 0 *.log
    watch ls -lat

Start the edge device and watch the logs. The changes will occur
quickly but what you should see is that the edge device contacts the rendezvous
server to determine it's owner, the device and owner use shared
credentials to authenticate to one another and then the owner uses
the serviceinfo API server to provision the edge device. If this
all works correctly, you'll see a container application start on
the edge device in its console.

### Verify the edge device is provisioned
You can test that the edge device is provisioned by sending a request
to the simple container web application that is a part of the device
provisioning.  If the `watch` command from above is still running
on the FDO server, terminate it using CTRL-C and then type the
following commands to test the web application on the edge device:

    curl http://YOUR-EDGE-DEVICE-IP-ADDR-OR-NAME:8080

where you substitute the correct IP address or DNS name for your
edge device.

### Demonstrate podman auto-update
There are actually two versions of the container web application
that can run on the edge device. Both versions reside in the local
container registry running on the FDO server. This is an additional
component to support this demo and not a typical item for the FDO
server. The edge device has a slightly modified podman-auto-update
systemd service that checks the container registry every thirty
seconds and then, if the application is different than what's
currently running, downloads the new container image and restarts
the application.

To initiate this, use the following commands in the FDO server
terminal window:

    REGADDR=YOUR-FDO-SERVER-IP-ADDR-OR-NAME
    podman pull --all-tags $REGADDR:5000/howsmysalute
    podman tag $REGADDR:5000/howsmysalute:army $REGADDR:5000/howsmysalute:prod
    podman push $REGADDR:5000/howsmysalute:prod

In the edge device console, you should see the How's My Salute application
restart within thirty seconds.

To test the application, browse to the application on the edge
device to test your salute at the
http://YOUR-EDGE-DEVICE-IP-ADDR-OR-NAME:8080/ URL.

The application should check an Army salute instead of a USMC one.

# TODO
* initiate update to underlying rpm-ostree image as well
* add quasi-serverless on-demand activation/deactivation to web application
