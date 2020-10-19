#!/bin/bash
export SCRIPT_DIR=$(realpath $(dirname `which $0`))

echo '{"host": "kathra.org"}' | $SCRIPT_DIR/resolv_host.sh > $TMP/resolv_host.test.result
cat $TMP/resolv_host.test.result
if [[ $(jq -r '.ip' < $TMP/resolv_host.test.result) =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Script work !"
  exit 0
else
  echo "Script fail !"
  exit 1
fi