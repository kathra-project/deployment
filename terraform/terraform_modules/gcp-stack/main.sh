
#/bin/bash
export SCRIPT_DIR=$(realpath $(dirname `which $0`))
export tmp=/tmp/kathra.gcp.Wrapper
export KUBECONFIG=$tmp/kube_config
[ ! -d $tmp ] && mkdir $tmp

cd $SCRIPT_DIR

export debug=1
export domain=""
export domainLabel=""

export kathraChartsVersion="master"
export kathraImagesTag="stable"

export terraformModules=$SCRIPT_DIR/../terraform_modules
export gcpStackModule=$SCRIPT_DIR

export gcpProjectName="kathra-project"
export gcpServiceAccount="kathra-sa-test"
export gcpCredentials="/$HOME/terraform-gke-keyfile.json"
export gcpRegion="us-central1"
export gcpZone="us-central1-a"

export kubernetesVersion="1.15.10"

export helmVersion=2.14.3
export helmPlateform=linux-amd64
export helmBin=$tmp/helm-local/$helmPlateform/helm

export kubectlBin=$tmp/kubectl

function showHelp() {
    findInArgs "deploy" $* > /dev/null && showHelpDeploy $* && exit 0
    findInArgs "destroy" $* > /dev/null && showHelpDestroy $* && exit 0 
    printInfo "KATHRA GCP Install Wrapper"
    printInfo ""
    printInfo "Usage: "
    printInfo "deploy : Deploy on GCP"
    printInfo "destroy : Destroy on GCP"
}
export -f showHelp

function showHelpDeploy() {
    printInfo "KATHRA GCP Install Wrapper"
    printInfo ""
    printInfo "Deploy options : "
    printInfo "--domain=<my-domain.xyz>                       :        Full base domain"
    printInfo ""
    printInfo "--charts-version=<branch|tag>                  :        Charts version   [default: $kathraChartsVersion]"
    printInfo "--images-version=<tag>                         :        Images tags      [default: $kathraImagesTag]"
    printInfo ""
    printInfo "--gcp-project-name=<group-name>                :        GCP Group Name   [default: $gcpProjectName]"
    printInfo "--gcp-region=<region>                          :        GCP region       [default: $gcpRegion]"
    printInfo "--gcp-zone=<zone>                              :        GCP zone         [default: $gcpZone]"
    printInfo "--gcp-credentials=<file path>                  :        GCP credential   [default: $gcpCredentials]"
    printInfo ""
    printInfo "--verbose                                      :        Enable DEBUG log level"
}
export -f showHelpDeploy

function showHelpDestroy() {
    printInfo "KATHRA GCP Install Wrapper"
    printInfo ""
    printInfo "destroy options : "
    printInfo "--domain=<my-domain.xyz>                       :        Full base domain"
    printInfo "--gcp-credentials=<file path>                  :        GCP credential   [default: $gcpCredentials]"
}
export -f showHelpDestroy

function parseArgs() {
    for argument in "$@" 
    do
        local key=${argument%%=*}
        local value=${argument#*=}
        case "$key" in
            --domain)                       domain=$value;;
            --charts-version)               kathraChartsVersion=$value;;
            --images-tag)                   kathraImagesTag=$value;;

            --gcp-project)                  gcpProjectName=$value;;
            --gcp-region)                   gcpRegion=$value;;
            --gcp-zone)                     gcpZone=$value;;
            --gcp-credentials)              gcpCredentials=$value;;
            
            --verbose)                      debug=1;;
            --help|-h)                      showHelp $*;;
        esac    
    done
}

function main() {
    parseArgs $*    
    [ "$domain" == "" ] && printError "Domain is undefined" && showHelpDeploy && exit 1
    #[ "$gcpCredentials" == "" ] && printError "Define gcp credentials file" && showHelpDeploy && exit 1
    #[ ! -f $gcpCredentials ] && printError "File gcp credentials is not found : $gcpCredentials" && showHelpDeploy && exit 1
    findInArgs "deploy" $* > /dev/null && deploy $* && return 0
    findInArgs "destroy" $* > /dev/null && destroy $* && return 0
    showHelp
}

function checkDependencies() {
    printDebug "checkDependencies()"
    which gcloud > /dev/null || installGoogleCloudSDK
    installKubectl
    installHelm
    which terraform > /dev/null || installTerraform
}

function deploy() {
    printDebug "deploy()"
    checkDependencies
    configureServiceAccount

    initTfVars $gcpStackModule/terraform.tfvars
    cd $gcpStackModule
    
    # Deploy Kubernetes and configure
    terraform init || printErrorAndExit "Terraform : Unable to init"
    terraform apply -auto-approve || printErrorAndExit "Terraform : Unable to apply"

    export KUBECONFIG=$KUBECONFIG
    terraform output kubeconfig_content > $KUBECONFIG  || printErrorAndExit "Terraform : Unable to get kubeconfig_content"
    $kubectlBin get nodes || printErrorAndExit "Unable to connect to Kubernetes server"

    # Install Tiller
    installTiller || printErrorAndExit "Unable to install Tiller"

    # Deploy Kathra
    printInfo "export KUBECONFIG=$KUBECONFIG"
    local scriptInstall=$SCRIPT_DIR/../../../install.sh
    printInfo "Prevent KubeDB issues, restart pods " && $kubectlBin -n kubedb delete pods --all 
    printInfo "$scriptInstall --domain=$domain --chart-version=$kathraChartsVersion --kathra-image-tag=$kathraImagesTag --enable-tls-ingress --verbose"
    $scriptInstall --domain=$domain --chart-version=$kathraChartsVersion --kathra-image-tag=$kathraImagesTag --enable-tls-ingress --verbose
    return $?
}
export -f deploy

