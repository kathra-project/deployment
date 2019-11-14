#!/bin/bash
########################################################################
# KATHRA + Minikube Install Wrapper
#
# @author Julien Boubechtoula
########################################################################
export SCRIPT_DIR=$(realpath $(dirname `which $0`))
export debug=0
export tmp=/tmp/kathra.minikube.wrapper
[ ! -d $tmp ] && mkdir $tmp

## Default values
export domain=
export tlsCert=
export tlsKey=
export generateCertsDnsChallenge=0
export hostNetworkDevice=$(ip -4 addr show | grep '^[0-9]*:' | awk '{print $2;}' | sed 's/\://g' | grep -v 'lo' | head -n 1)
export nodePortHTTP=30080
export nodePortHTTPS=30443
export minikubeCpus=6
export minikubeMemory=16384
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
    printInfo "Usage: "
    printInfo "--domain=<my-domain.xyz>:        Base domain"
    printInfo "--tlsCert=<path>:                Tls cert file path"
    printInfo "--tlsKey=<path>:                 Tls key file path"
    printInfo "--generateCertsDnsChallenge:     Generate TLS certificate from Let's Encrypt with DNS Challenge"
    printInfo "--network-device:                Network device to expose [default: $hostNetworkDevice]"
    printInfo "--cpus:                          Number of cpu [default: $minikubeCpus]"
    printInfo "--memory:                        Memory size [default: $minikubeMemory]"
    printInfo "--disk-size:                     Disk size [default: $minikubeDiskSize]"
    printInfo "--minikube-version:              Minikube version [default: $minikubeVersion]"
    printInfo "--vm-driver:                     Minikube VM driver [default: $minikubeVmDriver]"
    printInfo "--kubernetes-version:            Kubernetes version [default: $kubernetesVersion]"
    printInfo "--helm-version:                  Helm version [default: $helmVersion]"
    printInfo "--verbose:                       Enable DEBUG log level"
    exit 0
}

function parseArgs() {
    for argument in "$@" 
    do
        local key=${argument%%=*}
        local value=${argument#*=}
        case "$key" in
            --domain)                       domain=$value;;
            --tlsCert)                      tlsCert=$value;;
            --tlsKey)                       tlsKey=$value;;
            --generateCertsDnsChallenge)    generateCertsDnsChallenge=1;;
            --network-device)               hostNetworkDevice=$value;;
            --cpus)                         minikubeCpus=$value;;
            --memory)                       minikubeMemory=$value;;
            --disk-size)                    minikubeDiskSize=$value;;
            --minikube-version)             minikubeVersion=$value;;
            --vm-driver)                    minikubeVmDriver=$value;;
            --kubernetes-version)           kubernetesVersion=$value;;
            --helm-version)                 helmVersion=$value;;
            --verbose)                      debug=1;;
            --help|-h)                      showHelp;;
        esac    
    done
}

