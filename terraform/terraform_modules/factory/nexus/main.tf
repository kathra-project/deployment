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
  imageName: sonatype/nexus3
  imageTag: 3.23.0
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
    secretName: ${var.ingress_tls_secret_name == null ? "nexus-cert" : var.ingress_tls_secret_name}
EOF
]

}

module "default_repositories" {
    source = "./repositories"
    nexus_url = "https://${yamldecode(helm_release.nexus.metadata[0].values).nexusProxy.env.nexusHttpHost}"
    username  = "admin"
    password  = "admin123"
}
output "repositories" {
    value = module.default_repositories
}

provider "nexus" {
    insecure = true
    url      = "https://${yamldecode(helm_release.nexus.metadata[0].values).nexusProxy.env.nexusHttpHost}"
    username = "admin"
    password = "admin123"
}

resource "nexus_user" "kathra_user" {
  userid    = "kathra_admin"
  firstname = "Administrator"
  lastname  = "User"
  email     = "nexus@example.com"
  password  = var.password
  roles     = ["nx-admin"]
  status    = "active"
}

output "namespace" {
    value = helm_release.nexus.namespace
}
output "name" {
    value = helm_release.nexus.name
}
output "username" {
    value = nexus_user.kathra_user.userid
}
output "password" {
    value = nexus_user.kathra_user.password
}
output "service" {
    value = "http://sonatype-nexus-service:8081"
}
output "url" {
    value = "https://${yamldecode(helm_release.nexus.metadata[0].values).nexusProxy.env.nexusHttpHost}"
}