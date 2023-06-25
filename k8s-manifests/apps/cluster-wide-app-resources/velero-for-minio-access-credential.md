secrets用base64生成の元ネタ

```sh
export config_file=credentials-velero
export user=iamrootuser
export password=t0p-Secret
cat > $config_file <<EOF
[default]
aws_access_key_id = ${user}
aws_secret_access_key = ${password}
EOF
cat $config_file | base64

rm $config_file
```
