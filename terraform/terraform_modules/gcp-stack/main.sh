
#/bin/bash
export SCRIPT_DIR=$(realpath $(dirname `which $0`))
export tmp=/tmp/kathra.azure.Wrapper
export KUBECONFIG=$tmp/kube_config
[ ! -d $tmp ] && mkdir $tmp

. $SCRIPT_DIR/../common.sh

cd $SCRIPT_DIR

export debug=1
export domain=""

export kathraImagesTag="stable"

export terraformModules=$SCRIPT_DIR/../terraform_modules
export gcpStackModule=$SCRIPT_DIR

export gcpProjectName="kathra-project"
export gcpServiceAccount="kathra-sa"
export gcpCredentials="/$HOME/terraform-gke-keyfile.json"
export gcpRegion="us-central1"
export gcpZone="us-central1-a"

function showHelp() {
    findInArgs "deploy" $* > /dev/null && showHelpDeploy $* && exit 0
    findInArgs "destroy" $* > /dev/null && showHelpDestroy $* && exit 0 
    printInfo "KATHRA GCP Install Wrapper"
    printInfo ""
    printInfo "Usage: "
    printInfo "deploy : Deploy on GCP"
    printInfo "destroy : Destroy on GCP"
    exit 0
}
export -f showHelp

function showHelpDeploy() {
    printInfo "KATHRA GCP Install Wrapper"
    printInfo ""
    printInfo "Deploy options : "
    printInfo "--domain=<my-domain.xyz>                       :        Full base domain"
    printInfo ""
    printInfo "--images-version=<tag>                         :        Images tags         [default: $kathraImagesTag]"
    printInfo ""
    printInfo "--gcp-project-name=<group-name>                :        GCP Project name    [default: $gcpProjectName]"
    printInfo "--gcp-service-account=<service-acount>         :        GCP Service account [default: $gcpServiceAccount]"
    printInfo "--gcp-region=<region>                          :        GCP region          [default: $gcpRegion]"
    printInfo "--gcp-zone=<zone>                              :        GCP zone            [default: $gcpZone]"
    printInfo "--gcp-credentials=<file path>                  :        GCP credential      [default: $gcpCredentials]"
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
            --images-tag)                   kathraImagesTag=$value;;

            --gcp-service-account)          gcpServiceAccount=$value;;
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
    export START_KATHRA_INSTALL=`date +%s`

    which gcloud > /dev/null        || installGoogleCloudSDK
     
    [ "$domain" == "" ] && printError "Domain is undefined" && showHelpDeploy && exit 1
    #[ "$gcpCredentials" == "" ] && printError "Define gcp credentials file" && showHelpDeploy && exit 1
    #[ ! -f $gcpCredentials ] && printError "File gcp credentials is not found : $gcpCredentials" && showHelpDeploy && exit 1
    findInArgs "deploy" $* > /dev/null && deploy $* && return 0
    findInArgs "destroy" $* > /dev/null && destroy $* && return 0
    showHelp
}

function deploy() {
    printDebug "deploy()"
    checkDependencies
    configureServiceAccount

    initTfVars $gcpStackModule/terraform.tfvars
    cd $gcpStackModule
    
    
    # Deploy Stack
    terraform init                      || printErrorAndExit "Unable to init terraform"

    local retrySecondInterval=10
    local attempt_counter=0
    local max_attempts=5
    while true; do
        terraform apply -auto-approve && break
        printError "Terraform : Unable to apply, somes resources may be not ready, try again.. attempt ($attempt_counter/$max_attempts) "
        [ ${attempt_counter} -eq ${max_attempts} ] && printError "Check $1, error" && return 1
        attempt_counter=$(($attempt_counter+1))
        sleep $retrySecondInterval
    done

    # Post install
    postInstall
    preConfigureKubeConfig
}
export -f deploy

function destroy() {
    checkDependencies
    configureServiceAccount

    initTfVars $gcpStackModule/terraform.tfvars
    cd $gcpStackModule

    terraform init
    terraform state rm $(terraform state list | grep -E "module.factory|kubernetes_addons|helm_release.kathra|kubernetes_namespace")
    terraform destroy --target=module.kubernetes.google_container_cluster.kubernetes
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
    echo "kathra_version = \"$kathraImagesTag\"" >> $file
    
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

main $*

exit $?
