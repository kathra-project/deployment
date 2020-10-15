variable "ingress_host" {
}
variable "ingress_class" {
}
variable "ingress_tls_secret_name" {
  default = {
    harbor = "harbor-cert"
    notary = "harbor-cert-notary"
  }
}
variable "ingress_cert_manager_issuer" {
}
variable "namespace" { 
}
variable "password" {
}
variable "oidc_url" {
}
variable "oidc_client_id" {
}
variable "oidc_client_secret" {
}
variable "resource_limits_cpu" {
  default = "1"
}
variable "resource_limits_memory" {
  default = "1Gi"
}

resource "helm_release" "harbor" {
    name       = "harbor"
    repository = "https://helm.goharbor.io"
    chart      = "harbor"
    namespace  = var.namespace
    timeout    = 800
    version    = "v1.3.0"

    values = [<<EOF
externalURL: https://${var.ingress_host}

harborAdminPassword: ${var.password}

expose:
  tls:
    enabled: true
    secretName: ${var.ingress_tls_secret_name.harbor == null ? "harbor-cert" : var.ingress_tls_secret_name.harbor}
    notarySecretName: ${var.ingress_tls_secret_name.notary == null ? "harbor-notary-cert" : var.ingress_tls_secret_name.notary}
  ingress:
    labels:
      ingress: tls
    hosts:
      core: ${var.ingress_host}
      notary: notary-${var.ingress_host}
    annotations:
      kubernetes.io/ingress.class: ${var.ingress_class}
      cert-manager.io/issuer: "${var.ingress_cert_manager_issuer}"

auth:
  mode: oidc_auth
  selfRegistration: "off"
  oidc:
    scope: "openid,email"
    clientId: "${var.oidc_client_id}"
    clientSecret: "${var.oidc_client_secret}"
    endpoint: "${var.oidc_url}"

portal:
  replicas: 1
  resources:
    limits:
      memory: ${var.resource_limits_memory}
      cpu: ${var.resource_limits_cpu}
    requests:
      memory: 128Mi
      cpu: 100m

core:
  replicas: 1
  resources:
    limits:
      memory: ${var.resource_limits_memory}
      cpu: ${var.resource_limits_cpu}
    requests:
      memory: 128Mi
      cpu: 100m

registry:
  replicas: 1
  resources:
    limits:
      memory: ${var.resource_limits_memory}
      cpu: ${var.resource_limits_cpu}
    requests:
      memory: 128Mi
      cpu: 100m

chartmuseum:
  replicas: 1
  resources:
    limits:
      memory: ${var.resource_limits_memory}
      cpu: ${var.resource_limits_cpu}
    requests:
      memory: 128Mi
      cpu: 100m

clair:
  clair:
    resources:
      limits:
        memory: ${var.resource_limits_memory}
        cpu: ${var.resource_limits_cpu}
      requests:
        memory: 128Mi
        cpu: 100m
  
  adapter:
    resources:
      limits:
        memory: ${var.resource_limits_memory}
        cpu: ${var.resource_limits_cpu}
      requests:
        memory: 128Mi
        cpu: 100m

trivy:
  replicas: 1
  resources:
    limits:
      memory: ${var.resource_limits_memory}
      cpu: ${var.resource_limits_cpu}
    requests:
      memory: 128Mi
      cpu: 100m

notary:
  server:
    resources:
      limits:
        memory: ${var.resource_limits_memory}
        cpu: ${var.resource_limits_cpu}
      requests:
        memory: 128Mi
        cpu: 100m
  
  signer:
    resources:
      limits:
        memory: ${var.resource_limits_memory}
        cpu: ${var.resource_limits_cpu}
      requests:
        memory: 128Mi
        cpu: 100m

database:
  internal:
    resources:
      limits:
        memory: ${var.resource_limits_memory}
        cpu: ${var.resource_limits_cpu}
      requests:
        memory: 128Mi
        cpu: 100m

redis:
  internal:
    resources:
      limits:
        memory: ${var.resource_limits_memory}
        cpu: ${var.resource_limits_cpu}
      requests:
        memory: 128Mi
        cpu: 100m
EOF
]

}

resource "null_resource" "harbor_oidc_config" {
    provisioner "local-exec" {
        command     = "bash ${path.module}/oidc-config.sh"
        environment = {
            ADMIN_USER                     = "admin"
            ADMIN_PASSWORD                 = var.password
            HARBOR_CONFIGURATIONS_ENDPOINT = "https://${var.ingress_host}/api/configurations"
            OIDC_ENDPOINT                  = var.oidc_url
            OIDC_SCOPE                     = "openid,email"
            OIDC_GROUP_CLAIM               = "groups"
            OIDC_CLIENT_ID                 = var.oidc_client_id
            OIDC_CLIENT_SECRET             = var.oidc_client_secret
        }
    }
    depends_on = [helm_release.harbor]
}

output "namespace" {
    value = helm_release.harbor.namespace
}
output "name" {
    value = helm_release.harbor.name
}

output "admin" {
  value = {
    username = "admin"
    password = yamldecode(helm_release.harbor.metadata[0].values).harborAdminPassword
  }
}

output "host" {
    value = yamldecode(helm_release.harbor.metadata[0].values).expose.ingress.hosts.core
}
output "url" {
    value = yamldecode(helm_release.harbor.metadata[0].values).externalURL
}