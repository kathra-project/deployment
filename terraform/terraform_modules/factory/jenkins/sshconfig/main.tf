

variable "namespace" {
}
variable "ssh_host" {
}
variable "ssh_service" {
}
variable "ssh_user" {
    default = "git"
}
variable "ssh_service_port" {
    default = "22"
}


data "template_file" "sshconfig" {
    template = file("${path.module}/sshconfig.tpl")

    vars = {
        ssh_host            = var.ssh_host
        ssh_service         = var.ssh_service
        ssh_user            = var.ssh_user
        ssh_service_port    = var.ssh_service_port
    }
}


resource "kubernetes_secret" "sshconfig" {
    metadata {
        name        = "sshconfig"
        namespace   = var.namespace
    }
    data = {
        sshconfig   = data.template_file.sshconfig.rendered
    }
}

output "namespace" {
    value = kubernetes_secret.sshconfig.metadata[0].namespace
}
output "name" {
    value = kubernetes_secret.sshconfig.metadata[0].name
}
output "file" {
    value = "sshconfig"
}
