variable "version_chart" {
    default = "1.86.1"
}
variable "load_balancer_ip" {
    default =  ""
}
variable "aks_group" {
    default =  "kathra"
}

data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "kubernetes_namespace" "traefik" {
  metadata {
    name = "traefik"
    annotations = {
      "certmanager.k8s.io/disable-validation" = "true"
    }
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
  set {
    name  = "rbac.enabled"
    value = "true"
  }
  set {
    name  = "loadBalancerIP"
    value = var.load_balancer_ip
  }
  set {
    name = "service.annotations.\"service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group\""
    value = var.aks_group
  }
}
output "ingress_controller" {
  value = "traefik"
}
output "namespace" {
  value = helm_release.traefik.namespace
}