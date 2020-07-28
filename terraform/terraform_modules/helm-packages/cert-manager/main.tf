variable "version_chart" {
    default = "v0.12.0"
}
variable "namespace" {
}
<<<<<<< HEAD
variable "tiller_ns" {
    default =  "kube-system"
}
variable "namespace" {
    default =  "treafik"
}
variable "issuer_name_default" {
=======
variable "issuer_name" {
>>>>>>> feature/factory_tf
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
<<<<<<< HEAD
    filename = "${path.module}/clusterIssuer.yaml"
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config_file
  }
  version = "0.10.4"
  namespace = var.tiller_ns
=======
    filename    = "${path.module}/clusterIssuer.yaml"
>>>>>>> feature/factory_tf
}

data "helm_repository" "jetstack" {
  name = "jetstack"
  url  = "https://charts.jetstack.io"
}

<<<<<<< HEAD
resource "null_resource" "preConfigure" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig=$CONFIG apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml --namespace ${var.namespace}"
    environment = {
      CONFIG = var.kube_config_file
    }
=======
data "http" "certificaterequests_resources" {
  url = "https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml"
  request_headers = {
    Accept = "application/yaml"
>>>>>>> feature/factory_tf
  }
}

resource "kubectl_manifest" "preConfigure" {
    yaml_body = data.http.certificaterequests_resources.body
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = data.helm_repository.jetstack.metadata[0].name
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

<<<<<<< HEAD
resource "null_resource" "postInstall" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl --kubeconfig=$CONFIG apply -f $MANIFEST --namespace ${var.namespace} --validate=false --overwrite || exit 1
      kubectl --kubeconfig=$CONFIG label namespace ${var.namespace} certmanager.k8s.io/disable-validation=true --overwrite || exit 1
   EOT
    environment = {
      CONFIG = var.kube_config_file
      MANIFEST = local_file.clusterIssuer.filename
    }
  }
  depends_on = [helm_release.cert_manager]
=======
resource "kubectl_manifest" "cluster_issuers" {
    yaml_body = data.template_file.clusterIssuer.rendered
    depends_on = [helm_release.cert_manager]
}

output "namespace" {
  value = helm_release.cert_manager.namespace
}
output "issuer" {
  value = yamldecode(helm_release.cert_manager.metadata[0].values).ingressShim.defaultIssuerName
>>>>>>> feature/factory_tf
}


output "namespace" {
  value = helm_release.cert_manager.namespace
}
