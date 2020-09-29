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
  version    = "2.8.0"

  values = [<<EOF
nexusProxy:
  env:
    nexusDockerHost: ${var.ingress_host}
    nexusHttpHost: ${var.ingress_host}
  resources:
    limits:
      cpu: 250m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

nexus:
  adminPassword: ${var.password}
  imageName: sonatype/nexus3
  imageTag: 3.25.1
  resources:
    limits:
      cpu: 2
      memory: 4800Mi
    requests:
      cpu: 500m
      memory: 1024Mi
nexusBackup:
  nexusAdminPassword: ${var.password}
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250
      memory: 128Mi

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


resource "nexus_user" "kathra_user" {
    userid    = "kathra_admin"
    firstname = "Administrator"
    lastname  = "User"
    email     = "nexus@example.com"
    password  = var.password
    roles     = ["nx-admin"]
    status    = "active"
}

resource "null_resource" "allow_anonymous" {
    provisioner "local-exec" {
      command = <<EOT
for attempt in $(seq 1 100); do sleep 5 && curl --fail -u "${nexus_user.kathra_user.userid}:${nexus_user.kathra_user.password}" -X PUT "https://${yamldecode(helm_release.nexus.metadata[0].values).nexusProxy.env.nexusHttpHost}/service/rest/beta/security/anonymous" -H  "accept: application/json" -H  "Content-Type: application/json" -d "{  \"enabled\": true,  \"userId\": \"anonymous\",  \"realmName\": \"NexusAuthorizingRealm\"}"  && exit 0 || echo "Unable to update anonymous access ($attempt/100)"; done
    EOT
      interpreter = ["bash", "-c"]
    }
    depends_on = [ nexus_user.kathra_user, helm_release.nexus ]
}

module "default_repositories" {
    source = "./repositories"
    nexus_url = "https://${yamldecode(helm_release.nexus.metadata[0].values).nexusProxy.env.nexusHttpHost}"
    username  = "admin"
    password  = "admin123"
    vm_depends_on = [ null_resource.allow_anonymous ]
}
/*
output "repositories" {
    value = module.default_repositories
}
*/




provider "nexus" {
    insecure = true
    url      = "https://${yamldecode(helm_release.nexus.metadata[0].values).nexusProxy.env.nexusHttpHost}"
    username = "admin"
    password = "admin123"
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