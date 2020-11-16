#!/usr/bin/env sh

set -e

role=${CONTAINER_ROLE:-app}

if [ $role = "app" ] || [ $role = "queue" ]; then
    [ $(curl -s -H "Host: ping" http://localhost) = "pong" ] || exit 1
fi

exit 0
