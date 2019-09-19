# KATHRA over Minikube

This guidelines manual explains how to configure KATHRA over Minikube. 
You can install minikube manually or the automated script following : 
```shell
./install-minikube.sh --domain=my-domain.xyz --generateCertsDnsChallenge --disk-size=50000mb --cpus=7 --memory=12000
```

## Requirements

* OS : Ubuntu/Debian
* CPU : 6 Cores (with VT-X/AMD-v enabled)
* Memory : 14 GB
* Disk Space : 50 GB
* High bandwidth network (for images pulling)
* DNS provider

## 1. Get your own SSL certificate

You need SSL certificates for all yours services. The easiest way is to generate wildcard certificate with ACME with DNS challenge.
For our example, the domain is : "my-domain.xyz"

### ACME - DNS Challenge with Let's encrypt
#### Install Let's Encrypt

```shell
sudo apt-get update
sudo apt-get install -y python-minimal git-core letsencrypt
cd /opt
sudo git clone https://github.com/certbot/certbot.git
cd certbot && ./certbot-auto
```

#### Generate widlcard SSL certificate

##### Ask Let's Encrypt new request
```shell
./certbot-auto certonly --manual --preferred-challenges=dns --email=julien.boubechtoula@gmail.com --agree-tos -d *.my-domain.xyz
```

##### Add TXT record
Let's encrypt give you a token value to add in your DNS provider as TXT record
```shell
Please deploy a DNS TXT record under the name
_acme-challenge.my-domain.xyz with the following value:J50GNXkhGmKCfn-0LQJcknVGtPEAQ_U_WajcLXgqWqo
```

##### Get your certificate
 Certbot-auto downloads your certificate when Let's Encrypt have validated your TXT record. So, you have to wait your TXT record are progagated into DNS server.

```
IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/my-domain.xyz/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/my-domain.xyz/privkey.pem
   Your cert will expire on 2019-11-09. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot-auto
   again. To non-interactively renew *all* of your certificates, run
   "certbot-auto renew"
 - Your account credentials have been saved in your Certbot
   configuration directory at /etc/letsencrypt. You should make a
   secure backup of this folder now. This configuration directory will
   also contain certificates and private keys obtained by Certbot so
   making regular backups of this folder is ideal.
 - If you like Certbot, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le
```
Your certificates are here :
```shell
sudo ls -l /etc/letsencrypt/live/my-domain.xyz/
total 4
lrwxrwxrwx 1 root root  46 août  11 21:56 cert.pem -> ../../archive/my-domain.xyz/cert1.pem
lrwxrwxrwx 1 root root  47 août  11 21:56 chain.pem -> ../../archive/my-domain.xyz/chain1.pem
lrwxrwxrwx 1 root root  51 août  11 21:56 fullchain.pem -> ../../archive/my-domain.xyz/fullchain1.pem
lrwxrwxrwx 1 root root  49 août  11 21:56 privkey.pem -> ../../archive/my-domain.xyz/privkey1.pem
-rw-r--r-- 1 root root 692 août  11 21:56 README
```


## 2. Install & configure Minikube

### Deploy Minikube instance

```shell
sudo apt-get install -y virtualbox
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64   && chmod +x minikube
sudo cp minikube /usr/local/bin && rm minikube
minikube start --cpus 4 --memory 4096
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
sudo cp kubectl /usr/local/bin && rm kubectl
```

### Get your instance IP
```shell
minikube ip
192.168.99.101
```
### Check Kubectl access
```shell
kubectl version
Client Version: version.Info{Major:"1", Minor:"15", GitVersion:"v1.15.2", GitCommit:"f6278300bebbb750328ac16ee6dd3aa7d3549568", GitTreeState:"clean", BuildDate:"2019-08-05T09:23:26Z", GoVersion:"go1.12.5", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"15", GitVersion:"v1.15.2", GitCommit:"f6278300bebbb750328ac16ee6dd3aa7d3549568", GitTreeState:"clean", BuildDate:"2019-08-05T09:15:22Z", GoVersion:"go1.12.5", Compiler:"gc", Platform:"linux/amd64"}
```


### Configure your local host file
We considere host VM as frontend for domain's name. We use eth0 as public interface.
```shell
ip -4 addr show eth0 | grep -oP '(?<=inet\s)[\da-f.]+'
172.18.182.184
```
Here 172.18.182.184 is the address for the domain "my-domain.xyz". Either you declare my-domain.xyz into your private DNS or your can declare into your hosts file (see bellow)
```shell
echo "172.18.182.184 my-domain.xyz" >> /etc/hosts
```

### Configure CoreDNS
You have to declare your domain inside your minikube. 

