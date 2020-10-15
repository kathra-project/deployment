variable "version_chart" {
    default = "v0.12.0"
}
variable "namespace" {
}
variable "issuer_name" {
    default =  "letsencrypt-prod"
}
variable "email" {
    default =  "contact@kathra.org"
}

data "template_file" "clusterIssuer" {
  template = file("${path.module}/clusterIssuer.yaml.tpl")
  vars = {
    clusterIssuerName = var.issuer_name
    email = var.email
  }
}
resource "local_file" "clusterIssuer" {
    content     = data.template_file.clusterIssuer.rendered
    filename    = "${path.module}/clusterIssuer.yaml"
}

data "http" "certificaterequests_resources" {
  url = "https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml"
  request_headers = {
    Accept = "application/yaml"
  }
}

resource "kubectl_manifest" "preConfigure" {
    yaml_body = data.http.certificaterequests_resources.body
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "jetstack/cert-manager"
  version    = var.version_chart
  namespace  = var.namespace
  set {
    name  = "ingressShim.defaultIssuerKind"
    value = "ClusterIssuer"
  }
  set {
    name  = "ingressShim.defaultIssuerName"
    value = var.issuer_name
  }
  depends_on = [kubectl_manifest.preConfigure]
}

resource "kubectl_manifest" "cluster_issuers" {
    yaml_body = data.template_file.clusterIssuer.rendered
    depends_on = [helm_release.cert_manager]
}

output "namespace" {
  value = helm_release.cert_manager.namespace
}
output "issuer" {
  value = yamldecode(helm_release.cert_manager.metadata[0].values).ingressShim.defaultIssuerName
}