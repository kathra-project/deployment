variable "ingress_host" {
}
variable "ingress_class" {
}
variable "ingress_cert_manager_issuer" {
}
variable "ingress_tls_secret_name" {
  default = {
    unicorn = "gitlab-unicorn-tls"
    registry = "gitlab-registry-tls"
    minio = "gitlab-minio-tls"
  }
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

data "helm_repository" "gitlab" {
  name = "gitlab"
  url  = "https://charts.gitlab.io/"
}

resource "kubernetes_secret" "gitlab-root-pwd" {
  metadata {
    name        = "gitlab-root-pwd"
    namespace   = var.namespace
  }
  data = {
    password    = var.password
  }
}



resource "helm_release" "gitlab" {
  name       = "gitlab"
  repository = data.helm_repository.gitlab.metadata[0].name
  chart      = "gitlab"
  namespace  = var.namespace
  timeout    = 1200
  values = [<<EOF
nginx-ingress:
  enabled: false
certmanager:
  install: false
prometheus:
  install: false

gitlab:
  unicorn:
    ingress:
      tls:
        secretName: ${var.ingress_tls_secret_name.unicorn}
registry:
  ingress:
    tls:
      secretName: ${var.ingress_tls_secret_name.registry}
minio:
  ingress:
    tls:
      secretName: ${var.ingress_tls_secret_name.minio}

global:
  hosts:
    domain: ${var.ingress_host}
    gitlab:
      name: ${var.ingress_host}
    registry:
      name: registry-${var.ingress_host}
    minio:
      name: minio-${var.ingress_host}
  edition: ce
  ingress:
    configureCertmanager: false
    annotations:
      kubernetes.io/ingress.class: "${var.ingress_class}"
      cert-manager.io/issuer: "${var.ingress_cert_manager_issuer}"
    enabled: true

       
  appConfig:
    omniauth:
      enabled: true
      allowSingleSignOn: 
        - saml
        - openid_connect
      blockAutoCreatedUsers: false
      providers:
        - secret: "${kubernetes_secret.gitlab_omniauth_keycloak.metadata[0].name}"
EOF
]

}
resource "kubernetes_secret" "gitlab_omniauth_keycloak" {
  metadata {
    name        = "gitlab-omniauth-keycloak"
    namespace   = var.namespace
  }
  data = {
    "provider" = <<EOF
name: "openid_connect"
label: "keycloak"
args:
  name: "openid_connect"
  scope: ["openid", "profile"]
  response_type: "code"
  issuer: "${var.oidc_url}"
  discovery: true
  client_auth_method: "query"
  uid_field: "uid_field"
  client_options:
    identifier: "${var.oidc_client_id}"
    secret: "${var.oidc_client_secret}"
    redirect_uri: "https://${var.ingress_host}/users/auth/openid_connect/callback"
EOF
  }
}

/*


      enabled: true
      syncProfileFromProvider: []
      syncProfileAttributes: ['email']
      allowSingleSignOn:
        - openid_connect
      autoSignInWithProvider:
        - openid_connect
      blockAutoCreatedUsers: true
      autoLinkLdapUser: false
      autoLinkSamlUser: false
      externalProviders:
        - openid_connect
      allowBypassTwoFactor: []
      providers:

        - name: "oauth2_generic"
          label: "keycloak"
          app_id: "${var.oidc_client_id}"
          app_secret: "${var.oidc_client_secret}"
          args:
            name: "oauth2_generic"
            scope:
             - openid
             - profile
             - email
            issuer: "${var.oidc_url}"
            user_response_structure:
              attributes: 
                email: "email"
                first_name: "given_name"
                last_name: "family_name"
                name: "name"
                nickname: "preferred_username"
              id_path: "preferred_username"
            client_options:
              identifier: "${var.oidc_client_id}"
              secret: "${var.oidc_client_secret}"
              site: "${var.ingress_host}"
              authorize_url: "/auth/realms/kathra/protocol/openid-connect/userinfo"
              redirect_uri: "/auth/realms/kathra/protocol/openid-connect/auth"
              token_url: "/auth/realms/kathra/protocol/openid-connect/token"

*/


output "namespace" {
    value = helm_release.gitlab.namespace
}
output "name" {
    value = helm_release.gitlab.name
}
output "username" {
    value = "admin"
}
output "password" {
    //value = yamldecode(helm_release.gitlab.metadata[0].values).global.initialRootPassword
    value = ""
}
output "host" {
    value = yamldecode(helm_release.gitlab.metadata[0].values).global.hosts.domain
}
output "service" {
    value = "gitlab"
}
output "url" {
    value = "https://${yamldecode(helm_release.gitlab.metadata[0].values).global.hosts.domain}"
}