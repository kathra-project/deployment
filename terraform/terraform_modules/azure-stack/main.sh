#/bin/bash
export SCRIPT_DIR=$(realpath $(dirname `which $0`))
export tmp=/tmp/kathra.azure.Wrapper
export KUBECONFIG=$tmp/kube_config
[ ! -d $tmp ] && mkdir $tmp

cd $SCRIPT_DIR

export debug=1
export domain=""
export domainLabel=""

export terraformModules=$SCRIPT_DIR/../terraform_modules
export azureStackModule=$SCRIPT_DIR

export azureGroupName="kathra"
export azureLocation="eastus"

export terraformVersion="0.12.21"
export traefikChartVersion="1.85.0"

export kubernetesVersion="1.15.10"

export kathraChartVersion="master"
export kathraImagesTag="stable"

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
}
export -f showHelp

function showHelpDeploy() {
    printInfo "KATHRA Azure Install Wrapper"
    printInfo ""
    printInfo "Deploy options : "
    printInfo "--domain=<my-domain.xyz>                       :        Full base domain"
    printInfo ""
    printInfo "--charts-version=<branch|tag>                  :        Charts version [default: $kathraChartsVersion]"
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
            --charts-version)               kathraChartsVersion=$value;;
            --images-tag)                   kathraImagesTag=$value;;
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

    [ "$domain" == "" ] && printError "Domain and Azure Domain Label are undefined" && showHelpDeploy && exit 1
    [ "$ARM_SUBSCRIPTION_ID" == "" ] && printError "ARM_SUBSCRIPTION_ID undefined" && showHelpDeploy && exit 1
    [ "$ARM_CLIENT_ID" == "" ] && printError "ARM_CLIENT_ID undefined" && showHelpDeploy && exit 1
    [ "$ARM_CLIENT_SECRET" == "" ] && printError "ARM_CLIENT_SECRET undefined" && showHelpDeploy && exit 1
    [ "$ARM_TENANT_ID" == "" ] && printError "ARM_TENANT_ID undefined" && showHelpDeploy && exit 1

    cd $azureStackModule
    initTfVars $azureStackModule/terraform.tfvars

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
    echo "k8s_client_id = \"$ARM_CLIENT_ID\"" >> $file
    echo "k8s_client_secret = \"$ARM_CLIENT_SECRET\"" >> $file
    echo "k8s_version = \"$kubernetesVersion\"" >> $file
}

function deploy() {
    printDebug "deploy()"
    checkDependencies

    # Deploy Kubernetes and configure
    terraform init || printErrorAndExit "Terraform : Unable to init"
    terraform apply -auto-approve || printErrorAndExit "Terraform : Unable to apply"
    terraform output kubeconfig_content > $KUBECONFIG  || printErrorAndExit "Terraform : Unable to get kubeconfig_content"

    kubectl get nodes || printErrorAndExit "Unable to connect to Kubernetes server"

    # Deploy Kathra
    export KUBECONFIG=$KUBECONFIG
    printInfo "Force to restart kubedb and kube-system pods [ aks issues ]"
    kubectl -n kube-system delete pods --all
    kubectl -n kubedb delete pods --all
    printInfo "export KUBECONFIG=$KUBECONFIG"
    printInfo "install.sh --domain=$domain --chart-version=$kathraChartsVersion --kathra-image-tag=$kathraImagesTag --enable-tls-ingress --verbose"
    $SCRIPT_DIR/../install.sh --domain=$domain --chart-version=$kathraChartsVersion --kathra-image-tag=$kathraImagesTag --enable-tls-ingress --verbose
    return $?
}
export -f deploy

function destroy() {
    printDebug "destroy()"
    checkDependencies
    terraform init 
    terraform destroy
    return $?
}
export -f destroy


function checkDependencies() {
    printDebug "checkDependencies()"
    which curl > /dev/null || sudo apt-get install curl -y > /dev/null 2> /dev/null 
    which jq >  /dev/null || sudo apt-get install jq -y > /dev/null 2> /dev/null 
    which unzip > /dev/null || sudo apt-get install unzip -y > /dev/null 2> /dev/null 
    which az > /dev/null || installAzureCli
    which kubectl > /dev/null || installKubectl
    which terraform > /dev/null || installTerraform
}
export -f checkDependencies

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

function installKubectl() {
    printDebug "installKubectl()"
    which kubectl > /dev/null 2> /dev/null && return 0
    sudo curl -L -o $tmp/kubectl https://storage.googleapis.com/kubernetes-release/release/v$kubernetesVersion/bin/linux/amd64/kubectl 
    sudo chmod +x $tmp/kubectl 
    sudo mv $tmp/kubectl /usr/local/bin/kubectl
}
export -f installKubectl
 
function installTerraform() {
    printDebug "installTerraform()"
    which terraform > /dev/null 2> /dev/null && return 0
    sudo apt-get install unzip
    [ -f /tmp/terraform.zip ] && rm -f /tmp/terraform.zip
    curl https://releases.hashicorp.com/terraform/${terraformVersion}/terraform_${terraformVersion}_linux_amd64.zip > /tmp/terraform.zip
    unzip /tmp/terraform.zip
    sudo mv terraform /usr/local/bin/terraform
}
export -f installTerraform

function installTerraformModule() {
    printDebug "installTerraformModule($*)"
    local dir=$1
    local attemptMax=1
    cd $dir
    terraform init && terraform apply -auto-approve
}
export -f installTerraformModule

function installAndConfigureBackup() {
    printDebug "installAndConfigureBackup()"
    export TF_VAR_client_secret=$ARM_CLIENT_SECRET
    export TF_VAR_subscribtion=$ARM_SUBSCRIPTION_ID
    installTerraformModule $terraformModules/backup/azure
}
export -f installAndConfigureBackup

function installVeleroCli() {
    printDebug "installVeleroCli()"
    [ -f $veleroBin ] && return 0
    curl -L https://github.com/vmware-tanzu/velero/releases/download/v$veleroVersion/velero-v$veleroVersion-linux-amd64.tar.gz > $tmp/velero.tar.gz
    [ ! -d $tmp/velero ] && mkdir $tmp/velero
    tar -xvf $tmp/velero.tar.gz -C $tmp/velero
    chmod +x $veleroBin 
}
export -f installVeleroCli

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

function printErrorAndExit(){
    echo -e "\033[31;1m $* \033[0m" 1>&2 && exit 1
}
export -f printErrorAndExit
function printError(){
    echo -e "\033[31;1m $* \033[0m" 1>&2 && return 0
}
export -f printError
function printWarn(){
    echo -e "\033[33;1m $* \033[0m" 1>&2 && return 0
}
export -f printWarn
function printInfo(){
    echo -e "\033[33;1m $* \033[0m" 1>&2 && return 0
}
export -f printInfo
function printDebug(){
    [ "$debug" == "1" ] && echo -e "\033[94;1m $* \033[0m" 1>&2
    return 0
}
export -f printDebug

function findInArgs() {
    local keyToFind=$1
    shift 
    POSITIONAL=()
    while [[ $# -gt 0 ]]
    do
        [ "$(echo "$1" | cut -d'=' -f1)" == "${keyToFind}" ] && echo $(echo "$1" | cut -d'=' -f2) && return 0
        shift
    done
    return 1
}
export -f findInArgs

main $*

exit $?