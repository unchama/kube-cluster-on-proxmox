# kude-cluster-on-proxmox
Proxmox環境でサクッと作ってサクっと壊せる高可用性なkubernetesクラスタを作ってみる

# 前提条件

- Proxmox Virtual Environment 7.1-11
- Ubuntu 20.04 LTS (cloud-init image)
- Network Addressing(検証環境)
  - Service Network Segment (172.16.0.0/20)
  - Storage Network Segment (172.16.16.0/22)
  - kubernetes
    - Internal
      - Pod Network ()
      - Service Network ()
    - External
      - Node IP(172.16.3.0/24)
      - API Endpoint(172.16.3.100/24)

# 作成フロー

- proxmoxのホストコンソール上で`deploy-vm.sh`を実行すると、各種VMが沸く
