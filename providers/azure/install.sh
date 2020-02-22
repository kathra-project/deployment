#/bin/bash
export SCRIPT_DIR=$(realpath $(dirname `which $0`))
declare KUBECONFIG=$SCRIPT_DIR/kube_config
export tmp=/tmp/kathra.azure.wrapper
[ ! -d $tmp ] && mkdir $tmp

cd $SCRIPT_DIR
export debug=1

#kathra.az.boubechtoula.ovh
export domain=""
export azureGroupName="kathra"
export azureLocation="East US"
export terraformVersion="0.12.21"
export traefikChartVersion="1.85.0"
export kubeDbVersion="0.8.0"
export kubernetesVersion="1.15.5"

function showHelp() {
    findInArgs "deploy" $* > /dev/null && showHelpDeploy $* && exit 0
    findInArgs "destroy" $* > /dev/null && showHelpDestroy $* && exit 0 
    printInfo "KATHRA Azure Install Wrapper"
    printInfo ""
    printInfo "Usage: "
    printInfo "deploy : Deploy on Azure"
    printInfo "destroy : Destroy on Azure"
}
export -f showHelp

function showHelpDeploy() {
    printInfo "KATHRA Azure Install Wrapper"
    printInfo ""
    printInfo "Deploy options : "
    printInfo "--domain=<my-domain.xyz>                       :        Base domain"
    printInfo "--azure-group-name=<group-name>                :        Azure Group Name [default: $azureGroupName]"
    printInfo "--azure-location=<location>                    :        Azure Location [default: $azureLocation]"
    printInfo "--azure-subscribtion-id=<ARM_SUBSCRIPTION_ID>  :        Azure ARM_SUBSCRIPTION_ID [default: $ARM_SUBSCRIPTION_ID]"
    printInfo "--azure-client-id=<ARM_CLIENT_ID>              :        Azure ARM_CLIENT_ID [default: $ARM_CLIENT_ID]"
    printInfo "--azure-client-secret=<ARM_CLIENT_SECRET>      :        Azure ARM_CLIENT_SECRET [default: $ARM_CLIENT_SECRET]"
    printInfo "--azure-tenant-id=<ARM_TENANT_ID>              :        Azure ARM_TENANT_ID [default: $ARM_TENANT_ID]"
    printInfo "--kubernetes-version=<version>                 :        Kubernetes Version [default: $kubernetesVersion]"
    printInfo "--verbose                                      :        Enable DEBUG log level"
}
export -f showHelpDeploy

function showHelpDestroy() {
    printInfo "KATHRA Azure Install Wrapper"
    printInfo ""
    printInfo "Destroy options : "
}
export -f showHelpDestroy

function parseArgs() {
    for argument in "$@" 
    do
        local key=${argument%%=*}
        local value=${argument#*=}
        case "$key" in
            --domain)                       domain=$value;;
            --azure-group-name)             azureGroupName=$value;;
            --azure-location)               azureLocation=$value;;
            --azure-subscribtion-id)        ARM_SUBSCRIPTION_ID=$value;;
            --azure-client-id)              ARM_CLIENT_ID=$value;;
            --azure-client-secret)          ARM_CLIENT_SECRET=$value;;
            --azure-tenant-id)              ARM_TENANT_ID=$value;;
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
}

function deploy() {
    printDebug "deploy()"
    [ "$domain" == "" ] && printError "Domain undefined" && showHelpDeploy && exit 1

    sudo apt-get install curl jq unzip -y > /dev/null 2> /dev/null  
    installAzureCli
    installTerraform
    installKubectl

    ## install 
    installKubernetes
    installTraefik
    installKubeDB
    waitPublicIpIsResolvedByDns "$domain" "$INGRESS_PUBLIC_IP"
    installCertManager
    
    return $?
}
export -f deploy

