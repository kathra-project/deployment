

variable "namespace" {
}
variable "url" {
}
variable "username" {
}
variable "password" {
}


data "template_file" "pypi_config" {
    template = file("${path.module}/pipyrc.tpl")

    vars = {
        url                 = var.url
        username            = var.username
        password            = var.password
    }
}


resource "kubernetes_secret" "pypi_config" {
    metadata {
        name        = "pypi-config"
        namespace   = var.namespace
    }
    data = {
        ".pypirc"   = data.template_file.pypi_config.rendered
    }
}

output "namespace" {
    value = kubernetes_secret.pypi_config.metadata[0].namespace
}
output "name" {
    value = kubernetes_secret.pypi_config.metadata[0].name
}
