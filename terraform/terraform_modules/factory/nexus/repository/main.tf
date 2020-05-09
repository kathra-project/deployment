variable "repository_name" {
  
}
variable "type" {
  
}
variable "format" {
  
}
variable "url" {
  
}
variable "username" {
  
}
variable "password" {
  
}
variable "members" {
    default = null
}




data "external" "repository" {
    program = ["bash", "-c", "${path.module}/generate_api_token.sh"]
    query = {
        nexus_url        = var.url
        repository_name  = var.repository_name 
        username         = var.username
        password         = var.password
        type             = var.type
        format           = var.format
        members          = jsonencode(var.members)
    }
}

output "api_token" {
    value = data.external.repository.result.url
}

