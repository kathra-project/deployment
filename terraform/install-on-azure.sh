#/bin/bash
export SCRIPT_DIR=$(realpath $(dirname `which $0`))
export tmp=/tmp/kathra.azure.Wrapper
export KUBECONFIG=$tmp/kube_config
[ ! -d $tmp ] && mkdir $tmp

cd $SCRIPT_DIR
export debug=1
export domain=""
export domainLabel=""
export azureGroupName="kathra"
export azureLocation="East US"
export terraformVersion="0.12.21"
export traefikChartVersion="1.85.0"
export kubeDbVersion="0.8.0"
export kubernetesVersion="1.14.8"

export kathraChartVersion="master"
export kathraImagesTag="stable"

export veleroVersion="1.2.0"
export veleroBin=$tmp/velero/velero-v$veleroVersion-linux-amd64/ 

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
    printInfo "--domainLabel=<my-azure-dns-label>             :        Prefix domain using Azure DNS label (eg:my-custom-label.eastus.cloudapp.azure.com)"
    printInfo ""
    printInfo "--charts-version=<branch|tag>                  :        Charts version [default: $kathraChartsVersion]"
    printInfo "--images-tag=<tag>                             :        Images tags [default: $kathraImagesTag]"
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
            --domainLabel)                  domainLabel=$value;;
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
    export TF_VAR_group="$azureGroupName"
    export TF_VAR_location="$azureLocation"
    findInArgs "deploy" $* > /dev/null && deploy $* && return 0
    findInArgs "destroy" $* > /dev/null && destroy $* && return 0
    findInArgs "backup-install" $* > /dev/null && backupConfigure $* && return 0
}

function deploy() {
    printDebug "deploy()"
    [ "$domain" == "" ] && printError "Domain and Azure Domain Label are undefined" && showHelpDeploy && exit 1
    [ "$ARM_SUBSCRIPTION_ID" == "" ] && printError "ARM_SUBSCRIPTION_ID undefined" && showHelpDeploy && exit 1
    [ "$ARM_CLIENT_ID" == "" ] && printError "ARM_CLIENT_ID undefined" && showHelpDeploy && exit 1
    [ "$ARM_CLIENT_SECRET" == "" ] && printError "ARM_CLIENT_SECRET undefined" && showHelpDeploy && exit 1
    [ "$ARM_TENANT_ID" == "" ] && printError "ARM_TENANT_ID undefined" && showHelpDeploy && exit 1

    # Install package and client
    sudo apt-get install curl jq unzip -y > /dev/null 2> /dev/null  
    installAzureCli
    installTerraform
    installKubectl

    ## Configure IP and DNS 
    reserveStaticIP
    
    ## Install kubernetes
    installKubernetes
    [ ! "$domain" == "" ] && printInfo "Please, add DNS entry *.$domain -> $INGRESS_PUBLIC_IP" && waitPublicIpIsResolvedByDns "$domain" "$INGRESS_PUBLIC_IP"
    [ ! "$DOMAIN_NAME_AZURE" == "" ] && waitPublicIpIsResolvedByDns "$DOMAIN_NAME_AZURE" "$INGRESS_PUBLIC_IP"
    
    ## Configure http ingress, ssl and features
    installTraefik
    installCertManager
    installKubeDB

    # Install kathra
    [ ! "$domain" == "" ] && installKathra "$domain" "$kathraChartsVersion" "$kathraImagesTag" || installKathra "$DOMAIN_NAME_AZURE" "$kathraChartsVersion" "$kathraImagesTag"

    return $?
}
export -f deploy

function destroy() {
    printDebug "destroy()"
    sudo apt-get install curl jq unzip -y > /dev/null 2> /dev/null  
    installAzureCli
    uninstallKubernetes
    rm $SCRIPT_DIR/terraform_modules/helm-packages/kubedb/terraform.* 2> /dev/null > /dev/null
    rm $SCRIPT_DIR/terraform_modules/helm-packages/cert-manager/terraform.* 2> /dev/null > /dev/null
    rm $SCRIPT_DIR/terraform_modules/helm-packages/traefik/terraform.* 2> /dev/null > /dev/null
    rm $SCRIPT_DIR/terraform_modules/kathra/terraform.* 2> /dev/null > /dev/null
    return $?
}
export -f destroy

