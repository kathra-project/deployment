variable "ingress_host" {
}
variable "ingress_class" {
}
variable "ingress_cert_manager_issuer" {
}
variable "ingress_tls_secret_name" {
  default = "sonarqube-cert"
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


data "helm_repository" "oteemocharts" {
  name = "oteemocharts"
  url  = "https://oteemo.github.io/charts"
}

resource "kubernetes_secret" "sonarqube_config" {
  metadata {
    name        = "sonarqube-properties"
    namespace   = var.namespace
  }
  data = {
    "secret.properties"    = <<EOF

# https://github.com/vaulttec/sonar-auth-oidc/blob/master/src/main/java/org/vaulttec/sonarqube/auth/oidc/OidcConfiguration.java
sonar.auth.oidc.enabled=true
sonar.auth.oidc.issuerUri=${var.oidc_url}
sonar.auth.oidc.clientId.secured=${var.oidc_client_id}
sonar.auth.oidc.clientSecret.secured=${var.oidc_client_secret}
sonar.auth.oidc.allowUsersToSignUp=true
EOF
  }
}

resource "helm_release" "sonarqube" {

  name       = "sonarqube"
  repository = data.helm_repository.oteemocharts.metadata[0].name
  chart      = "sonarqube"
  namespace  = var.namespace

  values = [<<EOF

ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: "${var.ingress_class}"
    cert-manager.io/issuer: "${var.ingress_cert_manager_issuer}"
  hosts:
  - name: ${var.ingress_host}
    path: /
  tls:
  - hosts:
    - ${var.ingress_host}
    secretName: ${var.ingress_tls_secret_name == null ? "sonarqube-cert" : var.ingress_tls_secret_name}

plugins:
  install:
  - https://github.com/vaulttec/sonar-auth-oidc/releases/download/v2.0.0/sonar-auth-oidc-plugin-2.0.0.jar

sonarSecretProperties: ${kubernetes_secret.sonarqube_config.metadata[0].name}


EOF
]

}


output "namespace" {
    value = helm_release.sonarqube.namespace
}
output "name" {
    value = helm_release.sonarqube.name
}
output "url" {
    value = "https://${yamldecode(helm_release.sonarqube.metadata[0].values).ingress.hosts[0].name}"
}