###
### Main program
###     * Parse arguments provided
###     * Generate Certificate [if asked]
###     * Install [or start] minikube
###     * Configure CoreDNS : add A record (domain and subdomains to target host machine)
###     * Install Helm's Tiller [if not exists]
###     * Install KubeDB [if not exists]
###     * Install Traefik [if not exists]
###     * Configure Traefik default certificate with generated certificated [ or certificate provided ]
###     * Forward TCP 80,443 from host machine to specific Minikube's nodePorts 
###
function main() {
    printDebug "main()"
    parseArgs $*

    [ "$minikubeVmDriver" == "none" ] && export sudo="sudo"
    
    sudo apt-get update > /dev/null 2> /dev/null                                                                        || printErrorAndExit "Unable to apt-get update" 
    sudo apt-get install curl jq -y > /dev/null 2> /dev/null                                                            || printErrorAndExit "Unable to apt-get install 'curl, jq'" 
    [ "$domain" == "" ] && printErrorAndExit "Domain is not specifed"                                                   || printDebug "domain=$domain"
    [ $generateCertsDnsChallenge -eq 1 ] && generateCertsDnsChallenge $domain
    sudo ls -l $tlsCert > /dev/null  && printDebug "tlsCert=$tlsCert"                                                   || printErrorAndExit "$tlsCert not found" 
    sudo ls -l $tlsKey > /dev/null   && printDebug "tlsKey=$tlsKey"                                                     || printErrorAndExit "$tlsKey not found"

    ip -4 addr show $hostNetworkDevice > /dev/null 2> /dev/null && printDebug "hostNetworkDevice=$hostNetworkDevice"    || printErrorAndExit "Network device $hostNetworkDevice not found"

    printDebug "hostNetworkDevice=$hostNetworkDevice"
    printDebug "minikubeCpus=$minikubeCpus"
    printDebug "minikubeMemory=$minikubeMemory"
    printDebug "minikubeDiskSize=$minikubeDiskSize"

    local traefikDashboardHostName=traefik.$domain
    local hostIP=$(ip -4 addr show $hostNetworkDevice | grep -oP '(?<=inet\s)[\da-f.]+')

    startMinikube

    $sudo minikube ip 2> /dev/null > /dev/null || printErrorAndExit "Unable to get minikube IP"
    local minikubeIp=$($sudo minikube ip)
    printInfo "Minikube is started and has ip $minikubeIp"
    
    kubectl version 2> /dev/null > /dev/null || printErrorAndExit "Unable to connect to minikube with kubectl"
    printInfo "kubectl is connected"
    
    # Configure CoreDNS
    coreDnsAddRecords $domain  $hostIP
    
    # install Tiller
    installTiller

    # install KubeDB with Helm
    installKubeDB

    ## Target Traefik's dashboard to minikube
    addEntryHostFile "${traefikDashboardHostName}" "$minikubeIp"

    ## Install traefik with Helm
    installTraefik "${traefikDashboardHostName}" "${nodePortHTTP}" "${nodePortHTTPS}"
    configureDefaultCertificate "$tlsCert" "$tlsKey"

    ## Target Traefik's dashboard to host's IP
    addEntryHostFile "${traefikDashboardHostName}" "$hostIP"
    
    ## Enable forwarding host's IP to minikube IP
    forwardPort "80" "${minikubeIp}" "${nodePortHTTP}"
    forwardPort "443" "${minikubeIp}" "${nodePortHTTPS}"
    
    checkCommandAndRetry "curl --fail http://${traefikDashboardHostName} > /dev/null 2> /dev/null"  || printErrorAndExit "Unable to get Traefik's dashboard with cmd : curl http://${traefikDashboardHostName} "
    checkCommandAndRetry "curl --fail https://${traefikDashboardHostName} > /dev/null 2> /dev/null" || printErrorAndExit "Unable to get Traefik's dashboard with cmd : curl https://${traefikDashboardHostName} "

    printInfo "Your host redirect HTTP and HTTPS to Minikube"

    ## Add static host in /etc/hosts (we can use dnsmask or local bind may be ? )
    local subdomains=( "keycloak" "jenkins" "gitlab" "harbor" "nexus" "appmanager" "dashboard" "resourcemanager" "pipelinemanager" "sourcemanager" )
    for subdomain in ${subdomains[@]}; do addEntryHostFile "$subdomain.$domain" "$hostIP"; done;

    printInfo "Minikube is ready for KATHRA installation"
    printInfo "To install KATHRA, execute : ./install.sh --domain=$domain"
    printInfo "For more options : ./install.sh --help"
    return 0
}

function startMinikube() {
    printDebug "startMinikube(minikubeCpus: $minikubeCpus, minikubeMemory: $minikubeMemory, minikubeDiskSize: $minikubeDiskSize)"
    downloadMinikube
    downloadKubectl
    [ $(minikube status | grep -e "host: Running\|kubelet: Running\|apiserver: Running\|kubectl: Correctly Configured" | wc -l) -eq 4 ] && printInfo "Minikube already started" && return 0
    if [ $minikubeVmDriver == "none" ]
    then
        $sudo minikube start --vm-driver="none" --kubernetes-version v$kubernetesVersion || printErrorAndExit "Unable to install minikube"
    else
        minikube start --vm-driver=$minikubeVmDriver --cpus $minikubeCpus --memory $minikubeMemory --disk-size $minikubeDiskSize --kubernetes-version v$kubernetesVersion || printErrorAndExit "Unable to install minikube"
    fi
    printInfo "Minikubed started"
    return 0
}
export -f startMinikube

