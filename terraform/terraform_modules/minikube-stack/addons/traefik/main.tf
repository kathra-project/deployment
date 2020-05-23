variable "version_chart" {
    default = "1.86.1"
}
variable "default_tls_key" {
}
variable "default_tls_cert" {
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
    name  = "ssl.enabled"
    value = "true"
  }
  set {
    name  = "rbac.enabled"
    value = "true"
  }
  set {
    name  = "ssl.defaultCert"
    value = base64encode(var.default_tls_cert)
  }
  set {
    name  = "ssl.defaultKey"
    value = base64encode(var.default_tls_key)
  }
}

output "ingress_controller" {
  value = yamldecode(helm_release.traefik.metadata[0].values).kubernetes.ingressClass
}
output "namespace" {
  value = helm_release.traefik.namespace
}
/*
output "http_node_port" {
  value = yamldecode(helm_release.traefik.metadata[0].values).service.nodePorts.https
}
output "https_node_port" {
  value = yamldecode(helm_release.traefik.metadata[0].values).service.nodePorts.https
}*/