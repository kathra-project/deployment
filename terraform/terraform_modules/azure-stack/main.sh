#/bin/bash
export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export tmp=/tmp/kathra.azure.Wrapper
export KUBECONFIG=$tmp/kube_config
[ ! -d $tmp ] && mkdir $tmp
. $SCRIPT_DIR/../common.sh

cd $SCRIPT_DIR

export debug=1
export domain=""
export azureStackModule=$SCRIPT_DIR
export azureGroupName="kathra"
export azureLocation="francecentral"
export kathraImagesTag="stable"
export kubernetesVersion="1.15.10"

export veleroVersion="1.2.0"
export veleroBin=$tmp/velero/velero-v$veleroVersion-linux-amd64/velero


function showHelp() {
    findInArgs "deploy" $* > /dev/null && showHelpDeploy $* && exit 0
    findInArgs "destroy" $* > /dev/null && showHelpDestroy $* && exit 0 
    printInfo "KATHRA Azure Install Wrapper"
    printInfo ""
    printInfo "Usage: "
    printInfo "deploy : Deploy on Azure"
    printInfo "destroy : Destroy on Azure"
    printInfo "backup-install : Configure backup on Azure"
    exit 0
}
export -f showHelp

function showHelpDeploy() {
    printInfo "KATHRA Azure Install Wrapper"
    printInfo ""
    printInfo "Deploy options : "
    printInfo "--domain=<my-domain.xyz>                       :        Full base domain"
    printInfo ""
    printInfo "--images-version=<tag>                         :        Images tags [default: $kathraImagesTag]"
    printInfo ""
    printInfo "--azure-group-name=<group-name>                :        Azure Group Name [default: $azureGroupName]"
    printInfo "--azure-location=<location>                    :        Azure Location [default: $azureLocation]"
    printInfo "--azure-subscribtion-id=<ARM_SUBSCRIPTION_ID>  :        Azure ARM_SUBSCRIPTION_ID [default: $ARM_SUBSCRIPTION_ID]"
    printInfo "--azure-client-id=<ARM_CLIENT_ID>              :        Azure ARM_CLIENT_ID [default: $ARM_CLIENT_ID]"
    printInfo "--azure-client-secret=<ARM_CLIENT_SECRET>      :        Azure ARM_CLIENT_SECRET [default: $ARM_CLIENT_SECRET]"
    printInfo "--azure-tenant-id=<ARM_TENANT_ID>              :        Azure ARM_TENANT_ID [default: $ARM_TENANT_ID]"
    printInfo ""
    printInfo "--kubernetes-version=<version>                 :        Kubernetes Version [default: $kubernetesVersion]"
    printInfo ""
    printInfo "--verbose                                      :        Enable DEBUG log level"
}
export -f showHelpDeploy

function showHelpDestroy() {
    printInfo "KATHRA Azure Install Wrapper"
    printInfo ""
    printInfo "Destroy options : "
}
export -f showHelpDestroy

function showHelpConfigureBackup() {
    printInfo "KATHRA Azure Install Wrapper"
    printInfo ""
    printInfo "backup-install options : "
    printInfo "--azure-username=<username>                :        Azure Username or AZURE_USERNAME as env var"
    printInfo "--azure-password=<location>                :        Azure Password or AZURE_PASSWORD as env var"
}
export -f showHelpConfigureBackup

function parseArgs() {
    for argument in "$@" 
    do
        local key=${argument%%=*}
        local value=${argument#*=}
        case "$key" in
            --domain)                       domain=$value;;
            --images-version)                   kathraImagesTag=$value;;
            --azure-group-name)             azureGroupName=$value;;
            --azure-location)               azureLocation=$value;;
            --azure-subscribtion-id)        ARM_SUBSCRIPTION_ID=$value;;
            --azure-client-id)              ARM_CLIENT_ID=$value;;
            --azure-client-secret)          ARM_CLIENT_SECRET=$value;;
            --azure-tenant-id)              ARM_TENANT_ID=$value;;
            --azure-username)               AZURE_USERNAME=$value;;
            --azure-password)               AZURE_PASSWORD=$value;;
            --verbose)                      debug=1;;
            --help|-h)                      showHelp $*;;
        esac    
    done
}

