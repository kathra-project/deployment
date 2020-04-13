variable "kube_config_file" {
}
variable "ingress_host" {
}
variable "ingress_class" {
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


provider "helm" {
  kubernetes {
    config_path = var.kube_config_file
  }
}

data "helm_repository" "gitlab" {
  name = "gitlab"
  url  = "https://charts.gitlab.io/"
}

resource "helm_release" "gitlab" {
  name       = "gitlab-ce"
  repository = data.helm_repository.gitlab.metadata[0].name
  chart      = "gitlab"
  namespace  = var.namespace

  values = [<<EOF
nginx-ingress:
    enabled: false
certmanager:
    install: false
prometheus:
    install: false
global:
    #initialRootPassword:
    #    secret: gitlab-root-pwd
    #    key: password
    #   ${var.password}
    hosts:
        domain: ${var.ingress_host}
    ingress:
        configureCertmanager: false
        annotations:
            kubernetes.io/ingress.class: "${var.ingress_class}"
            cert-manager.io/issuer: letsencrypt-prod
        enabled: true

    prometheus:
        enabled: false
    omniauth:
        enabled: true
        autoSignInWithProvider:
        syncProfileFromProvider: []
        syncProfileAttributes: ['email']
        allowSingleSignOn: ['saml']
        blockAutoCreatedUsers: true
        autoLinkLdapUser: false
        autoLinkSamlUser: false
        externalProviders: []
        allowBypassTwoFactor: []
        providers:
        - name: "openid_connect"
          label: "keycloak"
          args:
            name: "openid_connect"
            scope:
             - openid
             - profile
             - email
            response_type: "code"
            issuer: "${var.oidc_url}"
            discovery: true
            client_auth_method: "query"
            uid_field: "preferred_username"
            send_scope_to_token_endpoint: false
            client_options:
                identifier: "${var.oidc_client_id}"
                secret: "${var.oidc_client_secret}"
                redirect_uri: "${var.ingress_host}/users/auth/openid_connect/callback"
              

EOF
]

}

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
    value = yamldecode(helm_release.gitlab.metadata[0].values).global.initialRootPassword
}
output "url" {
    value = "https://${yamldecode(helm_release.gitlab.metadata[0].values).global.hosts.domain[0]}"
}