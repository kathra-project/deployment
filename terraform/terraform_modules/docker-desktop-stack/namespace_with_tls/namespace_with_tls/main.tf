variable "default_tls_cert" {
}
variable "default_tls_key" {
}
variable "namespace" {
}

resource "kubernetes_namespace" "tls" {
  metadata {
    name = var.namespace
  }
}
resource "kubernetes_secret" "tls" {

  metadata {
    name = "default-tls"
    namespace = kubernetes_namespace.tls.metadata[0].name
  }

  data = {
    "tls.crt" = var.default_tls_cert
    "tls.key" = var.default_tls_key
  }

  type = "kubernetes.io/tls"
}

output "name" {
  value = kubernetes_namespace.tls.metadata[0].name
}

output "tls_secret_name" {
  value = kubernetes_secret.tls.metadata[0].name
}
