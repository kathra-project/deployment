

variable "namespace" {
}
variable "host" {
}
variable "username" {
}
variable "password" {
}


data "template_file" "sonar_scanner_config" {
    template = file("${path.module}/sonar-project.tpl.properties")

    vars = {
        url      = var.host
        username = var.username
        password = var.password
    }
}


resource "kubernetes_secret" "sonar_scanner_config" {
    metadata {
        name        = "jenkins-sonar-project-properties"
        namespace   = var.namespace
    }
    data = {
        "sonar-project.properties"   = data.template_file.sonar_scanner_config.rendered
    }
}

output "namespace" {
    value = kubernetes_secret.sonar_scanner_config.metadata[0].namespace
}
output "name" {
    value = kubernetes_secret.sonar_scanner_config.metadata[0].name
}
