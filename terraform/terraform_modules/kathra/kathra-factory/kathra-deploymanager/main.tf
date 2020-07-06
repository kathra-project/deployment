
variable "namespace" { 
}
variable "image" {
  default = "kathra/deploymanager-k8s"
}
variable "tag" {
  default = "stable"
}
variable "deployment_registry" {
}
variable "ingress_base" {

}

resource "helm_release" "deploymanager" {
  name       = "deploymanager"
  chart      = "${path.module}/../../../../../kathra-factory/kathra-deploymanager"
  namespace  = var.namespace
  timeout    = 600
  values = [<<EOF
image: ${var.image}
tag: ${var.tag}
mode: master
targetCluster: interne
domain: ${var.ingress_base}
protocol: https

docker:
  KATHRA_DOCKER_URL: ${var.deployment_registry.host}
  KATHRA_DOCKER_URL: ${var.deployment_registry.username}:${var.deployment_registry.password}
  TARGET_DOCKER_URL: ${var.deployment_registry.host}
  TARGET_DOCKER_AUTH: ${var.deployment_registry.username}:${var.deployment_registry.password}


resources:
  limits:
    cpu: "500m"
    memory: "256Mi"
  requests:
    cpu: "50m"
    memory: "128Mi"
    
rabbitmq:
  image: rabbitmq
  version: 3.7.4-management-alpine
  url: rabbitmq
  serviceType: ClusterIP
  username: guest
  password: guest
  nodePort: "31965"
  resources:
    limits:
      cpu: "500m"
      memory: "256Mi"
    requests:
      cpu: "50m"
      memory: "128Mi"


EOF
]

}


output "namespace" {
    value = helm_release.deploymanager.namespace
}
output "name" {
    value = helm_release.deploymanager.name
}
output "service_url" {
    value = "http://deploymanager/api/v1"
}
