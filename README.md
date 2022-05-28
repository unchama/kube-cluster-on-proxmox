# kube-cluster-on-proxmox
Proxmox環境でサクッと作ってサクっと壊せる高可用性なkubernetesクラスタを作ってみる

## 前提条件

- Proxmox Virtual Environment 7.1-11
  - 3ノードクラスタ構成
- Synology NAS(DS1621+)
  - 共有ストレージとして利用
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
      - LoadBalancer VIP (172.16.3.128-172.16.3.255)
- kubernetes構成情報
  - kubelet,kubeadm,kubectl v1.24.0
  - cillium (Container Network Interface)
  - MetalLB (for LoadBalancer,L2 mode)
  - Synology CSI Driver for Kubernetes(未導入)
  - argoCD(未導入)
    - かんがえちう
  - etcdのデイリーバックアップ(未導入)

## 作成フロー

- 以下は本リポジトリのサクッと作ってサクッと壊す対象外なので別途用意しておく
  - ベアメタルなProxmox環境の構築
  - Snippetが配置可能な共有ストレージの構築
  - VM Diskが配置可能な共有ストレージの構築
  - Network周りの構築

- proxmoxのホストコンソール上で`deploy-vm.sh`を実行すると、各種VMが沸きます。`TARGET_BRANCH`はデプロイ対象のコードが反映されたブランチ名に変更してください。


```sh
export TARGET_BRANCH=main
/bin/bash <(curl -s https://raw.githubusercontent.com/unchama/kube-cluster-on-proxmox/${TARGET_BRANCH}/deploy-vm.sh) ${TARGET_BRANCH}
```

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

Host unc-k8s-wk-3
  HostName 172.16.3.23
  User cloudinit
  IdentityFile ~/.ssh/id_ed25519
  ProxyCommand ssh -W %h:%p <踏み台サーバーホスト名>
```

- ローカル端末上でコマンド実行

```sh
# known_hosts登録削除(VM作り直す度にホスト公開鍵が変わる為)
ssh-keygen -R 172.16.3.11
ssh-keygen -R 172.16.3.12
ssh-keygen -R 172.16.3.13
ssh-keygen -R 172.16.3.21
ssh-keygen -R 172.16.3.22
ssh-keygen -R 172.16.3.23

# 接続チェック(ホスト公開鍵の登録も兼ねる)
ssh unc-k8s-cp-1 "hostname"
ssh unc-k8s-cp-2 "hostname"
ssh unc-k8s-cp-3 "hostname"
ssh unc-k8s-wk-1 "hostname"
ssh unc-k8s-wk-2 "hostname"
ssh unc-k8s-wk-3 "hostname"

# 最初のコントロールプレーンのkubeadm initが終わっているかチェック
ssh unc-k8s-cp-1 "kubectl get node -o wide && kubectl get pod -A -o wide"

# cloudinitの実行ログチェック(トラブルシュート用)
ssh unc-k8s-cp-1 "sudo cat /var/log/cloud-init-output.log"
ssh unc-k8s-cp-2 "sudo cat /var/log/cloud-init-output.log"
ssh unc-k8s-cp-3 "sudo cat /var/log/cloud-init-output.log"
ssh unc-k8s-wk-1 "sudo cat /var/log/cloud-init-output.log"
ssh unc-k8s-wk-2 "sudo cat /var/log/cloud-init-output.log"
ssh unc-k8s-wk-3 "sudo cat /var/log/cloud-init-output.log"
```

- ローカル端末上でコマンド実行

```sh
# join_kubeadm_cp.yaml を unc-k8s-cp-2 と unc-k8s-cp-3 にコピー
scp -3 unc-k8s-cp-1:~/join_kubeadm_cp.yaml unc-k8s-cp-2:~/
scp -3 unc-k8s-cp-1:~/join_kubeadm_cp.yaml unc-k8s-cp-3:~/

# unc-k8s-cp-2 と unc-k8s-cp-3 で kubeadm join
ssh unc-k8s-cp-2 "sudo kubeadm join --config ~/join_kubeadm_cp.yaml"
ssh unc-k8s-cp-3 "sudo kubeadm join --config ~/join_kubeadm_cp.yaml"

# unc-k8s-cp-2 と unc-k8s-cp-3 で cloudinitユーザー用にkubeconfigを準備
ssh unc-k8s-cp-2 "mkdir -p \$HOME/.kube && sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config &&sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
ssh unc-k8s-cp-3 "mkdir -p \$HOME/.kube && sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config &&sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"

# join_kubeadm_wk.yaml を unc-k8s-wk-1 と unc-k8s-wk-2 と unc-k8s-wk-3 にコピー
scp -3 unc-k8s-cp-1:~/join_kubeadm_wk.yaml unc-k8s-wk-1:~/
scp -3 unc-k8s-cp-1:~/join_kubeadm_wk.yaml unc-k8s-wk-2:~/
scp -3 unc-k8s-cp-1:~/join_kubeadm_wk.yaml unc-k8s-wk-3:~/

