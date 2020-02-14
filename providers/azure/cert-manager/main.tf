data "helm_repository" "jetstack" {
  name = "jetstack"
  url  = "https://charts.jetstack.io"
}

resource "helm_release" "example" {
  name       = "cert-manager"
  repository = data.helm_repository.jetstack.metadata[0].name
  chart      = "jetstack/cert-manager"
  version    = "v0.12.0"
  namespace  = "cert-manager"

  values = [
    "${file("values.yaml")}"
  ]

  set {
    name  = "ingressShim.defaultIssuerName"
    value = "letsencrypt"
  }

  set {
    name  = "ingressShim.defaultIssuerKind"
    value = "ClusterIssuer"
  }

  set_string {
    name  = "service.annotations.prometheus\\.io/port"
    value = "9127"
  }
}