
variable "namespace" { 
}
variable "name" {
}
variable "storage_class" {
  
}


resource "helm_release" "nfs" {
    name       = var.name
    chart      = "${path.module}/nfs"
    namespace  = var.namespace
    values = [<<EOF
configuration:
  persistence:
    size: 5Gi
    resourcePolicy: none
    storageClassName: ${var.storage_class}
EOF
]

}

data "kubernetes_service" "nfs" {
    metadata {
        name        = helm_release.nfs.metadata[0].name
        namespace   = helm_release.nfs.metadata[0].namespace
    }
    depends_on = [ helm_release.nfs ]
}

output "namespace" {
    value = helm_release.nfs.metadata[0].namespace
}
output "name" {
    value = helm_release.nfs.metadata[0].name
}
output "service_host" {
    value  = data.kubernetes_service.nfs.metadata[0].name
}
output "service_cluster_ip" {
    value  = data.kubernetes_service.nfs.spec[0].cluster_ip
}