function installKathra() {
    printDebug "installKathra(domainName: $1, chartsVersion: $2, imagesTag: $3)"
    local domainName=$1
    local chartsVersion=$2
    local imagesTag=$2
    kubectl --kubeconfig=$KUBECONFIG  -n kube-system delete pods -l name=tiller
    kubectl --kubeconfig=$KUBECONFIG  -n kube-system delete pods -l k8s-app=metrics-server

    export TF_VAR_charts_version="$chartsVersion"
    export TF_VAR_images_tag="$imagesTag"
    export TF_VAR_domain="$domainName"
    export TF_VAR_kube_config_file="$KUBECONFIG"

    installTerraformModule $SCRIPT_DIR/terraform_modules/kathra
}

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

function reserveStaticIP() {
    printDebug "reserveStaticIP()"
    [ ! "$domain_name_label" == "" ]  && export TF_VAR_domain_name_label=$domainLabel
    installTerraformModule $SCRIPT_DIR/terraform_modules/public-ip/azure
    printDebug "Wait until static IP is defined..."
    checkCommandAndRetry "terraform refresh && terraform output public_ip_address | grep -E '[0-9]*.[0-9]*.[0-9]*.[0-9]*'"
    terraform output public_ip_address > $tmp/public_ip_address 
    export INGRESS_PUBLIC_IP=$(cat $tmp/public_ip_address)
    printInfo "Your public IP is $INGRESS_PUBLIC_IP "

    if [ ! "$domain_name_label" == "" ]
    then
        printDebug "Wait until static domain label is defined..."
        checkCommandAndRetry "terraform refresh && terraform output domain_name_label | grep -E '.+'"
        terraform output domain_name_label > $tmp/domain_name_label 
        export DOMAIN_NAME_AZURE="$(cat $tmp/domain_name_label).$(echo $azureLocation | tr -d ' ' | tr '[:upper:]' '[:lower:]').cloudapp.azure.com"
        printInfo "Your domainName is $DOMAIN_NAME_AZURE"
    fi
}

function installKubernetes() {
    printDebug "installKubernetes()"
    local modulePath=$SCRIPT_DIR/terraform_modules/kubernetes/azure
    cd $modulePath
    export TF_VAR_k8s_client_id="$ARM_CLIENT_ID"
    export TF_VAR_k8s_client_secret="$ARM_CLIENT_SECRET"
    export TF_VAR_kubernete
    installTerraformModule $modulePath
    terraform output kube_config > $KUBECONFIG

    export TF_VAR_kube_config_file=$KUBECONFIG
    kubectl --kubeconfig=$KUBECONFIG get nodes || printErrorAndExit "Unable to connect Kubernetes"
}
export -f installKubernetes

function uninstallKubernetes() {
    printDebug "uninstallKubernetes()"
    local modulePath=$SCRIPT_DIR/terraform_modules/kubernetes/azure
    cd $modulePath
    terraform init
    terraform destroy
}
export tmp=/tmp/kathra.azure.Wrapper
export KUBECONFIG=$tmp/kube_config
export -f uninstallKubernetes

function installTerraformModule() {
    printDebug "installTerraformModule($*)"
    local dir=$1
    local attemptMax=3
    cd $dir
    for attempt in $(seq 1 $attemptMax); do terraform init && terraform apply -auto-approve && return 0 || printWarn "Unable to terraform apply, retry ($attempt/$attemptMax)"; done
    printErrorAndExit "Unable to terraform apply, too many attempts : $dir"
}
export -f installTerraformModule

function installTraefik() {
    printDebug "installTraefik()"
    export TF_VAR_version_chart=$traefikChartVersion
    export TF_VAR_load_balancer_ip=$INGRESS_PUBLIC_IP
    installTerraformModule $SCRIPT_DIR/terraform_modules/helm-packages/traefik
    
    checkCommandAndRetry "kubectl --kubeconfig=$KUBECONFIG -n traefik get svc traefik -o json | jq -r '.status.loadBalancer.ingress[0].ip' | grep -v null > /dev/null " 
    [ ! "$domain" == "" ] && export INGRESS_PUBLIC_IP=$(kubectl --kubeconfig=$KUBECONFIG -n traefik get svc traefik -o json | jq -r '.status.loadBalancer.ingress[0].ip' | grep -v null)
    [ ! "$domain" == "" ] && printInfo "Public IP Ingress $INGRESS_PUBLIC_IP"
    return $?
}
export -f installTraefik

function installKubeDB() {
    printDebug "installKubeDB()"
    curl -fsSL -o onessl https://github.com/kubepack/onessl/releases/download/0.3.0/onessl-linux-amd64 && chmod +x onessl && sudo mv onessl /usr/local/bin/
    export TF_VAR_apiserver_ca=$(onessl get kube-ca)
    export TF_VAR_version_chart=$kubeDbVersion
    installTerraformModule $SCRIPT_DIR/terraform_modules/helm-packages/kubedb
    return $?
}
export -f installKubeDB

