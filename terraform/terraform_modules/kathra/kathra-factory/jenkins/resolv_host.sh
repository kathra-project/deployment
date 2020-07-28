#!/bin/bash
eval "$(jq -r '@sh "host=\(.host)"')"

ip=$(nslookup $host | awk '/^Address: / { print $2 }' | head -n 1)

jq -n --arg ip "$ip" --arg host "$host" '{"ip": $ip, "host": $host}'
exit $?