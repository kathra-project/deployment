variable "k8s_client_id" {
}
variable "k8s_client_secret" {
}
variable "agent_count" {
    default = 2
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
    default = "kathra-k8s"
}
variable location {
}
variable "kubernetes_version" {
    default = "1.15.10"
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
        node_count      = var.agent_count
        vm_size         = "Standard_DS3_v2"
    }

    service_principal {
        client_id     = var.k8s_client_id
        client_secret = var.k8s_client_secret
    }
}

output "kube_config" {
    value = azurerm_kubernetes_cluster.k8s.kube_config_raw
}