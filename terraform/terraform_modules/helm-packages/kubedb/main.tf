variable "version_chart" {
    default = "0.8.0"
}
variable "kube_config_file" {
    default =  ""
}
variable "tiller_ns" {
    default =  "kube-system"
}


provider "helm" {
  kubernetes {
    config_path = var.kube_config_file
  }
  version   = "0.10.4"
  namespace = var.tiller_ns
}

provider "kubernetes" {
  config_path = var.kube_config_file
}

data "helm_repository" "stable" {
  name = "appscode"
  url  = "https://charts.appscode.com/stable/"
}

data "external" "apiserver_ca" {
    program = ["sh", "${path.module}/get-ca.sh"]
}

resource "helm_release" "kubedb" {
  name       = "kubedb-operator"
  repository = data.helm_repository.stable.metadata[0].name
  chart      = "appscode/kubedb"
  version    = var.version_chart
  namespace  = "kubedb"

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
