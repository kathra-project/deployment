data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "helm_release" "example" {
  name       = "traefik"
  repository = data.helm_repository.stable.metadata[0].name
  chart      = "traefik"
  version    = "1.86.1"
  namespace  = "traefik"

  values = [
    "${file("values.yaml")}"
  ]

  set {
    name  = "kubernetes.ingressClass"
    value = "traefik"
  }

  set {
    name  = "kubernetes.ingressEndpoint.useDefaultPublishedService"
    value = "true"
  }

  set_string {
    name  = "service.annotations.prometheus\\.io/port"
    value = "9127"
  }
}