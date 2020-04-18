
variable "kube_config_file" {
}
variable "namespace" {
}
variable "username" {
}
variable "password" {
}


variable "ingress_host" {
}

variable "group" {
    default =  "kathra"
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

  values = [ <<EOF

keycloak:
  username: ${var.username}
  password: ${var.password}
  image:
    tag: 9.0.2
  ingress:
    enabled: true
    hosts:
    - ${var.ingress_host}
    annotations:
      kubernetes.io/ingress.class: traefik
      cert-manager.io/issuer: letsencrypt-prod
    tls:
    - hosts:
      - ${var.ingress_host}
      secretName: keycloak-cert
  persistence.deployPostgres: true
  
EOF

  ]
  
}

output "name" {
  value = "keycloak"
}
output "namespace" {
  value = helm_release.keycloak.namespace
}