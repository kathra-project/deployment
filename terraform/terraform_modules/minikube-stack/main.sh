
#!/bin/bash
export SCRIPT_DIR=$(realpath $(dirname `which $0`))
export debug=0
[ "$tmp" == "" ] && export tmp=/tmp/kathra.minikube.wrapper
[ ! -d $tmp ] && mkdir $tmp

. ${SCRIPT_DIR}/sh/functions.sh






## Default values
export domain=
export tlsCert=
export tlsKey=
export manualDnsChallenge=0
export automaticDnsChallenge=0
export hostNetworkDevice=$(ip -4 addr show | grep '^[0-9]*:' | awk '{print $2;}' | sed 's/\://g' | grep -v 'lo' | head -n 1)
export nodePortHTTP=80
export nodePortHTTPS=443
export minikubeCpus=8
export minikubeMemory=20000
export minikubeDiskSize="50000mb"
export minikubeVersion="1.3.1"
export minikubeVmDriver="virtualbox"
export kubernetesVersion="1.15.1"
export helmVersion="2.14.3"
export kubeDbVersion="0.8.0"
export traefikChartVersion="1.78.2"
export sudo=""




function showHelp() {
    printInfo "KATHRA + Minikube Install Wrapper"
    printInfo ""
    printInfo "Usage examples: "
    printInfo "deploy --domain=mydomain.org --acme-dns-provider=ovh --acme-dns-config='{\"OVH_APPLICATION_KEY\": \"app-key\", \"OVH_APPLICATION_SECRET\": \"app-secret\",\"OVH_CONSUMER_KEY\": \"consumer-key\",\"OVH_ENDPOINT\": \"ovh-eu\"}'"
    printInfo "deploy --domain=mydomain.org --manual-acme"
    printInfo "deploy --domain=mydomain.org --tlsCert=my-cert --tlsKey=my-key"
    printInfo ""
    printInfo "Args: "
    printInfo "--domain=<my-domain.xyz>        Base domain"
    printInfo ""
    printInfo "Automatic TLS certificate generation from Let's Encrypt with DNS Challenge"
    printInfo "--acme-dns-provider             Provider name"
    printInfo "--acme-dns-config               Provider configuration"
    printInfo ""
    printInfo "Using own certificates"
    printInfo "--tls-cert=<path>                TLS cert file path"
    printInfo "--tls-key=<path>                 TLS key file path"
    printInfo ""
    printInfo "Manualy TLS certificate generation from Let's Encrypt with DNS Challenge"
    printInfo "--manual-acme          "

    printInfo ""
    printInfo "Optionnals: "
    printInfo "--network-device                Network device to expose [default: $hostNetworkDevice]"
    printInfo "--cpus                          Number of cpu [default: $minikubeCpus]"
    printInfo "--memory                        Memory size [default: $minikubeMemory]"
    printInfo "--disk-size                     Disk size [default: $minikubeDiskSize]"
    printInfo "--minikube-version              Minikube version [default: $minikubeVersion]"
    printInfo "--vm-driver                     Minikube VM driver [default: $minikubeVmDriver]"
    printInfo "--kubernetes-version            Kubernetes version [default: $kubernetesVersion]"
    printInfo "--verbose                       Enable DEBUG log level"
    exit 0
}

function parseArgs() {
    for argument in "$@" 
    do
        local key=${argument%%=*}
        local value=${argument#*=}
        case "$key" in
            --domain)                       domain=$value;;
            --tls-cert)                      tlsCert=$value;;
            --tls-key)                       tlsKey=$value;;
            --manual-acme)                  manualDnsChallenge=1;;
            --acme-dns-provider)            automaticDnsChallenge=1 && acmeDnsProvider="$value";;
            --acme-dns-config)              automaticDnsChallenge=1 && acmeDnsConfig="$value";;
            --network-device)               hostNetworkDevice=$value;;
            --cpus)                         minikubeCpus=$value;;
            --memory)                       minikubeMemory=$value;;
            --disk-size)                    minikubeDiskSize=$value;;
            --minikube-version)             minikubeVersion=$value;;
            --vm-driver)                    minikubeVmDriver=$value;;
            --kubernetes-version)           kubernetesVersion=$value;;
            --verbose)                      debug=1;;
            --help|-h)                      showHelp;;
        esac    
    done
}

