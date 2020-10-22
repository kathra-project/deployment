variable "version_chart" {
    default = "8.2.2"
}
variable "kube_config" {
}
variable "ingress_host" {
}
variable "ingress_tls_secret_name" {
  default = "keycloak-cert"
}
variable "ingress_cert_manager_issuer" {
}
variable "namespace" { 
}
variable "username" {
}
variable "password" {
}
variable "ingress_class" {
}
variable "storage_class" {
  default = "default"
}

data "helm_repository" "cetic" {
  name = "cetic"
  url  = "https://cetic.github.io/helm-charts"
}

resource "helm_release" "postgresql" {
  name          = "keycloak-db"
  repository    = data.helm_repository.cetic.metadata[0].name
  chart         = "postgresql"
  namespace     = var.namespace
  version       = "0.2.0"

  values = [<<EOF
postgresql:
  username: "${var.username}"
  password: "${var.password}"
  database: "keycloak"
persistence:
  enabled: true
  storageClass: ${var.storage_class}
EOF
]
}

data "kubernetes_service" "postgresql" {
  metadata {
    name      = "${helm_release.postgresql.name}-postgresql"
    namespace = var.namespace
  }
  depends_on = [ helm_release.postgresql ]
}

resource "helm_release" "keycloak" {
  name       = "keycloak"
  repository = "https://codecentric.github.io/helm-charts"
  chart      = "keycloak"
  version    = var.version_chart
  namespace  = var.namespace
  
  values = [<<EOF
keycloak:
  username: "${var.username}"
  password: "${var.password}"
  persistence:
    deployPostgres: false
    dbVendor: postgres
    dbName:  '${yamldecode(helm_release.postgresql.metadata[0].values).postgresql.database}'
    dbHost: ${data.kubernetes_service.postgresql.metadata[0].name}
    dbPort: 5432
    dbUser: '${yamldecode(helm_release.postgresql.metadata[0].values).postgresql.username}'
    dbPassword: '${yamldecode(helm_release.postgresql.metadata[0].values).postgresql.password}'
  resources:
    limits:
      cpu: 2
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 128Mi
    
  javaToolOptions: "-XX:+UseContainerSupport -XX:MaxRAMPercentage=50.0 -Dkeycloak.profile.feature.upload_scripts=enabled"
  ingress:
    annotations:
        kubernetes.io/ingress.class: "${var.ingress_class}"
        cert-manager.io/issuer: "${var.ingress_cert_manager_issuer}"
    enabled: true
    hosts: 
    - ${var.ingress_host}
    tls:
    - hosts:
      - ${var.ingress_host}
      secretName: ${var.ingress_tls_secret_name == null ? "keycloak-cert" : var.ingress_tls_secret_name}

EOF
]

  depends_on = [ helm_release.postgresql ]
}

resource "null_resource" "check_tls_resolution" {
    provisioner "local-exec" {
      command = <<EOT
for attempt in $(seq 1 100); do sleep 5 && curl --fail https://${var.ingress_host} && exit 0 || echo "Check https://${var.ingress_host} ($attempt/100)"; done
curl --fail https://${var.ingress_host} || exit 1
exit 1
    EOT
      interpreter = ["bash", "-c"]
    }
    depends_on = [ helm_release.keycloak ]
}




output "namespace" {
    value = helm_release.keycloak.namespace
}
output "name" {
    value = helm_release.keycloak.name
}

output "admin" {
  value = {
    username = yamldecode(helm_release.keycloak.metadata[0].values).keycloak.username
    password = yamldecode(helm_release.keycloak.metadata[0].values).keycloak.password
  }
}

output "host" {
    value = yamldecode(helm_release.keycloak.metadata[0].values).keycloak.ingress.hosts[0]
}
output "url" {
    value = "https://${yamldecode(helm_release.keycloak.metadata[0].values).keycloak.ingress.hosts[0]}"
}