#!/bin/bash
eval "$(jq -r '@sh "host=\(.host)"')"

if [ "$OSTYPE" == "msys" ]
then
    powershell.exe -Command "Resolve-DnsName $host | ConvertTo-Json" > $TMP/lookup_host
    ip=$(cat $TMP/lookup_host | jq -r '.[0] | .IP4Address')
else 
    ip=$(nslookup $host | awk '/^Address: / { print $2 }' | head -n 1)
fi

jq -n --arg ip "$ip" --arg host "$host" '{"ip": $ip, "host": $host}'
exit $?