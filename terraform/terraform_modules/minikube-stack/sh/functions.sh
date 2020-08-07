#!/bin/bash
[ "$tmp" == "" ] && export tmp=/tmp/kathra.minikube.wrapper
[ ! -d $tmp ] && mkdir $tmp

function startMinikube() {
    printDebug "startMinikube(minikubeCpus: $minikubeCpus, minikubeMemory: $minikubeMemory, minikubeDiskSize: $minikubeDiskSize)"
    downloadMinikube
    installKubectl
    [ $(minikube status | grep -e "host: Running\|kubelet: Running\|apiserver: Running\|kubectl: Correctly Configured\|kubeconfig: Configured" | wc -l) -eq 4 ] && minikube addons enable ingress && printInfo "Minikube already started" && return 0
    if [ "$minikubeVmDriver" == "none" ]
    then
        $sudo minikube start --vm-driver="none" --kubernetes-version v$kubernetesVersion || printErrorAndExit "Unable to install minikube"
        rm -Rf $HOME/.minikube $HOME/.kube
        $sudo mv /root/.kube /root/.minikube $HOME
        $sudo chown -R $USER $HOME/.kube $HOME/.minikube
        sudo chown -R $USER /etc/kubernetes
        sed -i "s#/root/#${HOME}/#g" $HOME/.kube/config
    else
        minikube start --vm-driver=$minikubeVmDriver --cpus $minikubeCpus --memory $minikubeMemory --disk-size $minikubeDiskSize --kubernetes-version v$kubernetesVersion || printErrorAndExit "Unable to install minikube"
    fi
    printInfo "Minikubed started"
    minikube addons enable ingress                                              || printErrorAndExit "Unable to enable ingress"
    addDefaultCertNginxController "kathra-services" "default-tls"               || printErrorAndExit "Unable to Configure Nginx"
    return 0
}
export -f startMinikube

function getLocalIp() {
    local hostNetworkDevice=$(ip -4 addr show | grep '^[0-9]*:' | awk '{print $2;}' | sed 's/\://g' | grep -v 'lo' | head -n 1)
    local ip=$(ip -4 addr show $hostNetworkDevice | grep -oP '(?<=inet\s)[\da-f.]+')
    [ "$ip" == "" ] && return 1
    echo $ip
}

function addDefaultCertNginxController() {
    local namespace=$1
    local secretName=$2
    kubectl -n kube-system patch deployment nginx-ingress-controller -o json --type "json" -p "[{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/args/1\",\"value\":\"--default-ssl-certificate=$namespace/$secretName\"}]" 
}

function addLocalIpInCoreDNS() {
    printDebug "addLocalIpInCoreDNS(domain: $1)"
    [ "$(getLocalIp)" == "" ] && return 1
    coreDnsAddRecords $domain  "$(getLocalIp)"
}

function getKubeConfig() {
    printDebug "getKubeConfig()"
    local ca_file=$(kubectl config view -o json | jq -r '.clusters[] | select((.name=="minikube") or (.name=="docker-desktop")) | .cluster."certificate-authority"')
    local host=$(kubectl config view -o json | jq -r '.clusters[] | select((.name=="minikube") or (.name=="docker-desktop")) | .cluster.server')
    local client_cert_file=$(kubectl config view -o json | jq -r '.users[] | select((.name=="minikube") or (.name=="docker-desktop")) | .user."client-certificate"')
    local client_key_file=$(kubectl config view -o json | jq -r '.users[] | select((.name=="minikube") or (.name=="docker-desktop")) | .user."client-key"')
    echo "{\"cluster_ca_certificate\": \"$(echo $ca_file | base64 -w0)\", \"host\":\"$host\", \"client_certificate\":\"$(echo $client_cert_file | base64 -w0)\", \"client_key\":\"$(echo $client_key_file | base64 -w0)\"}"
}

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

    helm install appscode/kubedb --namespace kubedb --name $nameRelease --version $kubeDbVersion --set apiserver.ca="$(onessl get kube-ca)" --set apiserver.enableValidatingWebhook=true --set apiserver.enableMutatingWebhook=true || printErrorAndExit "Unable install kubedb"
    printInfo "KubeDB Installed"
    return 0
}
export -f installKubeDB

