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

# download the image(ubuntu 20.04 LTS)
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img

# create a new VM and attach Network Adaptor
qm create $TEMPLATE_VMID --memory 2048 --net0 virtio,bridge=vmbr0

# import the downloaded disk to $BOOT_IMAGE_TARGET_VOLUME storage
qm importdisk $TEMPLATE_VMID focal-server-cloudimg-amd64.img $BOOT_IMAGE_TARGET_VOLUME

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
rm focal-server-cloudimg-amd64.img

# end region

# ---

# region02 : create vm from template

# clone from template
qm clone $TEMPLATE_VMID 1001 --name unc-k8s-cp-1 --full true
# resize disk (Resize after cloning, because it takes time to clone a large disk)
qm resize 1001 scsi0 30G
# set snippets
curl -s https://raw.githubusercontent.com/unchama/kude-cluster-on-proxmox/main/snippets/unc-k8s-cp-1-user.yaml > /var/lib/vz/snippets/unc-k8s-cp-1-user.yaml
curl -s https://raw.githubusercontent.com/unchama/kude-cluster-on-proxmox/main/snippets/unc-k8s-cp-1-network.yaml > /var/lib/vz/snippets/unc-k8s-cp-1-network.yaml
qm set 1001 --cicustom "user=local:snippets/unc-k8s-cp-1-user.yaml,network=local:snippets/unc-k8s-cp-1-network.yaml"

# clone from template
qm clone $TEMPLATE_VMID 1002 --name unc-k8s-cp-2 --full true
# resize disk (Resize after cloning, because it takes time to clone a large disk)
qm resize 1002 scsi0 30G
# set snippets
curl -s https://raw.githubusercontent.com/unchama/kude-cluster-on-proxmox/main/snippets/unc-k8s-cp-2-user.yaml > /var/lib/vz/snippets/unc-k8s-cp-2-user.yaml
curl -s https://raw.githubusercontent.com/unchama/kude-cluster-on-proxmox/main/snippets/unc-k8s-cp-2-network.yaml > /var/lib/vz/snippets/unc-k8s-cp-2-network.yaml
qm set 1002 --cicustom "user=local:snippets/unc-k8s-cp-2-user.yaml,network=local:snippets/unc-k8s-cp-2-network.yaml"

# clone from template
qm clone $TEMPLATE_VMID 1003 --name unc-k8s-cp-3 --full true
# resize disk (Resize after cloning, because it takes time to clone a large disk)
qm resize 1003 scsi0 30G
# set snippets
curl -s https://raw.githubusercontent.com/unchama/kude-cluster-on-proxmox/main/snippets/unc-k8s-cp-3-user.yaml > /var/lib/vz/snippets/unc-k8s-cp-3-user.yaml
curl -s https://raw.githubusercontent.com/unchama/kude-cluster-on-proxmox/main/snippets/unc-k8s-cp-3-network.yaml > /var/lib/vz/snippets/unc-k8s-cp-3-network.yaml
qm set 1003 --cicustom "user=local:snippets/unc-k8s-cp-3-user.yaml,network=local:snippets/unc-k8s-cp-3-network.yaml"

# start vm
qm start 1001
qm start 1002
qm start 1003

# end region
