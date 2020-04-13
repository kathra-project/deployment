variable "version_chart" {
    default = "1.86.1"
}

variable "kube_config_file" {
}
variable "ingress_host" {
}
variable "namespace" { 
}
variable "username" {
}
variable "password" {
}
variable "ingress_class" {
}


provider "helm" {
  kubernetes {
    config_path = var.kube_config_file
  }
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
        cert-manager.io/issuer: letsencrypt-prod
    enabled: true
    hosts: 
    - ${var.ingress_host}
    tls:
    - hosts:
      - ${var.ingress_host}
      secretName: keycloak-cert
EOF
]

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
output "url" {
    value = "https://${yamldecode(helm_release.keycloak.metadata[0].values).keycloak.ingress.hosts[0]}"
}