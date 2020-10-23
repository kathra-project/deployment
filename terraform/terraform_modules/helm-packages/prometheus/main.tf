variable "namespace" {
}
variable "ingress_cert_manager_issuer" {
}
variable "ingress_class" {
}

variable "grafana" {
  default = {
    ingress_tls_secret_name = "grafana-cert"
    password                = "admin"
    ingress_host            = "grafana.kathra.org"
  }
}




/*
resource "helm_release" "prometheus-operator" {
  name       = "prometheus"
  repository = data.helm_repository.stable.metadata[0].name
  chart      = "prometheus-operator"
  namespace  = var.namespace
  values     = [<<EOF

grafana:
  adminPassword: ${var.grafana.password}
  ingress:
    enabled: true
    hosts: 
    - ${var.grafana.ingress_host}
    tls:
    - hosts:
      - ${var.grafana.ingress_host}
      secretName: ${var.grafana.ingress_tls_secret_name == null ? "grafana-cert" : var.grafana.ingress_tls_secret_name}
    annotations:
      kubernetes.io/ingress.class: "${var.ingress_class}"
      cert-manager.io/cluster-issuer: "${var.ingress_cert_manager_issuer}"

EOF
]
}
*/
output "password" {
  value = var.grafana.password
}