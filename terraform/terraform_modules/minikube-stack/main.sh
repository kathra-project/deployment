#!/bin/bash
export SCRIPT_DIR=$(realpath $(dirname `which $0`))
export debug=0
[ "$tmp" == "" ] && export tmp=/tmp/kathra.minikube.wrapper
[ ! -d $tmp ] && mkdir $tmp

. ${SCRIPT_DIR}/sh/functions.sh
. ${SCRIPT_DIR}/../common.sh


## Default values
export domain=
export tlsCert=
export tlsKey=
export manualDnsChallenge=0
export automaticDnsChallenge=0
export nodePortHTTP=80
export nodePortHTTPS=443
export minikubeCpus=10
export minikubeMemory=20000
export minikubeDiskSize="50000mb"
export minikubeVersion="1.3.1"
export minikubeVmDriver="none"
export kubernetesVersion="1.15.1"
export sudo=""
export kathraImagesTag="stable"




function showHelp() {
    findInArgs "deploy" $* > /dev/null && showHelpDeploy $* && exit 0
    findInArgs "destroy" $* > /dev/null && showHelpDestroy $* && exit 0 
    printInfo "KATHRA Minikube Install Wrapper"
    printInfo ""
    printInfo "Usage: "
    printInfo "deploy : Deploy on Minikube"
    printInfo "destroy : Destroy on Minikube"
    exit 0
}
export -f showHelp


function showHelpDeploy() {
    printInfo "KATHRA + Minikube Install Wrapper"
    printInfo ""
    printInfo "Usage examples: "
    printInfo "deploy --domain=mydomain.org --acme-dns-provider=ovh --acme-dns-config='{\"OVH_APPLICATION_KEY\": \"app-key\", \"OVH_APPLICATION_SECRET\": \"app-secret\",\"OVH_CONSUMER_KEY\": \"consumer-key\",\"OVH_ENDPOINT\": \"ovh-eu\"}'"
    printInfo "deploy --domain=mydomain.org --manual-acme"
    printInfo "deploy --domain=mydomain.org --tlsCert=my-cert --tlsKey=my-key"
    printInfo ""
    printInfo "Args: "
    printInfo "--domain=<my-domain.xyz>                       : Base domain"
    printInfo ""
    printInfo "--images-tag=<tag>                             : Images tags [default: $kathraImagesTag]"
    printInfo ""
    printInfo "Automatic TLS certificate generation from Let's Encrypt with DNS Challenge"
    printInfo "--acme-dns-provider                            : Provider name"
    printInfo "--acme-dns-config                              : Provider configuration"
    printInfo ""
    printInfo "Using own certificates"
    printInfo "--tls-cert=<path>                              : TLS cert file path"
    printInfo "--tls-key=<path>                               : TLS key file path"
    printInfo ""
    printInfo "Manualy TLS certificate generation from Let's Encrypt with DNS Challenge"
    printInfo "--manual-acme          "

    printInfo ""
    printInfo "Optionnals: "
    printInfo "--cpus                                         : Number of cpu (with virtual machine) [default: $minikubeCpus]"
    printInfo "--memory                                       : Memory size (with virtual machine) [default: $minikubeMemory]"
    printInfo "--disk-size                                    : Disk size (with virtual machine) [default: $minikubeDiskSize]"
    printInfo "--minikube-version                             : Minikube version [default: $minikubeVersion]"
    printInfo "--vm-driver                                    : Minikube VM driver [default: $minikubeVmDriver]"
    printInfo "--kubernetes-version                           : Kubernetes version [default: $kubernetesVersion]"
    printInfo "--verbose                                      : Enable DEBUG log level"

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
            --images-tag)                   kathraImagesTag=$value;;
            --tls-cert)                      tlsCert=$value;;
            --tls-key)                       tlsKey=$value;;
            --manual-acme)                  manualDnsChallenge=1;;
            --acme-dns-provider)            automaticDnsChallenge=1 && acmeDnsProvider="$value";;
            --acme-dns-config)              automaticDnsChallenge=1 && acmeDnsConfig="$value";;
            --cpus)                         minikubeCpus=$value;;
            --memory)                       minikubeMemory=$value;;
            --disk-size)                    minikubeDiskSize=$value;;
            --minikube-version)             minikubeVersion=$value;;
            --vm-driver)                    minikubeVmDriver=$value;;
            --kubernetes-version)           kubernetesVersion=$value;;
            --verbose)                      debug=1;;
            --help|-h)                      showHelp $*;;
        esac    
    done
}

function main() {
    printDebug "main()"
    parseArgs "$1" "$2" "$3" "$4" "$5" "$5" "$6" "$7"

    ## check OS
    lsb_release -a 2> /dev/null | grep -E "Ubuntu|Debian" > /dev/null || printErrorAndExit "Only for Ubuntu or Debian Distrib"
    [ "$minikubeVmDriver" == "none" ] && export sudo="sudo"
    
    findInArgs "deploy"  $* > /dev/null         && deploy $*          && return 0
    findInArgs "destroy" $* > /dev/null         && destroy $*         && return 0
    findInArgs "backup-install" $* > /dev/null  && backupConfigure $* && return 0
    showHelp
}

function deploy() {
    printDebug "deploy()"
    export START_KATHRA_INSTALL=`date +%s`
    checkDependencies
    [ "$domain" == "" ]           && printErrorAndExit "Domain is not specifed"                    || printDebug "domain=$domain"
    [ $manualDnsChallenge -eq 1 ] && generateCertsDnsChallenge $domain $tmp/tls.cert $tmp/tls.key
    startMinikube                                                               || printErrorAndExit "Unable to install minikube"
    prePullImages
    kubectl get nodes                                                           || printErrorAndExit "Unable to connect to minikube with kubectl"
    checkHardwareResources                                                      || printErrorAndExit "Not enought resources (cpu or memory)"
    coreDnsAddRecords $domain  "$(minikube ip)"                                 || printErrorAndExit "Unable to add dns entry into coredns"
    getKubeConfig > $tmp/kathra_minikube_kubeconfig                             || printErrorAndExit "Unable to get kubeconfig"
    
    initTfVars $SCRIPT_DIR/terraform.tfvars
    local subdomains=( "keycloak" "sonarqube" "jenkins" "gitlab" "harbor" "nexus" "appmanager" "dashboard" "resourcemanager" "pipelinemanager" "sourcemanager" "codegen-helm" "codegen-swagger" "binaryrepositorymanager-harbor" "binaryrepositorymanager-nexus" )
    for subdomain in ${subdomains[@]}; do addEntryHostFile "$subdomain.$domain" "$(minikube ip)"; done;
    
    # Deploy Stack
    cd $SCRIPT_DIR
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

    return $?
}
export -f deploy

function destroy() {
    printDebug "destroy()"
    checkDependencies
    minikube delete
    cd $SCRIPT_DIR
    rm terraform.tfstate*
    return 0
}
export -f destroy

main "$1" "$2" "$3" "$4" "$5" "$5" "$6"