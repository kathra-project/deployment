#!/bin/bash -x

#!/bin/bash
export tmp=/tmp/kathra.jenkins.init_token.$(date +%s%N)
[ ! -d $tmp ] && mkdir $tmp
export SCRIPT_DIR=$(realpath $(dirname `which $0`))
export debug=1

. ${SCRIPT_DIR}/../../sh/commons.func.sh
. ${SCRIPT_DIR}/../../sh/jenkins.func.sh

export retrySecondInterval=2
export max_attempts=5

printDebug "$*"
declare nexus_url=$1
declare repository_name=$2
declare username=$3
declare password=$4
declare type=$5
declare format=$6

eval "$(jq -r '@sh "nexus_url=\(.nexus_url) repository_name=\(.repository_name) username=\(.username) password=\(.password) type=\(.type) format=\(.format)"')"
