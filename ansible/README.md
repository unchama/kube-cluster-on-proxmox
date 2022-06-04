# ansible

## ansibleを使うモチベーション

 - cloud-initだけだとk8sクラスタセットアップの全ての作業を完遂できない
 - この部分をansibleでシュッとやりたい

## ざっと構想

 - cloud-initでセットアップされるホストはBASIC認証がONの状態
 - `unc-k8s-cp-1`をansibleサーバーとする
 - `unc-k8s-cp-1`で鍵ペアを生成して、`unc-k8s-cp-[2-3]`と`unc-k8s-wk-[1-3]`に配る
 - 鍵配ったらSSHのBASIC認証を塞ぐ
 - kubeadm joinとかをやる
 - いえ〜〜〜〜〜い
