variable "k8s_client_id" {
}
variable "k8s_client_secret" {
}
variable "node_count" {
    default = 2
}
variable "node_size" {
    default = "Standard_D8s_v3"
}

variable "ssh_public_key" {
    default = "~/.ssh/id_rsa.pub"
}
variable "dns_prefix" {
    default = "kathra-k8s"
}
variable "group" {
}
variable cluster_name {
    default = "k8s-instance"
}
variable location {
}
variable "kubernetes_version" {
}

resource "azurerm_kubernetes_cluster" "k8s" {
    name                = var.cluster_name
    location            = var.location
    resource_group_name = var.group
    dns_prefix          = var.dns_prefix
    kubernetes_version  = var.kubernetes_version

    linux_profile {
        admin_username = "ubuntu"

        ssh_key {
            key_data = file(var.ssh_public_key)
        }
    }

    default_node_pool {
        name            = "agentpool"
        node_count      = var.node_count
        vm_size         = var.node_size
    }

    service_principal {
        client_id     = var.k8s_client_id
        client_secret = var.k8s_client_secret
    }
}

output "kube_config_raw" {
    value = azurerm_kubernetes_cluster.k8s.kube_config_raw
}

output "kube_config" {
    value = {
        host                      =  azurerm_kubernetes_cluster.k8s.kube_config.0.host
        client_certificate        =  azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate
        client_key                =  azurerm_kubernetes_cluster.k8s.kube_config.0.client_key
        cluster_ca_certificate    =  azurerm_kubernetes_cluster.k8s.kube_config.0.cluster_ca_certificate
    }
}

output "azure_group" {
    value = "MC_${var.group}_${var.cluster_name}_${var.location}"
}
