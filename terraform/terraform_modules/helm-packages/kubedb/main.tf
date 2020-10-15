variable "version_chart" {
    default = "0.8.0"
}

resource "kubernetes_namespace" "kubedb" {
  metadata {
    name = "kubedb"
  }
}

data "external" "apiserver_ca" {
    program = ["sh", "${path.module}/get-ca.sh"]
}

resource "helm_release" "kubedb" {
  name       = "kubedb-operator"
  repository = "https://charts.appscode.com/stable/"
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
