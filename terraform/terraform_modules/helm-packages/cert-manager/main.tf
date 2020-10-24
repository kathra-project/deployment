variable "version_chart" {
    default = "v1.0.3"
}
variable "namespace" {
}
variable "issuer_name" {
    default =  "letsencrypt-prod"
}
variable "email" {
    default =  "contact@kathra.org"
}
/*
data "http" "certificaterequests_resources" {
  url = "https://raw.githubusercontent.com/jetstack/cert-manager/release-0.14/deploy/manifests/00-crds.yaml"
  request_headers = {
    Accept = "application/yaml"
  }
}

resource "kubectl_manifest" "preConfigure" {
    yaml_body = data.http.certificaterequests_resources.body
}
*/
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
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
  set {
    name  = "installCRDs"
    value = "true"
  }
  //depends_on = [ kubectl_manifest.preConfigure ]
}



data "template_file" "clusterIssuer" {
  template = file("${path.module}/clusterIssuer.yaml.tpl")
  vars = {
    clusterIssuerName = yamldecode(helm_release.cert_manager.metadata[0].values).ingressShim.defaultIssuerName
    email = var.email
  }
}
resource "local_file" "clusterIssuer" {
    content     = data.template_file.clusterIssuer.rendered
    filename    = "${path.module}/clusterIssuer.yaml"
}


resource "kubectl_manifest" "cluster_issuers" {
    yaml_body = data.template_file.clusterIssuer.rendered
}

output "namespace" {
  value = helm_release.cert_manager.namespace
}
output "issuer" {
  value = yamldecode(helm_release.cert_manager.metadata[0].values).ingressShim.defaultIssuerName
}