function destroy() {
    printDebug "destroy()"
    sudo apt-get install curl jq unzip -y > /dev/null 2> /dev/null  
    installAzureCli
    uninstallKubernetes
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

function installKubernetes() {
    printDebug "installKubernetes()"
    cd $SCRIPT_DIR/terraform_modules/kubernetes
    export TF_VAR_k8s_client_id="$ARM_CLIENT_ID"
    export TF_VAR_k8s_client_secret="$ARM_CLIENT_SECRET"
    export TF_VAR_kubernetes_version="$kubernetesVersion"
    installTerraformModule $SCRIPT_DIR/terraform_modules/kubernetes
    terraform output kube_config > $KUBECONFIG
    export TF_VAR_kube_config_file="$KUBECONFIG"
    kubectl --kubeconfig=$KUBECONFIG get nodes || printErrorAndExit "Unable to connect Kubernetes"
}
export -f installKubernetes

function uninstallKubernetes() {
    printDebug "uninstallKubernetes()"
    cd $SCRIPT_DIR/terraform_modules/kubernetes
    terraform init
    terraform destroy
    rm $SCRIPT_DIR/terraform_modules/helm-packages/kubedb/terraform.*
    rm $SCRIPT_DIR/terraform_modules/helm-packages/cert-manager/terraform.*
    rm $SCRIPT_DIR/terraform_modules/helm-packages/traefik/terraform.*
}
export -f uninstallKubernetes

function installTerraformModule() {
    printDebug "installTerraformModule($*)"
    local dir=$1
    cd $dir && terraform init && terraform apply -auto-approve 
    [ $? -ne 0 ] && printErrorAndExit "Unable to terraform apply : $dir"
}
export -f installTerraformModule

function installTraefik() {
    printDebug "installTraefik()"
    export TF_VAR_version_chart=$traefikChartVersion
    installTerraformModule $SCRIPT_DIR/terraform_modules/helm-packages/traefik
    
    checkCommandAndRetry "kubectl --kubeconfig=$KUBECONFIG -n traefik get svc traefik -o json | jq -r '.status.loadBalancer.ingress[0].ip' | grep -v null > /dev/null " 
    export INGRESS_PUBLIC_IP=$(kubectl --kubeconfig=$KUBECONFIG -n traefik get svc traefik -o json | jq -r '.status.loadBalancer.ingress[0].ip' | grep -v null)

    printInfo "Public IP Ingress $INGRESS_PUBLIC_IP"
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
    checkCommandAndRetry "kubectl --kubeconfig=$KUBECONFIG run -it --rm --restart=Never --image=infoblox/dnstools:latest dnstools -- '-c' \"host test.$dnsEntry\" | grep \"test.$dnsEntry has address $ipExpected\" > /dev/null" || printErrorAndExit "Unable to run pod dnstools and check hostname"
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
    local clusterIssuerName="letsencrypt-prod"

    echo "apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: $clusterIssuerName
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: contact@$domain
    privateKeySecretRef:
      name: $clusterIssuerName
    solvers:
      - http01:
          ingress:
            class: traefik
  " > /tmp/clusterissuer.yaml

    export TF_VAR_apiserver_ca=$(onessl get kube-ca)
    export TF_VAR_version_chart="v0.12.0"
    export TF_VAR_issuer_name_default=$clusterIssuerName
    export TF_VAR_cluster_issuers_file=/tmp/clusterissuer.yaml

    kubectl --kubeconfig=$KUBECONFIG apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml --namespace traefik
    installTerraformModule $SCRIPT_DIR/terraform_modules/helm-packages/cert-manager
    kubectl --kubeconfig=$KUBECONFIG apply -f /tmp/clusterissuer.yaml --namespace traefik --validate=false --overwrite
    kubectl --kubeconfig=$KUBECONFIG label namespace traefik certmanager.k8s.io/disable-validation=true --overwrite
    printInfo "CertManager Installed"
    return $?

}
export -f installCertManager

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



