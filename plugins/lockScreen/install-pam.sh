#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

sudo install \
    --owner=root \
    --group=root \
    --mode=0644 \
    "$script_dir/pam.d/quickshell-lock" \
    /etc/pam.d/quickshell-lock

echo "Installed /etc/pam.d/quickshell-lock"
