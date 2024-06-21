#!/bin/sh

set -e

if ! command -v envsubst > /dev/null; then
   apk add --no-cache gettext
fi

envsubst < /etc/trojan-go/templates/config.json > /etc/trojan-go/config.json

# cat /etc/trojan-go/config.json

if [ "$#" -eq 0 ]; then
    set -- /etc/trojan-go/config.json
fi

exec /usr/local/bin/trojan-go -config "$@"