# nc-k8s-wk-1 と unc-k8s-wk-2 と unc-k8s-wk-3 で kubeadm join
ssh unc-k8s-wk-1 "sudo kubeadm join --config ~/join_kubeadm_wk.yaml"
ssh unc-k8s-wk-2 "sudo kubeadm join --config ~/join_kubeadm_wk.yaml"
ssh unc-k8s-wk-3 "sudo kubeadm join --config ~/join_kubeadm_wk.yaml"
```

- 軽い動作チェック

```sh
ssh unc-k8s-cp-1 "kubectl get node -o wide && kubectl get pod -A -o wide"
ssh unc-k8s-cp-2 "kubectl get node -o wide && kubectl get pod -A -o wide"
ssh unc-k8s-cp-3 "kubectl get node -o wide && kubectl get pod -A -o wide"
```

### ArgoCDへのアクセス

- ローカル端末上で以下コマンドを実行してargoCDの初期パスワードを取得する

```sh
ssh unc-k8s-cp-1 "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d"
```

- ローカル端末上でssh-portforward用の`~/.ssh/config`をセットアップ。ちなみに、LocalForward先のIPアドレスは[ここ](./k8s-manifests/apps/cluster-wide-app-resources/argocd-server-lb.yaml)で定義している

```
Host <踏み台サーバーホスト名>
  HostName <踏み台サーバーホスト名>
  ProxyCommand cloudflared access ssh --hostname %h
  User <踏み台サーバーユーザー名>
  IdentityFile ~/.ssh/id_ed25519

Host unc-k8s-cp-1_fwd
  HostName 172.16.3.11
  User cloudinit
  IdentityFile ~/.ssh/id_ed25519
  ProxyCommand ssh -W %h:%p <踏み台サーバーホスト名>
  # ArgoCD web-panel
  LocalForward 4430 172.16.3.240:443
```

- トンネル用のSSHセッションを開始する

```sh
ssh unc-k8s-cp-1_fwd
```

- ローカルブラウザで(https://localhost:4430)にアクセスし、ユーザーID`admin`でログインする。パスワードは先の手順で取得した初期パスワードを使用する

- Enjoy;)

## クラスタの削除

- proxmoxのホストコンソール上で以下コマンド実行。ノードローカルにいるVMしか操作できない為、全てのノードで打って回る。

```sh
# stop vm
## on unchama-tst-prox01
ssh 172.16.0.111 qm stop 1001
ssh 172.16.0.111 qm stop 1101

## on unchama-tst-prox03
ssh 172.16.0.113 qm stop 1002
ssh 172.16.0.113 qm stop 1102

## on unchama-tst-prox04
ssh 172.16.0.114 qm stop 1003
ssh 172.16.0.114 qm stop 1103

# delete vm
## on unchama-tst-prox01
ssh 172.16.0.111 qm destroy 1001 --destroy-unreferenced-disks true --purge true
ssh 172.16.0.111 qm destroy 1101 --destroy-unreferenced-disks true --purge true
ssh 172.16.0.111 qm destroy 9050 --destroy-unreferenced-disks true --purge true

## wait due to prevent to cluster-data mismatch on proxmox
sleep 20s

## on unchama-tst-prox03
ssh 172.16.0.113 qm destroy 1002 --destroy-unreferenced-disks true --purge true
ssh 172.16.0.113 qm destroy 1102 --destroy-unreferenced-disks true --purge true

## wait due to prevent to cluster-data mismatch on proxmox
sleep 20s

## on unchama-tst-prox04
ssh 172.16.0.114 qm destroy 1003 --destroy-unreferenced-disks true --purge true
ssh 172.16.0.114 qm destroy 1103 --destroy-unreferenced-disks true --purge true

```
## クラスタの削除後、クラスタの再作成に失敗する場合

クラスタの削除後、同じVMIDでVMを再作成できず、クラスタの作成に失敗することがあります。

これは、クラスタの削除時に複数ノードでコマンド`qm destroy`が実行された際に、Device Mapperで生成された仮想ディスクデバイスの一部が消えずに残留することがあるためです。

上記事象に遭遇した場合は、以下**いずれか**の方法で解決を試みてください。

 - 残った仮想ディスクデバイスを手動で削除する

    1. クラスタを構成するVMが一部でも存在する場合は、事前にクラスタの削除を実施してください。

    1. その後、**proxmoxをホストしている物理マシンのターミナル上で**次のコマンドを実行し、残ったデバイスを削除します。

       ```sh
       for host in 172.16.0.111 172.16.0.113 172.16.0.114 ; do
         ssh $host dmsetup remove vg01-vm--1101--cloudinit
         ssh $host dmsetup remove vg01-vm--1102--cloudinit
         ssh $host dmsetup remove vg01-vm--1103--cloudinit

         ssh $host dmsetup remove vg01-vm--1001--cloudinit
         ssh $host dmsetup remove vg01-vm--1002--cloudinit
         ssh $host dmsetup remove vg01-vm--1003--cloudinit

         ssh $host dmsetup remove vg01-vm--1101--disk--0
         ssh $host dmsetup remove vg01-vm--1102--disk--0
         ssh $host dmsetup remove vg01-vm--1103--disk--0

         ssh $host dmsetup remove vg01-vm--1001--disk--0
         ssh $host dmsetup remove vg01-vm--1002--disk--0
         ssh $host dmsetup remove vg01-vm--1003--disk--0
       done
       ```

   参考: [cannot migrate - device-mapper:create ioctl on cluster failed - proxmox forum](https://forum.proxmox.com/threads/cannot-migrate-device-mapper-create-ioctl-on-cluster-failed.12221/)

 - 全proxmoxホストを再起動する

   proxmoxホスト上の全てのVMの停止を伴うため、サービス提供中の本番環境では推奨されません。


## etc

- 起動用コマンドめも

```sh
## on unchama-tst-prox01
ssh 172.16.0.111 qm start 1001
ssh 172.16.0.111 qm start 1101

## on unchama-tst-prox03
ssh 172.16.0.113 qm start 1002
ssh 172.16.0.113 qm start 1102

## on unchama-tst-prox04
ssh 172.16.0.114 qm start 1003
ssh 172.16.0.114 qm start 1103
```
