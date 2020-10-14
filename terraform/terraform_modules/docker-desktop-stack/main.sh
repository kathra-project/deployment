
#!/bin/bash
export SCRIPT_DIR=$(dirname $(readlink -f "$0"))
export debug=0
[ "$tmp" == "" ] && export tmp=/tmp/kathra.minikube.wrapper
[ ! -d $tmp ] && mkdir $tmp

. ${SCRIPT_DIR}/../minikube-stack/sh/functions.sh
. ${SCRIPT_DIR}/../common.sh


## Default values
export domain=
export tlsCert=
export tlsKey=
export manualDnsChallenge=0
export automaticDnsChallenge=0
export nodePortHTTP=80
export nodePortHTTPS=443
export kathraImagesTag="stable"

function showHelp() {
    printInfo "Install Kathra on Docker Desktop (Windows)"
    printInfo ""
    printInfo "Usage examples: "
    printInfo "deploy --domain=mydomain.org --acme-dns-provider=ovh --acme-dns-config='{\"OVH_APPLICATION_KEY\": \"app-key\", \"OVH_APPLICATION_SECRET\": \"app-secret\",\"OVH_CONSUMER_KEY\": \"consumer-key\",\"OVH_ENDPOINT\": \"ovh-eu\"}'"
    printInfo "deploy --domain=mydomain.org --tlsCert=my-cert --tlsKey=my-key"
    printInfo ""
    printInfo "Args: "
    printInfo "--domain=<my-domain.xyz>        Base domain"
    printInfo "--images-tag=<tag>              Images tags [default: $kathraImagesTag]"
    printInfo ""
    printInfo ""
    printInfo "Automatic TLS certificate generation from Let's Encrypt with DNS Challenge"
    printInfo "--acme-dns-provider             Provider name"
    printInfo "--acme-dns-config               Provider configuration"
    printInfo ""
    printInfo "Using own certificates"
    printInfo "--tls-cert=<path>               TLS cert file path"
    printInfo "--tls-key=<path>                TLS key file path"
    printInfo ""

    printInfo ""
    printInfo "Optionnals: "
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
            --images-tag)                   kathraImagesTag=$value;;
            --tls-cert)                     tlsCert=$value;;
            --tls-key)                      tlsKey=$value;;
            --acme-dns-provider)            automaticDnsChallenge=1 && acmeDnsProvider="$value";;
            --acme-dns-config)              automaticDnsChallenge=1 && acmeDnsConfig="$value";;
            --verbose)                      debug=1;;
            --help|-h)                      showHelp;;
        esac    
    done
}

function main() {
    printDebug "main()"
    parseArgs "$1" "$2" "$3" "$4" "$5" "$5" "$6" "$7"

    ## check OS
    [ "$OS" == "Windows_NT" ] || printErrorAndExit "Only for Windows OS"
    [ "$minikubeVmDriver" == "none" ] && export sudo="sudo"
    findInArgs "deploy"  $* > /dev/null         && deploy $*          && return 0
    findInArgs "destroy" $* > /dev/null         && destroy $*         && return 0
    showHelp
}

