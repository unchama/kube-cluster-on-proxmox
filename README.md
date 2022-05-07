# kude-cluster-on-proxmox
Proxmox環境でサクッと作ってサクっと壊せる高可用性なkubernetesクラスタを作ってみる

# 前提条件

- Proxmox Virtual Environment 7.1-11
  - 3ノードクラスタ構成
- Ubuntu 20.04 LTS (cloud-init image)
  - kubernetes VMのベースとして使用
- Network Addressing(うんちゃま自宅検証環境)
  - Service Network Segment (172.16.0.0/20)
  - Storage Network Segment (172.16.16.0/22)
  - kubernetes
    - Internal
      - Pod Network (10.128.0.0/16)
      - Service Network (10.96.0.0/16)
    - External
      - Node IP
        - Service Network (172.16.3.0-172.16.3.127)
        - Storage Network (172.16.17.0-172.16.17.127)
      - API Endpoint (172.16.3.100)
      - NodeBalancer VIP (172.16.3.128-172.16.3.255)
    - 構成情報
      - kubelet,kubeadm,kubectl v1.23.6
      - cillium (Container Network Interface)
      - MetalLB (for LoadBalancer,L2 mode)
      - Synology CSI Driver for Kubernetes(未導入)

# 作成フロー

- proxmoxのホストコンソール上で`deploy-vm.sh`を実行すると、各種VMが沸く

  `/bin/bash <(curl -s https://raw.githubusercontent.com/unchama/kude-cluster-on-proxmox/main/deploy-vm.sh)`

- ローカル端末上で`~/.ssh/config`をセットアップ

```
Host <踏み台サーバーホスト名>
  HostName <踏み台サーバーホスト名>
  ProxyCommand cloudflared access ssh --hostname %h
  User <踏み台サーバーユーザー名>
  IdentityFile ~/.ssh/id_ed25519

Host unc-k8s-cp-1
  HostName 172.16.3.11
  User cloudinit
  IdentityFile ~/.ssh/id_ed25519
  ProxyCommand ssh -W %h:%p <踏み台サーバーホスト名>

Host unc-k8s-cp-2
  HostName 172.16.3.12
  User cloudinit
  IdentityFile ~/.ssh/id_ed25519
  ProxyCommand ssh -W %h:%p <踏み台サーバーホスト名>

Host unc-k8s-cp-3
  HostName 172.16.3.13
  User cloudinit
  IdentityFile ~/.ssh/id_ed25519
  ProxyCommand ssh -W %h:%p <踏み台サーバーホスト名>

Host unc-k8s-wk-1
  HostName 172.16.3.21
  User cloudinit
  IdentityFile ~/.ssh/id_ed25519
  ProxyCommand ssh -W %h:%p <踏み台サーバーホスト名>

Host unc-k8s-wk-2
  HostName 172.16.3.22
  User cloudinit
  IdentityFile ~/.ssh/id_ed25519
  ProxyCommand ssh -W %h:%p <踏み台サーバーホスト名>
```

- ローカル端末上でコマンド実行

```
# known_hosts再登録
ssh-keygen -R 172.16.3.11
ssh-keygen -R 172.16.3.12
ssh-keygen -R 172.16.3.13
ssh-keygen -R 172.16.3.21
ssh-keygen -R 172.16.3.22

# 接続チェック
ssh unc-k8s-cp-1 "hostname"
ssh unc-k8s-cp-2 "hostname"
ssh unc-k8s-cp-3 "hostname"
ssh unc-k8s-wk-1 "hostname"
ssh unc-k8s-wk-2 "hostname"

# cloudinitの実行ログチェック
ssh unc-k8s-cp-1 "sudo cat /var/log/cloud-init-output.log"
ssh unc-k8s-cp-2 "sudo cat /var/log/cloud-init-output.log"
ssh unc-k8s-cp-3 "sudo cat /var/log/cloud-init-output.log"
ssh unc-k8s-wk-1 "sudo cat /var/log/cloud-init-output.log"
ssh unc-k8s-wk-2 "sudo cat /var/log/cloud-init-output.log"
```

- ローカル端末上でコマンド実行

```
# join_kubeadm_cp.yaml を unc-k8s-cp-2 と unc-k8s-cp-3 にコピー
scp unc-k8s-cp-1:~/join_kubeadm_cp.yaml ./
scp ./join_kubeadm_cp.yaml unc-k8s-cp-2:~/
scp ./join_kubeadm_cp.yaml unc-k8s-cp-3:~/

# nc-k8s-cp-2 と unc-k8s-cp-3 で kubeadm join
ssh unc-k8s-cp-2 "sudo kubeadm join --config ~/join_kubeadm_cp.yaml"
ssh unc-k8s-cp-3 "sudo kubeadm join --config ~/join_kubeadm_cp.yaml"

# join_kubeadm_wk.yaml を unc-k8s-wk-1 と unc-k8s-wk-2 にコピー
scp unc-k8s-cp-1:~/join_kubeadm_wk.yaml ./
scp ./join_kubeadm_wk.yaml unc-k8s-wk-1:~/
scp ./join_kubeadm_wk.yaml unc-k8s-wk-2:~/

# nc-k8s-wk-1 と unc-k8s-wk-2 で kubeadm join
ssh unc-k8s-wk-1 "sudo kubeadm join --config ~/join_kubeadm_wk.yaml"
ssh unc-k8s-wk-2 "sudo kubeadm join --config ~/join_kubeadm_wk.yaml"
```

- 軽い動作チェック

```
ssh unc-k8s-cp-1 "kubectl get node && kubectl get pod -A"
```

# cleanup

```
# stop vm
qm stop 1001
qm stop 1002
qm stop 1003
qm stop 1101
qm stop 1102
# delete vm
qm destroy 9050 --destroy-unreferenced-disks true --purge true
qm destroy 1001 --destroy-unreferenced-disks true --purge true
qm destroy 1002 --destroy-unreferenced-disks true --purge true
qm destroy 1003 --destroy-unreferenced-disks true --purge true
qm destroy 1101 --destroy-unreferenced-disks true --purge true
qm destroy 1102 --destroy-unreferenced-disks true --purge true
```
