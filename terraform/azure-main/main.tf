variable "group" {
    default = "kathra"
}
variable "location" {
    default = "East US"
}
variable "domain" {

}
variable "domain_name_label" {
    default = null
}
variable "client_id" {

}
variable "client_secret" {
    
}
variable "kathra_charts_version" {
    
}
variable "kathra_images_tag" {
    
}

module "static_ip" {
  source  = "../terraform_modules/public-ip/azure"
  location = var.location
  group = var.group
  domain_name_label = var.domain_name_label
}

resource "null_resource" "check_dns_resolution" {
  provisioner "local-exec" {
    command = <<EOT
        echo "Trying to resolv DNS test.$DOMAIN  -> $IP"
        for attempt in $(seq 1 100); do sleep 5 && nslookup test.$DOMAIN | grep "$IP" && exit 0 || echo "Unable to resolv DNS *.$DOMAIN -> $IP ($attempt/100)"; done
        exit 1
   EOT
    environment = {
      IP = module.static_ip.public_ip_address
      DOMAIN = var.domain
    }
  }
}

module "kubernetes" {
  source  = "../terraform_modules/kubernetes/azure"
  location = var.location
  group = var.group
  k8s_client_id = var.client_id
  k8s_client_secret = var.client_secret
}

resource "local_file" "kube_config" {
    content     = module.kubernetes.kube_config
    filename = "${path.module}/kube_config"
}


module "treafik" {
    source  = "../terraform_modules/helm-packages/traefik"
    kube_config_file = local_file.kube_config.filename
    load_balancer_ip = module.static_ip.public_ip_address
    group = var.group
}

module "kubedb" {
    source  = "../terraform_modules/helm-packages/kubedb"
    kube_config_file = local_file.kube_config.filename
}

module "cert-manager" {
    source  = "../terraform_modules/helm-packages/cert-manager"
    kube_config_file = local_file.kube_config.filename
}

module "kathra" {
    source  = "../terraform_modules/kathra"
    domain = var.domain
    charts_version = var.kathra_charts_version
    images_tag = var.kathra_images_tag
    kube_config_file = local_file.kube_config.filename
}

output "kubeconfig" {
    value = local_file.kube_config.filename
}