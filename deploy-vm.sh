#!/usr/bin/env bash

# region : set variables

TARGET_BRANCH=$1
TEMPLATE_VMID=9050
CLOUDINIT_IMAGE_TARGET_VOLUME=tst-network-01-lun01
TEMPLATE_BOOT_IMAGE_TARGET_VOLUME=tst-network-01-lun01
BOOT_IMAGE_TARGET_VOLUME=local-lvm
SNIPPET_TARGET_VOLUME=unchama-tst-prox-bkup01
SNIPPET_TARGET_PATH=/mnt/pve/${SNIPPET_TARGET_VOLUME}/snippets
REPOSITORY_RAW_SOURCE_URL="https://raw.githubusercontent.com/unchama/kube-cluster-on-proxmox/${TARGET_BRANCH}"
VM_LIST=(
    #vmid #vmname      #cpu #mem  #targetip    #targethost
    "1001 unc-k8s-cp-1 2    8192  172.16.16.111 unchama-tst-prox01"
    "1002 unc-k8s-cp-2 2    8192  172.16.16.113 unchama-tst-prox03"
    "1003 unc-k8s-cp-3 2    8192  172.16.16.114 unchama-tst-prox04"
    "1101 unc-k8s-wk-1 4    12288 172.16.16.111 unchama-tst-prox01"
    "1102 unc-k8s-wk-2 4    12288 172.16.16.113 unchama-tst-prox03"
    "1103 unc-k8s-wk-3 4    12288 172.16.16.114 unchama-tst-prox04"
)

# endregion

# ---

# region : create template-vm

# download the image(ubuntu 20.04 LTS)
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img

# create a new VM and attach Network Adaptor
# vmbr0=Service Network Segment (172.16.0.0/20)
# vmbr1=Storage Network Segment (172.16.16.0/22)
qm create $TEMPLATE_VMID --cores 2 --memory 4096 --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=vmbr1 --name unc-k8s-cp-template

# import the downloaded disk to $TEMPLATE_BOOT_IMAGE_TARGET_VOLUME storage
qm importdisk $TEMPLATE_VMID focal-server-cloudimg-amd64.img $TEMPLATE_BOOT_IMAGE_TARGET_VOLUME

# finally attach the new disk to the VM as scsi drive
qm set $TEMPLATE_VMID --scsihw virtio-scsi-pci --scsi0 $TEMPLATE_BOOT_IMAGE_TARGET_VOLUME:vm-$TEMPLATE_VMID-disk-0

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

# endregion

# ---

# region : setup vm from template-vm

for array in "${VM_LIST[@]}"
do
    echo "${array}" | while read -r vmid vmname cpu mem targetip targethost
    do
        # clone from template
        # in clone phase, can't create vm-disk to local volume
        qm clone "${TEMPLATE_VMID}" "${vmid}" --name "${vmname}" --full true --target "${targethost}"
        
        # set compute resources
        ssh "${targetip}" qm set "${vmid}" --cores "${cpu}" --memory "${mem}"

        # move vm-disk to local
        ssh "${targetip}" qm move-disk "${vmid}" scsi0 "${BOOT_IMAGE_TARGET_VOLUME}" --delete true

        # resize disk (Resize after cloning, because it takes time to clone a large disk)
        ssh "${targetip}" qm resize "${vmid}" scsi0 30G

        # create snippet for cloud-init(user-config)
        # START irregular indent because heredoc
# ----- #
cat > "$SNIPPET_TARGET_PATH"/"$vmname"-user.yaml << EOF
#cloud-config
hostname: ${vmname}
timezone: Asia/Tokyo
manage_etc_hosts: true
chpasswd:
  expire: False
users:
  - default
  - name: cloudinit
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    # mkpasswd --method=SHA-512 --rounds=4096
    # password is zaq12wsx
    passwd: \$6\$rounds=4096\$Xlyxul70asLm\$9tKm.0po4ZE7vgqc.grptZzUU9906z/.vjwcqz/WYVtTwc5i2DWfjVpXb8HBtoVfvSY61rvrs/iwHxREKl3f20
ssh_pwauth: true
ssh_authorized_keys: []
package_upgrade: true
runcmd:
  # set ssh_authorized_keys
  - su - cloudinit -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
  - su - cloudinit -c "curl -sS https://github.com/unchama.keys >> ~/.ssh/authorized_keys"
  - su - cloudinit -c "curl -sS https://github.com/inductor.keys >> ~/.ssh/authorized_keys"
  - su - cloudinit -c "curl -sS https://github.com/kory33.keys >> ~/.ssh/authorized_keys"
  - su - cloudinit -c "chmod 600 ~/.ssh/authorized_keys"
  # run install scripts
  - su - cloudinit -c "curl -s ${REPOSITORY_RAW_SOURCE_URL}/scripts/k8s-node-setup.sh > ~/k8s-node-setup.sh"
  - su - cloudinit -c "sudo bash ~/k8s-node-setup.sh ${vmname}"
EOF
# ----- #
        # END irregular indent because heredoc
        
        # download snippet for cloud-init(network)
        curl -s "${REPOSITORY_RAW_SOURCE_URL}/snippets/${vmname}-network.yaml" > "${SNIPPET_TARGET_PATH}"/"${vmname}"-network.yaml

        # set snippet to vm
        ssh "${targetip}" qm set "${vmid}" --cicustom "user=${SNIPPET_TARGET_VOLUME}:snippets/${vmname}-user.yaml,network=${SNIPPET_TARGET_VOLUME}:snippets/${vmname}-network.yaml"

    done
done

for array in "${VM_LIST[@]}"
do
    echo "${array}" | while read -r vmid vmname cpu mem targetip targethost
    do
        # start vm
        ssh "${targetip}" qm start "${vmid}"
        
    done
done

# endregion
