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

resource "helm_release" "sonarqube" {

  name       = "sonarqube"
  repository = data.helm_repository.oteemocharts.metadata[0].name
  chart      = "sonarqube"
  version    = "6.2.2"
  namespace  = var.namespace
  timeout    = 600

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

sonarProperties:
  sonar.forceAuthentication: "true"
  sonar.auth.oidc.enabled: "true"
  sonar.auth.oidc.clientId.secured: "${var.oidc_client_id}"
  sonar.auth.oidc.clientSecret.secured: "${var.oidc_client_secret}"
  sonar.auth.oidc.groupsSync: "true"
  sonar.auth.oidc.groupsSync.claimName: "groups"
  sonar.core.serverBaseURL: "https://${var.ingress_host}"
  sonar.auth.oidc.issuerUri: "${var.oidc_url}"
  sonar.auth.oidc.providerConfiguration: "{\"issuer\":\"${var.oidc_url}\",\"authorization_endpoint\":\"${var.oidc_url}/protocol/openid-connect/auth\",\"token_endpoint\":\"${var.oidc_url}/protocol/openid-connect/token\",\"token_introspection_endpoint\":\"${var.oidc_url}/protocol/openid-connect/token/introspect\",\"userinfo_endpoint\":\"${var.oidc_url}/protocol/openid-connect/userinfo\",\"end_session_endpoint\":\"${var.oidc_url}/protocol/openid-connect/logout\",\"jwks_uri\":\"${var.oidc_url}/protocol/openid-connect/certs\",\"check_session_iframe\":\"${var.oidc_url}/protocol/openid-connect/login-status-iframe.html\",\"grant_types_supported\":[\"authorization_code\",\"implicit\",\"refresh_token\",\"password\",\"client_credentials\"],\"response_types_supported\":[\"code\",\"none\",\"id_token\",\"token\",\"id_token token\",\"code id_token\",\"code token\",\"code id_token token\"],\"subject_types_supported\":[\"public\",\"pairwise\"],\"id_token_signing_alg_values_supported\":[\"ES384\",\"RS384\",\"HS256\",\"HS512\",\"ES256\",\"RS256\",\"HS384\",\"ES512\",\"RS512\"],\"userinfo_signing_alg_values_supported\":[\"ES384\",\"RS384\",\"HS256\",\"HS512\",\"ES256\",\"RS256\",\"HS384\",\"ES512\",\"RS512\",\"none\"],\"request_object_signing_alg_values_supported\":[\"none\",\"RS256\"],\"response_modes_supported\":[\"query\",\"fragment\",\"form_post\"],\"registration_endpoint\":\"${var.oidc_url}/clients-registrations/openid-connect\",\"token_endpoint_auth_methods_supported\":[\"private_key_jwt\",\"client_secret_basic\",\"client_secret_post\",\"client_secret_jwt\"],\"token_endpoint_auth_signing_alg_values_supported\":[\"RS256\"],\"claims_supported\":[\"sub\",\"iss\",\"auth_time\",\"name\",\"given_name\",\"family_name\",\"preferred_username\",\"email\"],\"claim_types_supported\":[\"normal\"],\"claims_parameter_supported\":false,\"scopes_supported\":[\"openid\",\"phone\",\"address\",\"email\",\"profile\",\"offline_access\"],\"request_parameter_supported\":true,\"request_uri_parameter_supported\":true,\"code_challenge_methods_supported\":[\"plain\",\"S256\"],\"tls_client_certificate_bound_access_tokens\":true,\"introspection_endpoint\":\"${var.oidc_url}/protocol/openid-connect/token/introspect\"}"



resources: 
  limits:
    cpu: 2
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 512Mi

EOF
]

}

output "admin" {
    value = {
        username = "admin"
        password = "admin"
    }
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