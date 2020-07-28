

variable "namespace" {
}
variable "repository_url" {
}
variable "repository_username" {
}
variable "repository_password" {
}
variable "sonar_url" {
    default="http://localhost:9000"
}
variable "sonar_username" {
    default=""
}
variable "sonar_password" {
    default=""
}


data "template_file" "maven_settings" {
    template = file("${path.module}/settings.tpl.xml")

    vars = {
        repository_username            = var.repository_username
        repository_password            = var.repository_password
        repository_url                 = var.repository_url
        sonar_url                      = var.sonar_url
        sonar_username                 = var.sonar_username
        sonar_password                 = var.sonar_password
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