#### Update CoreDns's ConfigMap
You have to add DNS records for domain "my-domain.xyz".
You use IP 172.18.182.184 as target.
```shell
kubectl -n kube-system edit cm coredns
```
```yaml
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           upstream
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        file /etc/coredns/my-domain.xyz.db my-domain.xyz
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
  my-domain.xyz.db: |
    my-domain.xyz.            IN      SOA     sns.dns.icann.org. noc.dns.icann.org. 2015082541 7200 3600 1209600 3600
    my-domain.xyz.            IN      NS      b.iana-servers.net.
    my-domain.xyz.            IN      NS      a.iana-servers.net.
    my-domain.xyz.            IN      A       172.18.182.184
    *.my-domain.xyz.          IN      CNAME   my-domain.xyz.
   
```

#### Mount file records as volume
```shell
kubectl -n kube-system edit deployment coredns
```

```yaml
volumes:
- name: config-volume
    configMap:
    name: coredns
    items:
    - key: Corefile
        path: Corefile
    - key: my-domain.xyz.db
        path: my-domain.xyz.db
```

#### Check your DNS configuration

```shell
kubectl run -it --rm --restart=Never --image=infoblox/dnstools:latest dnstools -- '-c' 'host my-domain.xyz'
my-domain.xyz has address 172.18.182.184
pod "dnstools" deleted

kubectl run -it --rm --restart=Never --image=infoblox/dnstools:latest dnstools -- '-c' 'host x.my-domain.xyz'
x.my-domain.xyz is an alias for my-domain.xyz.
my-domain.xyz has address 172.18.182.184
pod "dnstools" deleted
```

Your hostname and their subdomains should be resolved inside your cluster.

### Init Helm tiller

```shell
curl -LO https://git.io/get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
helm init
```

### Install Treafik & configure SSL Ingress

#### 1. Install Treafik
```
helm install stable/traefik --name traefik --set dashboard.enabled=true,ssl.enabled=true,serviceType=NodePort,service.nodePorts.http=30080,service.nodePorts.https=30443,dashboard.domain=traefik.my-domain.xyz,rbac.enabled=true  --namespace traefik
```
#### 2. Check dashboard

```
curl -H "Host: traefik.my-domain.xyz" http://$(minikube ip):30080
<a href="/dashboard/">Found</a>.
curl -H "Host: traefik.my-domain.xyz" -k https://$(minikube ip):30443
<a href="/dashboard/">Found</a>.
```
Treafik's dashboard should be available on HTTP and unsecured HTTPS


#### 3. Redirect HTTP, HTTPS from Host to Minikube
Currently, your minikube expose HTTP and HTTPS on 30080 and 30443.
You have to redirected your traffic incoming to theses ports.

For GitLab you need forward NodePort 30022

#### Redirect port with Socat or Ip Tables
```
minikube ip
192.168.99.100
sudo apt-get install -y socat
nohup sudo socat tcp-l:80,fork,reuseaddr tcp:192.168.99.100:30080 &
nohup sudo socat tcp-l:443,fork,reuseaddr tcp:192.168.99.100:30443 &
nohup sudo socat tcp-l:30022,fork,reuseaddr tcp:192.168.99.100:30022 &
```

Now, your local host redirect HTTP and HTTPS traffic to your Minikube on specifics NodePorts


```shell
echo "172.18.182.184 traefik.my-domain.xyz" >> /etc/hosts
```

```
curl http://traefik.my-domain.xyz
<a href="/dashboard/">Found</a>.
curl -k https://traefik.my-domain.xyz
<a href="/dashboard/">Found</a>.
```

#### 3. Configure SSL dashboard

Add your SSL certificate to secret and kill current pods. 

```
kubectl -n traefik patch secrets traefik-default-cert -p "{\"data\": {\"tls.crt\":\"$(base64 -w0 < /etc/letsencrypt/archive/my-domain.xyz/fullchain1.pem)\",\"tls.key\":\"$(base64 -w0 < /etc/letsencrypt/archive/my-domain.xyz/privkey1.pem)\"}}"

kubectl -n traefik delete pods --all
```

You can get Traefik's dashboard without option "insecure".
```
curl -H "Host: traefik.my-domain.xyz" https://$(minikube ip):30443
<a href="/dashboard/">Found</a>.
curl https://traefik.my-domain.xyz
<a href="/dashboard/">Found</a>.
```


### Install KubeDB

```
curl -fsSL -o onessl https://github.com/kubepack/onessl/releases/download/0.3.0/onessl-linux-amd64 \
  && chmod +x onessl \
  && sudo mv onessl /usr/local/bin/
helm repo add appscode https://charts.appscode.com/stable/
helm repo update
helm install appscode/kubedb --name kubedb-operator --version 0.8.0 \
  --set apiserver.ca="$(onessl get kube-ca)" \
  --set apiserver.enableValidatingWebhook=true \
  --set apiserver.enableMutatingWebhook=true
```

## 3. Install KATHRA

```
./install.sh --domain=my-domain.xyz --debug
```