function waitPublicIpIsResolvedByDns() {
    printDebug "waitPublicIpIsResolvedByDns($*)"
    local dnsEntry=$1
    local ipExpected=$2
    kubectl --kubeconfig=$KUBECONFIG delete pods dnstools 2> /dev/null > /dev/null
    checkCommandAndRetry "subDomain=\$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1) && kubectl --kubeconfig=$KUBECONFIG run -it --rm --restart=Never --image=infoblox/dnstools:latest dnstools -- '-c' \"host \$subDomain.$dnsEntry\" | grep \"\$subDomain.$dnsEntry has address $ipExpected\" > /dev/null" || printErrorAndExit "Unable to run pod dnstools and check hostname"
    return $?
}
export -f waitPublicIpIsResolvedByDns

function checkCommandAndRetry() {
    local retrySecondInterval=5
    local attempt_counter=0
    local max_attempts=300
    while true; do
        eval "${1}" && return 0 
        [ ${attempt_counter} -eq ${max_attempts} ] && printError "Check $1, error" && return 1
        attempt_counter=$(($attempt_counter+1))
        printDebug "Check : $1, attempt ($attempt_counter/$max_attempts), retry in $retrySecondInterval sec."
        sleep $retrySecondInterval
    done
    return 0
}
export -f checkCommandAndRetry

function installCertManager() {
    printDebug "installCertManager()"
    export TF_VAR_version_chart="v0.12.0"
    installTerraformModule $SCRIPT_DIR/terraform_modules/helm-packages/cert-manager
    printInfo "CertManager Installed"
    return $?

}
export -f installCertManager

function installAndConfigureBackup() {
    printDebug "installAndConfigureBackup()"
    export TF_VAR_client_secret=$ARM_CLIENT_SECRET
    export TF_VAR_subscribtion=$ARM_SUBSCRIPTION_ID
    installTerraformModule $SCRIPT_DIR/terraform_modules/backup/azure
}
export -f installAndConfigureBackup

function installVeleroCli() {
    printDebug "installVeleroCli()"
    curl -L https://github.com/vmware-tanzu/velero/releases/download/v$veleroVersion/velero-v$veleroVersion-linux-amd64.tar.gz > $tmp/velero.tar.gz
    mkdir $tmp/velero
    tar -xvf $tmp/velero.tar.gz -C $tmp/velero
    chmod +x $veleroBin
}
export -f installVeleroCli

function backupConfigure() {
    printDebug "backupConfigure()"

    #[ "$AZURE_USERNAME" == "" ] && printError "AZURE_USERNAME undefined" && showHelpConfigureBackup && exit 1
    #[ "$AZURE_PASSWORD" == "" ] && printError "AZURE_PASSWORD undefined" && showHelpConfigureBackup && exit 1

    [ "$ARM_SUBSCRIPTION_ID" == "" ] && printError "ARM_SUBSCRIPTION_ID undefined" && showHelpDeploy && exit 1
    [ "$ARM_CLIENT_ID" == "" ] && printError "ARM_CLIENT_ID undefined" && showHelpDeploy && exit 1
    [ "$ARM_CLIENT_SECRET" == "" ] && printError "ARM_CLIENT_SECRET undefined" && showHelpDeploy && exit 1
    [ "$ARM_TENANT_ID" == "" ] && printError "ARM_TENANT_ID undefined" && showHelpDeploy && exit 1

    export VELERO_RESOURCE_GROUP_NAME="kathra-backup" # Resource group where storage account will be created and used to store a backups
    export VELERO_STORAGE_ACCOUNT_NAME="kathrabackupaccountname" # Storage account name for Velero backups 
    export VELERO_BLOB_CONTAINER_NAME="kathrabackupcontainer" # Blob container for Velero backups
    export LOCATION="eastus" # Azure region for your resources
    export VELERO_SP_NAME="KathraSpVelero" # A name for Velero Azure AD service principal name
    export AKS_RESOURCE_GROUP="MC_kathra_kathra-k8s_eastus" # Name of the auto-generated resource group that is created when you provision your cluster in Azure
    
    az login 
    az account set --subscription $ARM_SUBSCRIPTION_ID

    # Create and configure storage
    az group create --location $LOCATION --name $VELERO_RESOURCE_GROUP_NAME
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

    $veleroBin version && printInfo "Velero is installed"
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
