variable "version_chart" {
    default = "1.86.1"
}

variable "kube_config_file" {
    default =  ""
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config_file
  }
  version = "0.10.4"
}

provider "kubernetes" {
  config_path = var.kube_config_file
}


data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "kubernetes_namespace" "traefik" {
  metadata {
    name = "traefik"
  }
}


resource "helm_release" "traefik" {
  name       = "traefik"
  repository = data.helm_repository.stable.metadata[0].name
  chart      = "traefik"
  version    = var.version_chart
  namespace  = "traefik"

  set {
    name  = "kubernetes.ingressClass"
    value = "traefik"
  }
  set {
    name  = "kubernetes.ingressEndpoint.useDefaultPublishedService"
    value = "true"
  }
  set {
    name  = "ssl.enabled"
    value = "true"
  }
  set {
    name  = "ssl.permanentRedirect"
    value = "true"
  }
}