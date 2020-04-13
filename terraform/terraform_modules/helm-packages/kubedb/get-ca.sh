#!/bin/bash
curl -fsSL -o /tmp/onessl https://github.com/kubepack/onessl/releases/download/0.3.0/onessl-linux-amd64 2> /dev/null && chmod +x /tmp/onessl
echo "{\"cert\": $(/tmp/onessl get kube-ca | jq -aRs . | sed 's/\\/\\\\/g' )}"
rm /tmp/onessl