function forwardPort() {
    local portLocal=$1
    local hostDist=$2
    local portDist=$3
    printDebug "forwardPort(portLocal: $portLocal, hostDist: $hostDist, portDist: $portDist)"
    ! dpkg -s socat > /dev/null && sudo apt-get install -y socat
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
    [ "${minikubeVmDriver}" == "virtualbox" ] && ! dpkg -s virtualbox > /dev/null && sudo apt-get install -y virtualbox
    [ "${minikubeVmDriver}" == "none" ] && ! dpkg -s nfs-common > /dev/null && sudo apt-get install -y nfs-common
    which minikube > /dev/null 2> /dev/null && return 0
    sudo curl -L -o $tmp/minikube https://storage.googleapis.com/minikube/releases/v$minikubeVersion/minikube-linux-amd64
    sudo chmod +x $tmp/minikube
    sudo mv $tmp/minikube /usr/local/bin/minikube
}
export -f downloadMinikube

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

    ## Test DNS config
    checkCommandAndRetry "kubectl delete pods check-dns ; kubectl run -it --rm --restart=Never --image=infoblox/dnstools:latest check-dns -- '-c' \"host $domain\" | tee | grep \"$domain has address $ip\" > /dev/null" || printErrorAndExit "Unable to run pod dnstools and check hostname"
    printInfo "CoreDNS Configured"
    return 0
}
export -f coreDnsAddRecords



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
    printDebug "generateCertsDnsChallenge(domain: $1, tlsCertOut: $2, tlsKeyOut: $3)"
    local domain=$1
    local tlsCertOut=$2
    local tlsKeyOut=$3
    local email=contact@$domain
    local directoryName=$(sudo ls -l /etc/letsencrypt/archive/ | awk '{print $9}' | grep -E "$domain(-[0-9]+)*" | tail -n 1)
    if [ ! $directoryName == "" ]
    then
        local certDir=/etc/letsencrypt/live/$directoryName
        export tlsCert=$certDir/fullchain.pem
        export tlsKey=$certDir/privkey.pem

        sudo ls -l $tlsCert > /dev/null 2> /dev/null && sudo ls -l $tlsKey > /dev/null 2> /dev/null && printInfo "Certificate already exists: $tlsCert, $tlsKey" && sudo cp $tlsCert $tlsCertOut && sudo cp $tlsKey $tlsKeyOut && sudo chown $USER $tlsKeyOut && sudo chown $USER $tlsCertOut && return 0
    fi
    printInfo "Generate new wildcard certificate for domain *.$domain with Let's Encrypt"

    ! dpkg -s python-minimal > /dev/null && sudo apt-get install -y python-minimal
    ! dpkg -s letsencrypt > /dev/null    && sudo apt-get install -y letsencrypt
    ! dpkg -s git-core > /dev/null       && sudo apt-get install -y git-core

    [ -d /opt/certbot ] && sudo rm -Rf /opt/certbot 
    cd /opt && sudo git clone https://github.com/certbot/certbot.git && cd certbot && ./certbot-auto
    ./certbot-auto certonly --manual --preferred-challenges=dns --email=$email --agree-tos -d *.$domain  || printErrorAndExit "Unable to generate certificate for domain *.$domain"

    local directoryName=$(sudo ls -l /etc/letsencrypt/archive/ | awk '{print $9}' | grep -E "$domain(-[0-9]+)*" | tail -n 1)
    local certDir=/etc/letsencrypt/live/$directoryName
    export tlsCert=$certDir/fullchain.pem
    export tlsKey=$certDir/privkey.pem

    sudo chmod +r -R $certDir
    sudo ls -l $tlsCert > /dev/null || printErrorAndExit "File $tlsCert not found"
    sudo ls -l $tlsKey > /dev/null || printErrorAndExit "File $tlsKey not found"
    printInfo "Certificate FullChain and PrivateKey generated: $tlsCert, $tlsKey"
    sudo cp $tlsCert $tlsCertOut
    sudo cp $tlsKey $tlsKeyOut
    sudo chown $USER $tlsCertOut
    sudo chown $USER $tlsKeyOut
    return 0
}
export -f generateCertsDnsChallenge

function initTfVars() {
    local file=$1
    [ -f $file ] && rm $file
    echo "domain = \"$domain\"" >> $file
    echo "kube_config = $(getKubeConfig)" >> $file
    echo "kathra_version = \"$kathraImagesTag\"" >> $file
    [ $manualDnsChallenge -eq 1 ]    && echo "tls_cert_filepath = \"$tmp/tls.cert\""        >> $file
    [ $manualDnsChallenge -eq 1 ]    && echo "tls_key_filepath = \"$tmp/tls.key\""          >> $file
    [ $automaticDnsChallenge -eq 1 ] && echo "acme_provider = \"$acmeDnsProvider\""         >> $file
    [ $automaticDnsChallenge -eq 1 ] && echo "acme_config = ${acmeDnsConfig}"               >> $file
}
export -f initTfVars


function terraformInitAndApply() {
    terraform init                      || printErrorAndExit "Unable to init terraform"
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
}
export -f terraformInitAndApply