function checkCommandAndRetry() {
    local retrySecondInterval=5
    local attempt_counter=0
    local max_attempts=100
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

function installKubeDB() {
    printDebug "installKubeDB()"
    local nameRelease=kubedb-operator
    [ ! "$(helm list --output json | jq -r ".Releases[] | select(.Name==\"$nameRelease\")")" == "" ] && printDebug "KubeDB already installed" && return 0

    curl -fsSL -o onessl https://github.com/kubepack/onessl/releases/download/0.3.0/onessl-linux-amd64 && chmod +x onessl && sudo mv onessl /usr/local/bin/
    helm repo add appscode https://charts.appscode.com/stable/ || printErrorAndExit "Unable add helm repo"
    helm repo update || printErrorAndExit "Unable update helm repo"

    helm install appscode/kubedb --name $nameRelease --version $kubeDbVersion --set apiserver.ca="$(onessl get kube-ca)" --set apiserver.enableValidatingWebhook=true --set apiserver.enableMutatingWebhook=true || printErrorAndExit "Unable install kubedb"
    printInfo "KubeDB Installed"
    return 0
}
export -f installKubeDB

function forwardPort() {
    local portLocal=$1
    local hostDist=$2
    local portDist=$3
    printDebug "forwardPort(portLocal: $portLocal, hostDist: $hostDist, portDist: $portDist)"
    sudo apt-get install -y socat > /dev/null 2> /dev/null
    ps a | grep "socat tcp-l:$portLocal," | grep -v grep | awk '{print $1}' | xargs sudo kill -9 > /dev/null 2> /dev/null
    nohup sudo socat tcp-l:$portLocal,fork,reuseaddr tcp:$hostDist:$portDist > /dev/null 2>&1 </dev/null &
    printInfo "localhost listen on port $portLocal and redirect to $hostDist:$portDist"
    return $?
}
export -f forwardPort

function addEntryHostFile() {
    local domain=$1
    local ip=$2
    printDebug "addEntryHostFile(domain: $domain, ip: $ip)"
    sudo grep -v " $domain$" < /etc/hosts > $tmp/addEntryHostFile && sudo cp $tmp/addEntryHostFile /etc/hosts
    echo "$ip $domain" | sudo tee -a /etc/hosts
}
export -f addEntryHostFile

function downloadMinikube() {
    printDebug "downloadMinikube()"
    [ "${minikubeVmDriver}" == "virtualbox" ] && sudo apt-get install -y virtualbox
    [ "${minikubeVmDriver}" == "none" ] && sudo apt-get install -y nfs-common
    which minikube > /dev/null 2> /dev/null && return 0
    sudo curl -L -o $tmp/minikube https://storage.googleapis.com/minikube/releases/v$minikubeVersion/minikube-linux-amd64
    sudo chmod +x $tmp/minikube
    sudo mv $tmp/minikube /usr/local/bin/minikube
}
export -f downloadMinikube

function downloadKubectl() {
    printDebug "downloadKubectl()"
    sudo apt-get install -y virtualbox
    which kubectl > /dev/null 2> /dev/null && return 0
    sudo curl -L -o $tmp/kubectl https://storage.googleapis.com/kubernetes-release/release/v$kubernetesVersion/bin/linux/amd64/kubectl 
    sudo chmod +x $tmp/kubectl 
    sudo mv $tmp/kubectl /usr/local/bin/kubectl
}
export -f downloadKubectl

function coreDnsAddRecords() {
    local domain=$1
    local ip=$2
    printDebug "coreDnsAddRecords(domain: $domain, ip: $ip)"
    ## Add kathra.db into Coredns ConfigMap
    kubectl -n kube-system get cm coredns -o json >  $tmp/coredns.cm.json
    local configMap=$(kubectl -n kube-system get cm coredns -o json | jq -r '.data["kathra.db"]')
    if [ "$configMap" == "null" ]
    then
        cat > $tmp/kathra.db <<EOF
$domain.            IN      SOA     sns.dns.icann.org. noc.dns.icann.org. 2015082541 7200 3600 1209600 3600
$domain.            IN      NS      b.iana-servers.net.
$domain.            IN      NS      a.iana-servers.net.
$domain.            IN      A       $ip
*.$domain.          IN      CNAME   $domain.
EOF
        jq ".data += {\"kathra.db\": \"$(cat $tmp/kathra.db | sed ':a;N;$!ba;s/\n/\n/g')\"}" < $tmp/coredns.cm.json | sed "s/53 {/53 {\\\\n file \/etc\/coredns\/kathra.db $domain /g" > $tmp/coredns.cm.updated.json
        kubectl apply -f $tmp/coredns.cm.updated.json || printErrorAndExit "Unable to update coredns configmap: $tmp/coredns.cm.updated.json"
    fi
    
    ## Mount kathra.db into Coredns Deployment
    kubectl -n kube-system get deployment coredns -o json > $tmp/coredns.deployment.json
    if [ $(grep "kathra.db" < $tmp/coredns.deployment.json | wc -l) -eq 0 ]
    then
        jq ".spec.template.spec.volumes[0].configMap.items += [{\"key\": \"kathra.db\", \"path\": \"kathra.db\"}]" < $tmp/coredns.deployment.json > $tmp/coredns.deployment.updated.json
        kubectl apply -f $tmp/coredns.deployment.updated.json || printErrorAndExit "Unable to update coredns deployment: $tmp/coredns.deployment.updated.json"
    fi

    ## Test config
    checkCommandAndRetry "kubectl run -it --rm --restart=Never --image=infoblox/dnstools:latest dnstools -- '-c' \"host $domain\" | grep \"$domain has address $ip\" > /dev/null" || printErrorAndExit "Unable to run pod dnstools and check hostname"
    printInfo "CoreDNS Configured"
    return 0
}
export -f coreDnsAddRecords

function installTiller() {
    printDebug "installTiller()"
    curl -L https://git.io/get_helm.sh > $tmp/get_helm.sh && chmod +x $tmp/get_helm.sh || printErrorAndExit "Unable to download Helm"
    $tmp/get_helm.sh --version v$helmVersion  || printErrorAndExit "Unable to get Helm"
    helm list 2> /dev/null > /dev/null && printInfo "Tiller already installed" && return 0
    helm init || printErrorAndExit "Unable to init Helm's Tiller"
    checkCommandAndRetry '[ $(kubectl -n kube-system get deployment tiller-deploy -o json | jq -r '"'"'.status.readyReplicas'"'"' | sed '"'"'s/null/0/g'"'"') -gt 0 ]'
    [ $? -ne 0 ] && printError "Unable to init Helm's Tiller"
    printInfo "Tiller installed"
}
export -f installTiller


function installTraefik() {
    local domainDashboard=$1
    local httpPort=$2
    local httpsPort=$3
    printDebug "installTraefik(domainDashboard: $domainDashboard, httpPort: $httpPort, httpsPort: $httpsPort)"
    [ ! "$(helm list --output json | jq -r ".Releases[] | select(.Name==\"traefik\")")" == "" ] && printDebug "Traefik already installed" && return 0

    helm install stable/traefik --name traefik --version $traefikChartVersion --set dashboard.enabled=true,ssl.enabled=true,serviceType=NodePort,service.nodePorts.http=$httpPort,service.nodePorts.https=$httpsPort,dashboard.domain=$domainDashboard,rbac.enabled=true --namespace traefik || printErrorAndExit "Unable install Traefik"
    printInfo "Traefik installed"

    checkCommandAndRetry "curl --fail http://$domainDashboard:$httpPort > /dev/null 2> /dev/null " || printErrorAndExit "Unable to get dashboard with HTTP : curl --fail http://$domainDashboard:$httpPort "
    checkCommandAndRetry "curl --fail -k https://$domainDashboard:$httpsPort > /dev/null 2> /dev/null" || printErrorAndExit "Unable to get dashboard with HTTPS: curl --fail https://$domainDashboard:$httpsPort"
    printInfo "Traefik's dashboard is available via HTTP and HTTPS"
    return 0
}
export -f installTraefik

function configureDefaultCertificate() {
    local tlsFullChainFile=$1
    local tlsKeyFile=$2
    printDebug "configureDefaultCertificate(tlsFullChainFile: $tlsFullChainFile, tlsKeyFile: $tlsKeyFile)"
    kubectl -n traefik patch secrets traefik-default-cert -p "{\"data\": {\"tls.crt\":\"$(sudo cat $tlsFullChainFile | base64 -w0)\",\"tls.key\":\"$(sudo cat $tlsKeyFile | base64 -w0)\"}}" || printErrorAndExit "Unable to patch secrets 'traefik-default-cert' "
    printInfo "Traefik default certificate updated from files (fullchain: $tlsFullChainFile, key:$tlsKeyFile)"
    kubectl -n traefik delete pods --all > /dev/null 2> /dev/null
    return 0
}
export -f configureDefaultCertificate

function generateCertsDnsChallenge() {
    printDebug "generateCertsDnsChallenge(domain: $1)"
    local domain=$1
    local email=contact@$domain
    local certDir=/etc/letsencrypt/live/$domain
    export tlsCert=$certDir/fullchain.pem
    export tlsKey=$certDir/privkey.pem

    sudo ls -l $tlsCert > /dev/null 2> /dev/null && sudo ls -l $tlsKey > /dev/null 2> /dev/null && printInfo "Certificate already exists: $tlsCert, $tlsKey" && return 0

    printInfo "Generate new wildcard certificate for domain *.$domain with Let's Encrypt"

    sudo apt-get update
    sudo apt-get install -y python-minimal git-core letsencrypt
    [ -d /opt/certbot ] && sudo rm -Rf /opt/certbot 
    cd /opt
    sudo git clone https://github.com/certbot/certbot.git
    cd certbot && ./certbot-auto
    ./certbot-auto certonly --manual --preferred-challenges=dns --email=$email --agree-tos -d *.$domain  || printErrorAndExit "Unable to generate certificate for domain *.$domain"
    sudo chmod +r -R $certDir
    sudo ls -l $tlsCert > /dev/null || printErrorAndExit "File $tlsCert not found"
    sudo ls -l $tlsKey > /dev/null || printErrorAndExit "File $tlsKey not found"
    printInfo "Certificate FullChain and PrivateKey generated: $tlsCert, $tlsKey"
    return 0
}
export -f generateCertsDnsChallenge

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

main $*

exit $?