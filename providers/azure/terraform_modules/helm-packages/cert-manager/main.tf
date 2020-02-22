variable "version_chart" {
    default = "v0.12.0"
}

variable "kube_config_file" {
    default =  ""
}
variable "issuer_name_default" {
    default =  "letsencrypt-prod"
}
variable "cluster_issuers_file" {
    default =  ""
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config_file
  }
  version = "0.10.4"
}

data "helm_repository" "jetstack" {
  name = "jetstack"
  url  = "https://charts.jetstack.io"
}

resource "null_resource" "preConfigure" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig=$CONFIG apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml --namespace traefik"
    environment = {
      CONFIG = var.kube_config_file
    }
  }
}

resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = data.helm_repository.jetstack.metadata[0].name
  chart      = "jetstack/cert-manager"
  version    = var.version_chart
  namespace  = "traefik"

  set {
    name  = "ingressShim.defaultIssuerKind"
    value = "ClusterIssuer"
  }
  set {
    name  = "ingressShim.defaultIssuerName"
    value = var.issuer_name_default
  }
}

resource "null_resource" "postConfigure" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig=$CONFIG apply -f $MANIFEST --namespace traefik --validate=false --overwrite"
    environment = {
      CONFIG = var.kube_config_file
      MANIFEST = var.cluster_issuers_file
    }
  }
}

resource "null_resource" "postConfigure_2" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig=$CONFIG label namespace traefik certmanager.k8s.io/disable-validation=true --overwrite"
    environment = {
      CONFIG = var.kube_config_file
    }
  }
}
