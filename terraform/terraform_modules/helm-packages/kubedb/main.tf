variable "version_chart" {
    default = "0.8.0"
}
variable "kube_config_file" {
}
variable "namespace" {
}
provider "helm" {
  kubernetes {
    config_path = var.kube_config_file
  }
}
data "helm_repository" "appscode" {
  name = "appscode"
  url  = "https://charts.appscode.com/stable"
}

data "external" "apiserver_ca" {
    program = ["sh", "${path.module}/get-ca.sh"]
}

resource "helm_release" "kubedb" {
  name       = "kubedb-operator"
  repository = data.helm_repository.appscode.metadata[0].name
  chart      = "appscode/kubedb"
  version    = var.version_chart
  namespace  = var.namespace

  set {
    name  = "apiserver.enableValidatingWebhook"
    value = "true"
  }
  set {
    name  = "apiserver.ca"
    value = data.external.apiserver_ca.result["cert"]
  }
  set {
    name  = "apiserver.enableMutatingWebhook"
    value = "true"
  }
}