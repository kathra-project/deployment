variable "group" {
    default = "kathra-backup"
}

variable location {
    default = "East US"
}

variable "client_secret" {
    default = ""
}
variable "tenant_id" {
    default = ""
}
variable "subscribtion_id" {
    default = ""
}
variable "velero_client_id" {
    default = ""
}
variable "velero_client_secret" {
    default = ""
}



variable "kube_config_file" {
    default =  ""
}

provider "helm" {
  kubernetes {
    config_path = var.kube_config_file
  }
  version = "0.10.4"
}

data "helm_repository" "vmware-tanzu" {
  name = "vmware-tanzu"
  url  = "https://vmware-tanzu.github.io/helm-charts"
}

resource "azurerm_resource_group" "example" {
  name      = var.group
  location  = var.location
}

resource "azurerm_storage_account" "example" {
  name                     = "kathrabackupaccountname"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "example" {
  name                  = "kathrabackupcontainer"
  resource_group_name   = azurerm_resource_group.example.name
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "private"
}

data "template_file" "credential" {
  template = file("${path.module}/velero.credential.tpl")
  
  vars = {
    ARM_SUBSCRIPTION_ID = var.subscribtion_id
    ARM_TENANT_ID = var.tenant_id
    ARM_CLIENT_ID = var.velero_client_id
    ARM_CLIENT_SECRET = var.velero_client_secret
    AKS_RESOURCE_GROUP = azurerm_resource_group.example.name
  }
}

resource "helm_release" "velero" {
  name       = "velero"
  repository = data.helm_repository.vmware-tanzu.metadata[0].name
  chart      = "vmware-tanzu/velero"
  version    = "2.7.4"
  namespace  = "velero"

  values  = ["${data.template_file.credential.rendered}"]

  set {
    name  = "configuration.provider"
    value = "azure"
  }
  set {
    name  = "configuration.backupStorageLocation.name"
    value = "azure"
  }
  set {
    name  = "configuration.backupStorageLocation.bucket"
    value = azurerm_storage_container.example.name
  }
  set {
    name  = "configuration.backupStorageLocation.config.storageAccount"
    value = azurerm_storage_account.example.name
  }
  set {
    name  = "configuration.backupStorageLocation.config.resourceGroup"
    value = azurerm_resource_group.example.name
  }
  set {
    name  = "configuration.volumeSnapshotLocation.name"
    value = "azure"
  }
  set {
    name  = "configuration.volumeSnapshotLocation.bucket"
    value = azurerm_storage_container.example.name
  }
  set {
    name  = "configuration.volumeSnapshotLocation.config.storageAccount"
    value = azurerm_storage_account.example.name
  }
  set {
    name  = "configuration.volumeSnapshotLocation.config.resourceGroup"
    value = azurerm_resource_group.example.name
  }
  set {
    name  = "image.repository"
    value = "velero/velero"
  }
  set {
    name  = "image.tag"
    value = "v1.2.0"
  }
  set {
    name  = "image.pullPolicy"
    value = "IfNotPresent"
  }
  set {
    name  = "initContainers[0].name"
    value = "velero-plugin-for-microsoft-azure"
  }
  set {
    name  = "initContainers[0].image"
    value = "velero/velero-plugin-for-microsoft-azure:v1.0.0"
  }
  set {
    name  = "initContainers[0].volumeMounts[0].mountPath"
    value = "/target"
  }
  set {
    name  = "initContainers[0].volumeMounts[0].name"
    value = "plugins"
  }

}