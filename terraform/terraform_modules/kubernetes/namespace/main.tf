variable "kube_config_file" {
}
variable "namespace" {
}

provider "kubernetes" {
  config_path = var.kube_config_file
}

resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.namespace
  }
}

output "namespace" {
  value = kubernetes_namespace.ns.metadata[0].name
}