function deploy() {
    printDebug "deploy()"
    [ "$OS" == "Windows_NT" ]                                                   || printErrorAndExit "Only for Windows_NT"
    net session  > /dev/null 2> /dev/null                                       || printErrorAndExit "Please, start your console as admin"
    which docker > /dev/null                                                    || printErrorAndExit "Docker not installed"
    export START_KATHRA_INSTALL=`date +%s`
    checkDependencies
    [ "$domain" == "" ]           && printErrorAndExit "Domain is not specifed" || printDebug "domain=$domain"

    kubectl get nodes                                                           || printErrorAndExit "Unable to connect with kubectl"
    checkHardwareResources                                                      || printErrorAndExit "Not enought resources (cpu or memory)"
    installIngressController                                                    || printErrorAndExit "Unable to configure Ingress Controller"

    coreDnsAddRecords $domain  "$(getLocalIp)"                                  || printErrorAndExit "Unable to add dns entry into coredns"
    getKubeConfig > $tmp/kathra_minikube_kubeconfig                             || printErrorAndExit "Unable to get kubeconfig"
    
    initTfVars $SCRIPT_DIR/terraform.tfvars
    echo "storage_class_default = \"docker.io/hostpath\"" >> $SCRIPT_DIR/terraform.tfvars

    local subdomains=( "keycloak" "sonarqube" "jenkins" "gitlab" "harbor" "nexus" "appmanager" "dashboard" "resourcemanager" "pipelinemanager" "sourcemanager" "codegen-helm" "codegen-swagger" "binaryrepositorymanager-harbor" "binaryrepositorymanager-nexus" )
    for subdomain in ${subdomains[@]}; do addEntryHostFile "$subdomain.$domain" "$(getLocalIp)"; done;
    #echo ${subdomains[@]} | xargs -I % bash -c "addEntryHostFile '%.${domain}' '$(getLocalIp)'"
    
    # Copy configuration from MinikubeStack
    cp -R ${SCRIPT_DIR}/../minikube-stack/namespace_with_tls .
    cp ${SCRIPT_DIR}/../minikube-stack/main.tf main.tf
    cd ${SCRIPT_DIR}

    # Apply configuration
    terraformInitAndApply

    # Post install
    postInstall

    return $?
}
export -f deploy

function installIngressController() {
    if [ "$(helm ls -o json | jq ".[] | select(.name==\"nginx\") | ({name: .name}) | length")" != "1" ]
    then
        printInfo "Install Nginx ingress controller"
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
        helm repo update

        cat <<EOF > $tmp/installIngressController.values.yaml
controller:
  config:
    proxy-buffer-size: "256k"
    proxy-buffering: "on"
EOF

        helm install -f $tmp/installIngressController.values.yaml nginx ingress-nginx/ingress-nginx 
        checkCommandAndRetry "curl -v localhost 2>&1 | grep \"nginx\" > /dev/null"
    else
        [ "$(helm ls -o json | jq ".[] | select(.name==\"nginx\") | select(.status==\"deployed\") | ({name: .name}) | length")" != "1" ] && printErrorAndExit "Nginx installation have failed, please remove it ! (helm delete nginx)"
        printInfo "Nginx Ingress controller already installed"
    fi
    local ip=$(getLocalIp)
    [ "$ip" == "" ] && printErrorAndExit "Unable to find local IP for ingress"
    printInfo "Ingress exposed on IP : $ip"
}

function destroy() {
    printDebug "destroy()"
    checkDependencies
    cd $SCRIPT_DIR
    terraform state rm $(terraform state list | grep -v acme | grep -v private | tr '\n' ' ')
    return 0
}
export -f destroy

function addEntryHostFile() {
    local domain=$1
    local ip=$2
    local hostsFile=$WINDIR/system32/drivers/etc/host
    printDebug "addEntryHostFile(domain: $domain, ip: $ip)"
    grep -v " $domain$" < $hostsFile > $tmp/addEntryHostFile
    
    cp $tmp/addEntryHostFile $hostsFile
    [ $? -ne 0 ] && printErrorAndExit "Error : Unable to modify host file, please start GitBash with admin rights"
    echo "$ip $domain" | tee -a $hostsFile
}
export -f addEntryHostFile

function getLocalIp() {
    printDebug "getLocalIp"

    powershell.exe -Command "Get-NetAdapter -Physical | ConvertTo-Json" >  $tmp/getLocalIp.physicalsInterfaces
    powershell.exe -Command "Get-NetIPAddress -AddressFamily IPv4  | ConvertTo-Json" >  $tmp/getLocalIp.ipAdresses

    local ifIndex=$(jq '.ifIndex' < $tmp/getLocalIp.physicalsInterfaces)
    local ipAddress=$(jq -r ".[] | select( .ifIndex == ${ifIndex} ) | .IPAddress" < $tmp/getLocalIp.ipAdresses)
    curl -v $ipAddress 2>&1 | grep "nginx" > /dev/null && echo $ipAddress
    return $?
}
export -f getLocalIp

main "$1" "$2" "$3" "$4" "$5" "$5" "$6"