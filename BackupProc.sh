# POC Backup With Velero and Restic

sudo docker run -d --name minio -p 9000:9000 -v data:/data minio/minio server /data
sudo docker exec -it minio cat /data/.minio.sys/config/config.json | egrep "(access|secret)Key"
wget https://github.com/heptio/velero/releases/download/v1.1.0/velero-v1.1.0-linux-amd64.tar.gz
tar zxf velero-v1.1.0-linux-amd64.tar.gz
sudo mv velero-v1.1.0-linux-amd64/velero /usr/local/bin/
rm -rf velero*

accessKey=$(sudo docker exec -it minio cat /data/.minio.sys/config/config.json | jq -r '.credential.accessKey')
secretKey=$(sudo docker exec -it minio cat /data/.minio.sys/config/config.json | jq -r '.credential.secretKey')

rm minio.credentials
cat <<EOF>> minio.credentials
[default]
aws_access_key_id=$accessKey
aws_secret_access_key=$secretKey
EOF

#kubectl delete namespace velero

myIP=$(hostname -I | awk '{print $1}')

velero install  \
--secret-file ./minio.credentials \
--provider aws \
--use-restic \
--bucket kathra \
--backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://${myIP}:9000,publicUrl=http://${myIP}:9000

velero backup create kube-system-backup-0 --include-namespaces kube-system
velero backup create traefik-backup-0 --include-namespaces traefik
velero backup create kathra-backup-0 --include-namespaces kathra-services
velero backup create kathra-factory-backup-0 --include-namespaces kathra-factory