function main() {
    parseArgs $*    
    
    which az > /dev/null            || installAzureCli
    
    [ "$ARM_SUBSCRIPTION_ID" == "" ] && printError "ARM_SUBSCRIPTION_ID undefined" && showHelpDeploy && exit 1
    [ "$ARM_CLIENT_ID" == "" ] && printError "ARM_CLIENT_ID undefined" && showHelpDeploy && exit 1
    [ "$ARM_CLIENT_SECRET" == "" ] && printError "ARM_CLIENT_SECRET undefined" && showHelpDeploy && exit 1
    [ "$ARM_TENANT_ID" == "" ] && printError "ARM_TENANT_ID undefined" && showHelpDeploy && exit 1

    findInArgs "deploy" $* > /dev/null && deploy $* && return 0
    findInArgs "destroy" $* > /dev/null && destroy $* && return 0
    findInArgs "backup-install" $* > /dev/null && backupConfigure $* && return 0
}

function initTfVars() {
    local file=$1
    [ -f $file ] && rm $file
    echo "group = \"$azureGroupName\"" >> $file
    echo "location = \"$azureLocation\"" >> $file
    echo "domain = \"$domain\"" >> $file
    echo "kathra_version = \"$kathraImagesTag\"" >> $file
    echo "k8s_client_id = \"$ARM_CLIENT_ID\"" >> $file
    echo "k8s_client_secret = \"$ARM_CLIENT_SECRET\"" >> $file
    echo "subscribtion_id = \"$ARM_SUBSCRIPTION_ID\"" >> $file
    echo "tenant_id = \"$ARM_TENANT_ID\"" >> $file
    echo "k8s_version = \"$kubernetesVersion\"" >> $file
}

function deploy() {
    printDebug "deploy()"

    [ "$domain" == "" ] && printError "Domain are undefined" && showHelpDeploy && exit 1
    cd $azureStackModule
    initTfVars $azureStackModule/terraform.tfvars

    checkDependencies

    # Deploy Kubernetes and configure
    terraform init || printErrorAndExit "Terraform : Unable to init"


    local retrySecondInterval=10
    local attempt_counter=0
    local max_attempts=5
    while true; do
        terraform apply -auto-approve && return 0 
        printError "Terraform : Unable to apply, somes resources may be not ready, try again.. attempt ($attempt_counter/$max_attempts) "
        [ ${attempt_counter} -eq ${max_attempts} ] && printError "Check $1, error" && return 1
        attempt_counter=$(($attempt_counter+1))
        sleep $retrySecondInterval
    done

    terraform output kubeconfig_content > $KUBECONFIG  || printErrorAndExit "Terraform : Unable to get kubeconfig_content"

    # Post install
    postInstall
}
export -f deploy

function destroy() {
    printDebug "destroy()"
    checkDependencies
    terraform init 
    local statesToDelete=$(terraform state list | grep -E "factory|kubernetes_addons|kathra|helm_release")
    [ ! "$statesToDelete" == "" ] && terraform state rm $statesToDelete
    local resourcesToDestroy=$(terraform state list | grep "kubernetes" | sed -E 's/(.*)/--target=\1/g' | tr '\n' ' ')
    [ ! "$resourcesToDestroy" == "" ] && terraform destroy -auto-approve $resourcesToDestroy
    return $?
}
export -f destroy

function installAzureCli() {
    printDebug "installAzureCli()"
    which az > /dev/null 2> /dev/null && return 0

    sudo apt-get update && apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | 
      gpg --dearmor | 
      sudo tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
    AZ_REPO=$(lsb_release -cs)
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | 
    sudo tee /etc/apt/sources.list.d/azure-cli.list
    sudo apt-get update && apt-get install -y azure-cli
}
export -f installAzureCli


