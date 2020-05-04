variable "version_chart" {
    default = "1.86.1"
}
variable "kube_config" {
}
variable "ingress_host" {
}
variable "ingress_tls_secret_name" {
  default = "keycloak-cert"
}
variable "ingress_cert_manager_issuer" {
}
variable "namespace" { 
}
variable "username" {
}
variable "password" {
}
variable "ingress_class" {
}

data "helm_repository" "codecentric" {
  name = "codecentric"
  url  = "https://codecentric.github.io/helm-charts"
}

resource "helm_release" "keycloak" {
  name       = "keycloak"
  repository = data.helm_repository.codecentric.metadata[0].name
  chart      = "keycloak"
  namespace  = var.namespace
  
  values = [<<EOF
keycloak:
  username: "${var.username}"
  password: "${var.password}"
  persistence:
    deployPostgres: true
    dbVendor: "postgres"
  ingress:
    annotations:
        kubernetes.io/ingress.class: "${var.ingress_class}"
        cert-manager.io/issuer: "${var.ingress_cert_manager_issuer}"
    enabled: true
    hosts: 
    - ${var.ingress_host}
    tls:
    - hosts:
      - ${var.ingress_host}
      secretName: ${var.ingress_tls_secret_name == null ? "keycloak-cert" : var.ingress_tls_secret_name}
EOF
]

}

resource "null_resource" "check_tls_resolution" {
    triggers = {
        timestamp        = timestamp()
    }
    provisioner "local-exec" {
      command = <<EOT
for attempt in $(seq 1 100); do sleep 5 && curl --fail https://${var.ingress_host} && exit 0 || echo "Check https://${var.ingress_host} ($attempt/100)"; done
curl --fail https://${var.ingress_host} || exit 1
exit 1
    EOT
    }
    depends_on = [ helm_release.keycloak ]
}




output "namespace" {
    value = helm_release.keycloak.namespace
}
output "name" {
    value = helm_release.keycloak.name
}
output "username" {
    value = yamldecode(helm_release.keycloak.metadata[0].values).keycloak.username
}
output "password" {
    value = yamldecode(helm_release.keycloak.metadata[0].values).keycloak.password
}
output "host" {
    value = yamldecode(helm_release.keycloak.metadata[0].values).keycloak.ingress.hosts[0]
}
output "url" {
    value = "https://${yamldecode(helm_release.keycloak.metadata[0].values).keycloak.ingress.hosts[0]}"
}