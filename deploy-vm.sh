#!/usr/bin/env bash

# region : set variables

TARGET_BRANCH=$1
TEMPLATE_VMID=9050
CLOUDINIT_IMAGE_TARGET_VOLUME=local-lvm
TEMPLATE_BOOT_IMAGE_TARGET_VOLUME=local-lvm
BOOT_IMAGE_TARGET_VOLUME=local-lvm
SNIPPET_TARGET_VOLUME=local
SNIPPET_TARGET_PATH=/var/lib/vz/snippets
REPOSITORY_RAW_SOURCE_URL="https://raw.githubusercontent.com/unchama/kube-cluster-on-proxmox/${TARGET_BRANCH}"
VM_LIST=(
    # ---
    # vmid:       proxmox上でVMを識別するID
    # vmname:     proxmox上でVMを識別する名称およびホスト名
    # cpu:        VMに割り当てるコア数(vCPU)
    # mem:        VMに割り当てるメモリ(MB)
    # vmsrvip:    VMのService Segment側NICに割り振る固定IP
    # vmsanip:    VMのStorage Segment側NICに割り振る固定IP
    # targetip:   VMの配置先となるProxmoxホストのIP
    # targethost: VMの配置先となるProxmoxホストのホスト名
    # ---
    #vmid #vmname      #cpu #mem  #vmsrvip    #vmsanip     #targetip    #targethost
    "1001 unc-k8s-cp-1 2    8192  172.16.3.11 172.16.17.11 172.16.16.112 sc-tst-proxmox-02"
    "1002 unc-k8s-cp-2 2    8192  172.16.3.12 172.16.17.12 172.16.16.112 sc-tst-proxmox-02"
    "1003 unc-k8s-cp-3 2    8192  172.16.3.13 172.16.17.13 172.16.16.112 sc-tst-proxmox-02"
    "1101 unc-k8s-wk-1 4    8192  172.16.3.21 172.16.17.21 172.16.16.112 sc-tst-proxmox-02"
    "1102 unc-k8s-wk-2 4    8192  172.16.3.22 172.16.17.22 172.16.16.112 sc-tst-proxmox-02"
    "1103 unc-k8s-wk-3 4    8192  172.16.3.23 172.16.17.23 172.16.16.112 sc-tst-proxmox-02"
)

# endregion

# ---

# region : create template-vm

# download the image(ubuntu 22.04 LTS)
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# create a new VM and attach Network Adaptor
# vmbr0=Service Network Segment (172.16.0.0/22)
# vmbr1=Storage Network Segment (172.16.16.0/22)
qm create $TEMPLATE_VMID --cores 2 --memory 4096 --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=vmbr1 --name unc-k8s-cp-template

# import the downloaded disk to $TEMPLATE_BOOT_IMAGE_TARGET_VOLUME storage
qm importdisk $TEMPLATE_VMID jammy-server-cloudimg-amd64.img $TEMPLATE_BOOT_IMAGE_TARGET_VOLUME

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
rm jammy-server-cloudimg-amd64.img

# endregion

# ---

# region : setup vm from template-vm

for array in "${VM_LIST[@]}"
do
    echo "${array}" | while read -r vmid vmname cpu mem vmsrvip vmsanip targetip targethost
    do
        # clone from template
        # in clone phase, can't create vm-disk to local volume
        qm clone "${TEMPLATE_VMID}" "${vmid}" --name "${vmname}" --full true --target "${targethost}"
        
        # set compute resources
        ssh -n "${targetip}" qm set "${vmid}" --cores "${cpu}" --memory "${mem}"

        # move vm-disk to local
        ssh -n "${targetip}" qm move-disk "${vmid}" scsi0 "${BOOT_IMAGE_TARGET_VOLUME}" --delete true

        # resize disk (Resize after cloning, because it takes time to clone a large disk)
        ssh -n "${targetip}" qm resize "${vmid}" scsi0 30G

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
  - su - cloudinit -c "sudo bash ~/k8s-node-setup.sh ${vmname} ${TARGET_BRANCH}"
  # change default shell to bash
  - chsh -s $(which bash) cloudinit
EOF
# ----- #
        # END irregular indent because heredoc

        # create snippet for cloud-init(network-config)
        # START irregular indent because heredoc
# ----- #
cat > "$SNIPPET_TARGET_PATH"/"$vmname"-network.yaml << EOF
version: 1
config:
  - type: physical
    name: ens18
    subnets:
    - type: static
      address: '${vmsrvip}'
      netmask: '255.255.240.0'
      gateway: '172.16.3.254'
  - type: physical
    name: ens19
    subnets:
    - type: static
      address: '${vmsanip}'
      netmask: '255.255.252.0'
  - type: nameserver
    address:
    - '10.255.0.1'
    - '10.255.0.2'
    search:
    - 'local'
EOF
# ----- #
        # END irregular indent because heredoc

        # set snippet to vm
        ssh -n "${targetip}" qm set "${vmid}" --cicustom "user=${SNIPPET_TARGET_VOLUME}:snippets/${vmname}-user.yaml,network=${SNIPPET_TARGET_VOLUME}:snippets/${vmname}-network.yaml"

    done
done

for array in "${VM_LIST[@]}"
do
    echo "${array}" | while read -r vmid vmname cpu mem vmsrvip vmsanip targetip targethost
    do
        # start vm
        ssh -n "${targetip}" qm start "${vmid}"
        
    done
done

# endregion