function backupConfigure() {
    printDebug "backupConfigure()"

    [ "$ARM_SUBSCRIPTION_ID" == "" ] && printError "ARM_SUBSCRIPTION_ID undefined" && showHelpDeploy && exit 1
    [ "$ARM_CLIENT_ID" == "" ] && printError "ARM_CLIENT_ID undefined" && showHelpDeploy && exit 1
    [ "$ARM_CLIENT_SECRET" == "" ] && printError "ARM_CLIENT_SECRET undefined" && showHelpDeploy && exit 1
    [ "$ARM_TENANT_ID" == "" ] && printError "ARM_TENANT_ID undefined" && showHelpDeploy && exit 1

    local VELERO_RESOURCE_GROUP_NAME="kathra-backup" # Resource group where storage account will be created and used to store a backups
    local VELERO_STORAGE_ACCOUNT_NAME="kathrabackupaccountname" # Storage account name for Velero backups 
    local VELERO_BLOB_CONTAINER_NAME="kathrabackupcontainer" # Blob container for Velero backups
    local VELERO_SP_NAME="KathraSpVelero" # A name for Velero Azure AD service principal name
    local AKS_RESOURCE_GROUP="MC_kathra_kathra-k8s_$azureLocation" # Name of the auto-generated resource group that is created when you provision your cluster in Azure
    
    az login 
    az account set --subscription $ARM_SUBSCRIPTION_ID

    # Create and configure storage
    az group create --location $azureLocation --name $VELERO_RESOURCE_GROUP_NAME
    az storage account create --name $VELERO_STORAGE_ACCOUNT_NAME --resource-group $VELERO_RESOURCE_GROUP_NAME --location $LOCATION --kind StorageV2 --sku Standard_LRS --encryption-services blob --https-only true --access-tier Hot
    az storage container create --name $VELERO_BLOB_CONTAINER_NAME --public-access off --account-name $VELERO_STORAGE_ACCOUNT_NAME
    
    # Create a credentials file for Velero
    echo "AZURE_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID" > $tmp/credentials-velero
    echo "AZURE_TENANT_ID=$ARM_TENANT_ID" >> $tmp/credentials-velero
    echo "AZURE_CLIENT_ID=$ARM_CLIENT_ID" >> $tmp/credentials-velero
    echo "AZURE_CLIENT_SECRET=$ARM_CLIENT_SECRET" >> $tmp/credentials-velero
    echo "AZURE_RESOURCE_GROUP=$AKS_RESOURCE_GROUP" >> $tmp/credentials-velero
    echo "AZURE_CLOUD_NAME=AzurePublicCloud" >> $tmp/credentials-velero
    
    helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
    helm repo update
    helm install --name velero2 --namespace velero \
    --set configuration.provider=azure \
    --set-file credentials.secretContents.cloud=$tmp/credentials-velero \
    --set configuration.backupStorageLocation.name=azure \
    --set configuration.backupStorageLocation.bucket=$VELERO_BLOB_CONTAINER_NAME \
    --set configuration.backupStorageLocation.config.storageAccount=$VELERO_STORAGE_ACCOUNT_NAME \
    --set configuration.backupStorageLocation.config.resourceGroup=$VELERO_RESOURCE_GROUP_NAME \
    --set configuration.volumeSnapshotLocation.name=azure \
    --set configuration.volumeSnapshotLocation.bucket=$VELERO_BLOB_CONTAINER_NAME \
    --set configuration.volumeSnapshotLocation.config.storageAccount=$VELERO_STORAGE_ACCOUNT_NAME \
    --set configuration.volumeSnapshotLocation.config.resourceGroup=$VELERO_RESOURCE_GROUP_NAME \
    --set image.repository=velero/velero \
    --set image.tag=v$veleroVersion \
    --set image.pullPolicy=IfNotPresent \
    --set initContainers[0].name=velero-plugin-for-microsoft-azure \
    --set initContainers[0].image=velero/velero-plugin-for-microsoft-azure:v1.0.0 \
    --set initContainers[0].volumeMounts[0].mountPath=/target \
    --set initContainers[0].volumeMounts[0].name=plugins \
    vmware-tanzu/velero

    installVeleroCli

    $veleroBin version || printErrorAndExit "Velero not installed"
    printInfo "Velero is installed"
    printInfo "To backup Kathra :"
    printInfo "$veleroBin backup create kathra-backup --include-namespaces kathra-factory,kathra-services"
    printInfo "$veleroBin restore create kathra-restore --from-backup kathra-backup "
    
}
export -f backupConfigure



main $*

exit $?
