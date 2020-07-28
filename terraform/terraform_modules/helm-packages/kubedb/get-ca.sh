#!/bin/bash
[ ! -f /tmp/onessl ] && curl -fsSL -o /tmp/onessl https://github.com/kubepack/onessl/releases/download/0.3.0/onessl-linux-amd64 2> /dev/null
chmod +x /tmp/onessl
[ ! -f /tmp/kathra_kube_db_ca ] && /tmp/onessl get kube-ca > /tmp/kathra_kube_db_ca
echo "{\"cert\": $(cat /tmp/kathra_kube_db_ca | jq -aRs . | sed 's/\\/\\\\/g' )}"