###
### Download helm wrapper
###
function installHelm() {
    [ -f $helmBin ] && return
    local uriHelm="https://storage.googleapis.com/kubernetes-helm/helm-v${helmVersion}-${helmPlateform}.tar.gz"
    curl ${uriHelm} > $tmp/helm-local.tar.gz 2> /dev/null
    [ $? -ne 0 ] && printError "Unable to get ${uriHelm}" && exit 1
    [ ! -d  $tmp/helm-local/ ] && mkdir $tmp/helm-local/ 
    tar xvzf $tmp/helm-local.tar.gz -C $tmp/helm-local/ 2>&1 > /dev/null && chmod +x $tmp/helm-local/$helmPlateform/*
    return $?
}
export -f installHelm

function installTiller() {
    printDebug "installTiller()"
    installHelm   || printErrorAndExit "Unable to install Helm"
    $helmBin version && return
    printInfo "Helm 2 install Tiller"
    $kubectlBin --namespace kube-system create sa tiller
    $kubectlBin create    clusterrolebinding tiller \
                    --clusterrole cluster-admin \
                    --serviceaccount=kube-system:tiller
    $helmBin init --service-account tiller --upgrade
    $helmBin version
    while [ $? -ne 0 ]; do printInfo "Check Helm tiller" && $helmBin version; done
    $helmBin version && printInfo "Tiller installed" || return 1
    
}
export -f installTiller

function destroy() {
    checkDependencies
    configureServiceAccount

    initTfVars $gcpStackModule/terraform.tfvars
    cd $gcpStackModule

    terraform init
    terraform destroy
}
export -f destroy

function initTfVars() {
    local file=$1
    [ -f $file ] && rm $file
    echo "project_name = \"$gcpProjectName\"" >> $file
    echo "region = \"$gcpRegion\"" >> $file
    echo "zone = \"$gcpZone\"" >> $file
    echo "domain = \"$domain\"" >> $file
    echo "gcp_crendetials = \"$gcpCredentials\"" >> $file
    echo "k8s_version = \"$kubernetesVersion\"" >> $file
}
export -f initTfVars

function configureServiceAccount() {
    #gcloud init
    [ -f $gcpCredentials ] && return

    # enable services
    gcloud services enable compute.googleapis.com && printInfo "Enable service compute.googleapis.com"                              || printErrorAndExit "Unable to enable service compute.googleapis.com "
    gcloud services enable servicenetworking.googleapis.com && printInfo "Enable service servicenetworking.googleapis.com"          || printErrorAndExit "Unable to enable service servicenetworking.googleapis.com "
    gcloud services enable cloudresourcemanager.googleapis.com && printInfo "Enable service cloudresourcemanager.googleapis.com"    || printErrorAndExit "Unable to enable cloudresourcemanager compute.googleapis.com "
    gcloud services enable container.googleapis.com && printInfo "Enable service container.googleapis.com"                          || printErrorAndExit "Unable to enable service container.googleapis.com "

    # create service acount
    local iamAccount=$gcpServiceAccount@$gcpProjectName.iam.gserviceaccount.com
    gcloud iam service-accounts list --filter email=$iamAccount | grep $iamAccount || gcloud iam service-accounts create $gcpServiceAccount
    gcloud iam service-accounts list --filter email=$iamAccount | grep $iamAccount || printErrorAndExit "Unable to create service account $iamAccount"

    # create key if not exist
    [ ! -f $gcpCredentials ] && gcloud iam service-accounts keys create $gcpCredentials --iam-account=$iamAccount

    # enable service account to use 
    gcloud projects add-iam-policy-binding $gcpProjectName --member serviceAccount:$iamAccount --role roles/container.admin                 > /dev/null || printErrorAndExit "Unable to add role roles/container.admin to $iamAccount"
    gcloud projects add-iam-policy-binding $gcpProjectName --member serviceAccount:$iamAccount --role roles/compute.admin                   > /dev/null || printErrorAndExit "Unable to add role roles/compute.admin to $iamAccount"
    gcloud projects add-iam-policy-binding $gcpProjectName --member serviceAccount:$iamAccount --role roles/iam.serviceAccountUser          > /dev/null || printErrorAndExit "Unable to add role roles/iam.serviceAccountUser to $iamAccount"
    gcloud projects add-iam-policy-binding $gcpProjectName --member serviceAccount:$iamAccount --role roles/resourcemanager.projectIamAdmin > /dev/null || printErrorAndExit "Unable to add role roles/resourcemanager.projectIamAdmin to $iamAccount"

}
export -f configureServiceAccount



function installGoogleCloudSDK() {
    printDebug "installGoogleCloudSDK()"
    echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    sudo apt-get update && sudo apt-get install google-cloud-sdk
}
export -f installGoogleCloudSDK

function installKubectl() {
    printDebug "installKubectl()"
    [ -f $kubectlBin ] && return 0
    sudo curl -L -o $kubectlBin https://storage.googleapis.com/kubernetes-release/release/v$kubernetesVersion/bin/linux/amd64/kubectl 
    sudo chmod +x $kubectlBin
}
export -f installKubectl
 
function installTerraform() {
    printDebug "installTerraform()"
    [ -f $terraformBin ] && return
    which unzip > /dev/null || sudo apt-get install unzip
    [ -f $tmp/terraform.zip ] && rm -f $tmpterraform.zip
    curl https://releases.hashicorp.com/terraform/${terraformVersion}/terraform_${terraformVersion}_linux_amd64.zip > $tmp/terraform.zip
    unzip $tmp/terraform.zip
}
export -f installTerraform

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