function main() {
    printDebug "main()"
    parseArgs "$1" "$2" "$3" "$4" "$5" "$5" "$6"

    ## check OS
    lsb_release -a 2> /dev/null | grep -E "Ubuntu|Debian" > /dev/null || printErrorAndExit "Only for Ubuntu or Debian Distrib"
    [ "$minikubeVmDriver" == "none" ] && export sudo="sudo"
    

    findInArgs "deploy"  $* > /dev/null         && deploy $*          && return 0
    findInArgs "destroy" $* > /dev/null         && destroy $*         && return 0
    findInArgs "backup-install" $* > /dev/null  && backupConfigure $* && return 0
    showHelp
}

function initTfVars() {
    local file=$1
    [ -f $file ] && rm $file
    echo "domain = \"$domain\"" >> $file
    echo "kube_config = $(getKubeConfig)" >> $file
    [ $manualDnsChallenge -eq 1 ]    && echo "tls_cert_filepath = \"$tmp/tls.cert\""            >> $file
    [ $manualDnsChallenge -eq 1 ]    && echo "tls_key_filepath = \"$tmp/tls.key\""              >> $file
    [ $automaticDnsChallenge -eq 1 ] && echo "acme_provider = \"$acmeDnsProvider\""         >> $file
    [ $automaticDnsChallenge -eq 1 ] && echo "acme_config = ${acmeDnsConfig}"               >> $file
}

function deploy() {
    printDebug "deploy()"
    checkDependencies
    [ "$domain" == "" ]           && printErrorAndExit "Domain is not specifed"                    || printDebug "domain=$domain"
    [ $manualDnsChallenge -eq 1 ] && generateCertsDnsChallenge $domain $tmp/tls.cert $tmp/tls.key
    startMinikube                                                               || printErrorAndExit "Unable to install minikube"
    kubectl get nodes                                                           || printErrorAndExit "Unable to connect to minikube with kubectl"
    coreDnsAddRecords $domain  "$(minikube ip)"                                 || printErrorAndExit "Unable to add dns entry into coredns"
    getKubeConfig > $tmp/kathra_minikube_kubeconfig                             || printErrorAndExit "Unable to get kubeconfig"
    
    initTfVars $SCRIPT_DIR/terraform.tfvars
    
    local hostIP=$(ip -4 addr show $hostNetworkDevice | grep -oP '(?<=inet\s)[\da-f.]+')
    local subdomains=( "keycloak" "jenkins" "gitlab" "harbor" "nexus" "appmanager" "dashboard" "resourcemanager" "pipelinemanager" "sourcemanager" )
    for subdomain in ${subdomains[@]}; do addEntryHostFile "$subdomain.$domain" "$(minikube ip)"; done;
    
    # Deploy Kubernetes and configure
    cd $SCRIPT_DIR
    terraform init                      || printErrorAndExit "Unable to init terraform"
    terraform apply -auto-approve       || printErrorAndExit "Unable to apply terraform"

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

function checkDependencies() {
    ! dpkg -s socat > /dev/null     && sudo apt-get install -y socat
    ! dpkg -s jq > /dev/null        && sudo apt-get install -y jq
    ! dpkg -s curl > /dev/null      && sudo apt-get install -y curl
    
    installTerraform
    
    installTerraformPlugin "keycloak" "1.17.1" "https://github.com/mrparkers/terraform-provider-keycloak.git" "1.17.1"   || printErrorAndExit "Unable to install keycloak terraform plugin"
    installTerraformPlugin "kubectl"  "1.3.5"  "https://github.com/gavinbunney/terraform-provider-kubectl"    "v1.3.5"   || printErrorAndExit "Unable to install keycloak terraform plugin"
    installTerraformPlugin "nexus"    "1.6.0"  "https://github.com/datadrivers/terraform-provider-nexus"      "v1.6.0"   || printErrorAndExit "Unable to install keycloak terraform plugin"

}

main "$1" "$2" "$3" "$4" "$5" "$5" "$6"