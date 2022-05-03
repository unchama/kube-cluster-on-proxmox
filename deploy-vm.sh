#!/bin/bash

# region00 : set variables

KUBE_API_SERVER_VIP=172.16.3.100
NODE_IP_K8S_CP=( 172.16.3.11 172.16.3.12 172.16.3.13 )

TEMPLATE_VMID=9050
CLOUDINIT_IMAGE_TARGET_VOLUME=tst-network-01-lun01
BOOT_IMAGE_TARGET_VOLUME=tst-network-01-lun01

# end region

# ---

# region01 : create-template

# download the image
wget https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img

# create a new VM and attach Network Adaptor
qm create $TEMPLATE_VMID --memory 2048 --net0 virtio,bridge=vmbr0

# import the downloaded disk to $BOOT_IMAGE_TARGET_VOLUME storage
qm importdisk $TEMPLATE_VMID bionic-server-cloudimg-amd64.img $BOOT_IMAGE_TARGET_VOLUME

# finally attach the new disk to the VM as scsi drive
qm set $TEMPLATE_VMID --scsihw virtio-scsi-pci --scsi0 $BOOT_IMAGE_TARGET_VOLUME:vm-$TEMPLATE_VMID-disk-0

# add Cloud-Init CD-ROM drive
qm set $TEMPLATE_VMID --ide2 $CLOUDINIT_IMAGE_TARGET_VOLUME:cloudinit

# set the bootdisk parameter to scsi0
qm set $TEMPLATE_VMID --boot c --bootdisk scsi0

# set serial console
qm set $TEMPLATE_VMID --serial0 socket --vga serial0

# migrate to template
qm template $TEMPLATE_VMID

# cleanup
rm bionic-server-cloudimg-amd64.img

# end region

# ---

# region02 : create vm from template



# end region