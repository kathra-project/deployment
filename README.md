# How to install Kathra

## Microsoft Azure

### Requirements
- Microsoft Azure Account
- Sufficient CPU Quota (by default : 2 x Standard_D8s_v3)
- Public DNS Provider : For cert-manager
- Terraform, Kubectl, Golang

### Install

During installation, you have to register public IP provided by Azure into you DNS Provider. 

```sh
export ARM_SUBSCRIPTION_ID="xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxx"
export ARM_CLIENT_ID="xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxx"
export ARM_CLIENT_SECRET="xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxx"
export ARM_TENANT_ID="xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxx"

git clone git@gitlab.com:kathra/deployment.git
./deployment/terraform/terraform_modules/minikube-stack
./main.sh deploy --domain=kathra.azure.my-domain.org --azure-group-name=kathra --azure-location=francecentral --verbose

terraform output kubeconfig_content > /tmp/kubeconfig_content
export KUBECONFIG=/tmp/kubeconfig_content
```

## Google Cloud Provider

### Requirements
- GCP Account
- Sufficient CPU Quota (by default : 4 x n1-standard-4)
- Public DNS Provider : For cert-manager
- Terraform, Kubectl, Golang

### Install

During installation, you have to register public IP provided by Azure into you DNS Provider. 

```sh
git clone git@gitlab.com:kathra/deployment.git
./deployment/terraform/terraform_modules/gcp-stack
./main.sh deploy --domain=kathra.gcp.my-domain.org --gcp-project-name=<project-name> --gcp-credentials=<gcp_credentials_file> --verbose

terraform output kubeconfig_content > /tmp/kubeconfig_content
export KUBECONFIG=/tmp/kubeconfig_content
```


## Minikube

### Requirements
- Computer with 10 CPU and 20 Go Memory
- Large bandwidth : Only for images pulling
- DNS Provider : For DNS Challing with Let's Encrypt
- Ubuntu or Debian OS : Not tested on other distrib
- Terraform, Kubectl, Golang
- Root access : For additionnals packages and DNS configuration

### Install with Minikube

For the first installation, you have to make DNS Challenge with Let's Encrypt to generate TLS certificate (eg: For kathra.my-own-domain.org you have to add TXT record for domain _acme-challenge.kathra.my-own-domain.org with TOKEN provided by Let's Encrypt). 

#### Manual ACME
```sh
git clone git@gitlab.com:kathra/deployment.git
./deployment/terraform/terraform_modules/minikube-stack
./main.sh deploy --domain=local.my-domain.org --manual-acme
```

This procedure installs Minikube and configures somes features (Traefik, KubeDB and internal DNS).

By default, the login is 'user' and password '123'. You can override this configure during installation.

#### Auto ACME
ACME with Terraform Provider https://www.terraform.io/docs/providers/acme/
```sh
git clone git@gitlab.com:kathra/deployment.git
./deployment/terraform/terraform_modules/minikube-stack
./main.sh deploy --domain=local.my-domain.org --acme-dns-provider=ovh --acme-dns-config='{"OVH_APPLICATION_KEY": "app-key", "OVH_APPLICATION_SECRET": "app-secret","OVH_CONSUMER_KEY": "consumer-key","OVH_ENDPOINT": "ovh-eu"}'
```

#### Own TLS Cert
```sh
git clone git@gitlab.com:kathra/deployment.git
./deployment/terraform/terraform_modules/minikube-stack
./main.sh deploy --domain=local.my-domain.org --tlsCert=<path> --tlsKey=<path>
```

# Backup your instance

If you want to backup your kathra instance, we have to backup Kathra Database (ArangoDB) and factory tools (Keycloak, Gitlab, Nexus, Harbor, Jenkins) at the same time.

You can use Velero with Restic (https://velero.io/docs/master/restic/)


# Developers settings
## GitLab - SSH Agent
To pull source repositories, you have to configure your SSH client to connect throught gitlab's NodePort.
```
terraform output -json kathra | jq -r '.factory.gitlab.ssh.node_port'
kubectl -n kathra-factory get svc gitlab
NAME      TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                     AGE
gitlab    NodePort   10.233.23.197   <none>        80:32739/TCP,22:30000/TCP   5m

kubectl describe nodes | grep InternalIP
InternalIP:  192.168.208.52
```

Add settings to ssh's config
```ssh
export nodePort=$(terraform output -json kathra | jq -r '.factory.gitlab.ssh.node_port')
export clusterIp=$(terraform output -json kathra | jq -r '.factory.gitlab.ssh.cluster_ip')
cat <<EOF >$FILE
Host gitlab.your-domain.xyz
        Port $nodePort
        HostName $clusterIp
EOF
```

## For Java developers : Nexus - Maven Repository
You have to configure you maven setting if you want to pull artifacts from your Nexus.
You need to add "repository" section into your ~/.m2/settings.xml 

```
<repository>
   <id>nexus-kathra</id>
   <name>Nexus KATHRA</name>
   <url>https://nexus.your-domain.xyz/repository/maven-all/</url>
   <releases>
      <updatePolicy>always</updatePolicy>
      <enabled>true</enabled>
   </releases>
   <snapshots>
      <updatePolicy>always</updatePolicy>
      <enabled>true</enabled>
   </snapshots>
</repository>
```

## For Docker users : Harbor - Images Repository
If you want to pull images from Harbor's repository, you have to configure your docker client (~/.docker/config).
You can use "jenkins.harbor" account to pull image with password generated into ~/.kathra_pwd.
But, we recommend to create specific account with read only access.
```
docker login --username "jenkins.harbor" --password "$(cat ~/.kathra_pwd | jq -r '.HARBOR_ADMIN_PASSWORD')" https://harbor.your-domain.xyz
```

# Troubleshootings tips

## Nexus init : "Error: could not read repository 'maven-snapshots': HTTP: 503, Service Unavailable"

Nexus is not ready during Terraform initialization.
Wait few minutes and re-apply.

## Token generation : "https://xxxxx.org is not ready, TLS is self signed"

TLS certificates are not generated by CertManager, you have to delete 
```sh
terraform output kubeconfig_content > /tmp/kubeconfig_content
export KUBECONFIG=/tmp/kubeconfig_content
kubectl get certificates --all-namespaces
NAMESPACE        NAME                   READY   SECRET                 AGE
kathra-factory   gitlab-minio-cert      True    gitlab-minio-cert      28m
kathra-factory   gitlab-registry-cert   True    gitlab-registry-cert   28m
kathra-factory   gitlab-unicorn-cert    True    gitlab-unicorn-cert    28m
kathra-factory   harbor-cert            True    harbor-cert            29m
kathra-factory   harbor-notary-cert     True    harbor-notary-cert     29m
kathra-factory   jenkins-cert           False   jenkins-cert           16m
kathra-factory   keycloak-cert          True    keycloak-cert          30m
kathra-factory   nexus-cert             True    nexus-cert             30m
kathra-factory   sonarqube-cert         True    sonarqube-cert         29m
```

Cause possible : 
- Certificat quota exceeded (https://letsencrypt.org/docs/rate-limits/)


# Product version

##  Factory products compatibilities

| Product 	      | Version 	|
|--------------	|---------------------	|
| Kubernetes   	| 1.15.1             	|
| Treafik      	| 1.7.9               	|
| Keycloak     	| 10.0.0               	|
| Gitlab-ci    	| 12.10.6              	|
| Nexus        	| 3.21.2              	|
| Harbor       	| 1.10.0               	|
| Jenkins      	| 2.190.1             	|
| SonarQube      	| 8.2                	|
