#/bin/bash
export SCRIPT_DIR=$(realpath $(dirname `which $0`))
declare $KUBECONFIG=$SCRIPT_DIR/kube_config
cd $SCRIPT_DIR

# Requirements
# Buy domain : https://docs.microsoft.com/bs-latn-ba/azure/app-service/manage-custom-dns-buy-domain#buy-the-domain
# Add DNS entry : https://docs.microsoft.com/bs-latn-ba/azure/dns/dns-getstarted-cli
# az cli
# kubectl
# helm
# terraform

## install k8s
terraform init
terraform apply
terraform output kube_config > $KUBECONFIG


## install treafik
kubectl create ns traefik
helm install traefik stable/traefik --namespace traefik --set kubernetes.ingressClass=traefik --set kubernetes.ingressEndpoint.useDefaultPublishedService=true --version 1.85.0

## get external-ip
kubectl get svc -n traefik --watch

## add dns record 
az network dns record-set a add-record \
    --resource-group myResourceGroup \
    --zone-name MY_CUSTOM_DOMAIN \
    --record-set-name *.traefik \
    --ipv4-address MY_EXTERNAL_IP

kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml --namespace traefik
kubectl label namespace traefik certmanager.k8s.io/disable-validation=true


## install cert-manager
kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml --namespace traefik
kubectl label namespace traefik certmanager.k8s.io/disable-validation=true
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager --namespace traefik --version v0.12.0 jetstack/cert-manager --set ingressShim.defaultIssuerName=letsencrypt --set ingressShim.defaultIssuerKind=ClusterIssuer


echo "apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: MY_EMAIL_ADDRESS
    privateKeySecretRef:
      name: letsencrypt
    solvers:
      - http01:
          ingress:
            class: traefik
" > /tmp/letsencrypt.clusterissuer.yaml

kubectl apply -f /tmp/letsencrypt.clusterissuer.yaml --namespace traefik

helm upgrade traefik stable/traefik --namespace traefik --set kubernetes.ingressClass=traefik --set kubernetes.ingressEndpoint.useDefaultPublishedService=true --version 1.85.0 --set ssl.enabled=true --set ssl.enforced=true --set ssl.permanentRedirect=true