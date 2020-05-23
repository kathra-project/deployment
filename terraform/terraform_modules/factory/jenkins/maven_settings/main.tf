

variable "namespace" {
}
variable "url" {
}
variable "username" {
}
variable "password" {
}


data "template_file" "maven_settings" {
    template = file("${path.module}/settings.tpl.xml")

    vars = {
        username            = var.username
        password            = var.password
        url                 = var.url
    }
}


resource "kubernetes_secret" "maven_settings" {
    metadata {
        name        = "jenkins-maven-settings-xml"
        namespace   = var.namespace
    }
    data = {
        "settings.xml"   = data.template_file.maven_settings.rendered
    }
}

output "namespace" {
    value = kubernetes_secret.maven_settings.metadata[0].namespace
}
output "name" {
    value = kubernetes_secret.maven_settings.metadata[0].name
}
