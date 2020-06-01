variable "project_name" {
}
variable location {
}
variable "node_count" {
    default = 4
}
variable "node_size" {
    default = "n1-standard-4"
}

variable "kubernetes_version" {
    default = "1.16.8-gke.15"
}

resource "random_id" "username" {
    byte_length = 14
}

resource "random_id" "password" {
    byte_length = 16
}

resource "google_container_cluster" "kubernetes" {
    name               = "kathra-cluster"
    initial_node_count = var.node_count

    master_auth {
        username = random_id.username.hex
        password = random_id.password.hex
        client_certificate_config {
            issue_client_certificate = true
        }
    }

    node_config {
        machine_type = var.node_size

        oauth_scopes = [
            "https://www.googleapis.com/auth/compute",
            "https://www.googleapis.com/auth/devstorage.read_only",
            "https://www.googleapis.com/auth/logging.write",
            "https://www.googleapis.com/auth/monitoring",
        ]

        tags = ["kathra-cluster"]
    }

    min_master_version = var.kubernetes_version
}



output "kube_config" {
    value = {
        name                      =  google_container_cluster.kubernetes.name
        host                      =  google_container_cluster.kubernetes.endpoint
        username                  =  google_container_cluster.kubernetes.master_auth[0].username
        password                  =  google_container_cluster.kubernetes.master_auth[0].password
        client_certificate        =  google_container_cluster.kubernetes.master_auth[0].client_certificate
        client_key                =  google_container_cluster.kubernetes.master_auth[0].client_key
        cluster_ca_certificate    =  google_container_cluster.kubernetes.master_auth[0].cluster_ca_certificate
    }
}