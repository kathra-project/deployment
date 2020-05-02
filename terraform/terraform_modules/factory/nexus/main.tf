variable "ingress_host" {
}
variable "ingress_class" {
}
variable "ingress_cert_manager_issuer" {
}
variable "ingress_tls_secret_name" {
  default = "nexus-cert"
}
variable "namespace" { 
}
variable "password" {
}


data "helm_repository" "oteemocharts" {
  name = "oteemocharts"
  url  = "https://oteemo.github.io/charts"
}


resource "helm_release" "nexus" {
  name       = "nexus"
  repository = data.helm_repository.oteemocharts.metadata[0].name
  chart      = "sonatype-nexus"
  namespace  = var.namespace
  version    = "2.1.0"

  values = [<<EOF
nexusProxy:
  env:
    nexusDockerHost: ${var.ingress_host}
    nexusHttpHost: ${var.ingress_host}

nexus:
  adminPassword: ${var.password}
nexusBackup:
  nexusAdminPassword: ${var.password}

ingress:
  enabled: true
  path: /
  annotations:
    kubernetes.io/ingress.class: "${var.ingress_class}"
    cert-manager.io/issuer: "${var.ingress_cert_manager_issuer}"
  tls:
    enabled: true
    usesSecret: true
    secretName: ${var.ingress_tls_secret_name}
EOF
]

}

output "namespace" {
    value = helm_release.nexus.namespace
}
output "name" {
    value = helm_release.nexus.name
}
output "username" {
    value = "admin"
}
output "password" {
    value = yamldecode(helm_release.nexus.metadata[0].values).nexus.adminPassword
}
output "service" {
    value = "http://sonatype-nexus-service:8081"
}
output "url" {
    value = "https://${yamldecode(helm_release.nexus.metadata[0].values).nexusProxy.env.nexusHttpHost}"
}