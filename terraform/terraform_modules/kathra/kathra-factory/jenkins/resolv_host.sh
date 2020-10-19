#!/bin/bash
eval "$(jq -r '@sh "host=\(.host)"')"
if [ "$OSTYPE" == "msys" ] || [ "$OSTYPE" == "win32" ]
then
    which powershell.exe 2> /dev/null > /dev/null
    [ $? -ne 0 ] && >&2 echo "powershell.exe not found" && exit 1
    powershell.exe -Command "Resolve-DnsName $host -Type A | ConvertTo-Json" > $TMP/lookup_host
    cat $TMP/lookup_host | jq -r '.[0] | .IP4Address' > $TMP/lookup_host.ip 2> /dev/null
    [ $? -ne 0 ] && cat $TMP/lookup_host | jq -r '.IP4Address' > $TMP/lookup_host.ip 2> /dev/null
    ip=$(cat $TMP/lookup_host.ip)
else 
    which nslookup 2> /dev/null > /dev/null
    [ $? -ne 0 ] && >&2 echo "nslookup not found" && exit 2
    ip=$(nslookup $host | awk '/^Addecho ress: / { print $2 }' | head -n 1)
fi

which jq 2> /dev/null > /dev/null
[ $? -ne 0 ] && >&2 echo "jq not found" && exit 3
jq -n --arg ip "$ip" --arg host "$host" '{"ip": $ip, "host": $host}'
exit $?