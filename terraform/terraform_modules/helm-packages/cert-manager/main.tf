variable "version_chart" {
    default = "v0.12.0"
}
variable "kube_config_file" {
    default =  ""
}
variable "issuer_name_default" {
    default =  "letsencrypt-prod"
}
variable "email" {
    default =  "contact@kathra.org"
}

data "template_file" "clusterIssuer" {
  template = file("${path.module}/clusterIssuer.yaml.tpl")
  vars = {
    clusterIssuerName = var.issuer_name_default
    email = var.email
  }
}
resource "local_file" "clusterIssuer" {
    content     = data.template_file.clusterIssuer.rendered
    filename = "${path.module}/clusterIssuer.yaml"
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

resource "helm_release" "cert_manager" {
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

resource "null_resource" "postInstall" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl --kubeconfig=$CONFIG apply -f $MANIFEST --namespace traefik --validate=false --overwrite || exit 1
      kubectl --kubeconfig=$CONFIG label namespace traefik certmanager.k8s.io/disable-validation=true --overwrite || exit 1
   EOT
    environment = {
      CONFIG = var.kube_config_file
      MANIFEST = local_file.clusterIssuer.filename
    }
  }
  depends_on = [helm_release.cert_manager]
}

