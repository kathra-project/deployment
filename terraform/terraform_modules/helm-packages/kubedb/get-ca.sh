#!/bin/bash
curl -fsSL -o onessl https://github.com/kubepack/onessl/releases/download/0.3.0/onessl-linux-amd64 2> /dev/null && chmod +x onessl
echo "{\"cert\": $(onessl get kube-ca | jq -aRs . | sed 's/\\/\\\\/g' )}"