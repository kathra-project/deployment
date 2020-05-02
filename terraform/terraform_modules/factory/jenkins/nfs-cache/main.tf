
variable "namespace" { 
}
variable "name" {
}

resource "helm_release" "nfs" {
  name       = var.name
  chart      = "${path.module}/nfs"
  namespace  = var.namespace
  values = [<<EOF
configuration:
  persistence:
    PVC_STORAGE_SIZE: 5Gi
    resourcePolicy: none
EOF
]

}


output "namespace" {
    value = helm_release.nfs.namespace
}
output "name" {
    value = helm_release.nfs.name
}
output "service_host" {
    value  = helm_release.nfs.name
}