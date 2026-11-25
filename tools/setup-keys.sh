#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Generate the release and AVB signing keys this port uses.
#
# The private keys are not tracked in this repository. Reusing the keys from
# the working checkout (copy them to keys/ next to this script, or directly to
# vendor/infinity-priv/keys) reproduces the existing signatures; generating a
# new set gives a functionally identical build with a different OTA
# certificate.
#
# Usage: tools/setup-keys.sh

set -euo pipefail

root="${ANDROID_BUILD_TOP:-$PWD}"
here="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/vendor/infinity-priv/keys"

if [ ! -f "$root/build/make/core/main.mk" ]; then
    echo "$root is not an Android tree" >&2
    exit 1
fi

mkdir -p "$out"

if [ -d "$here/keys" ] && [ -f "$here/keys/releasekey.x509.pem" ]; then
    echo "using the keys kept next to this repository"
    cp -a "$here/keys/." "$out/"
elif [ ! -f "$out/releasekey.pk8" ]; then
    echo "generating a release key"
    ( cd "$out" && "$root/development/tools/make_key" releasekey \
        '/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=Android/emailAddress=android@android.com' )
fi

if [ ! -f "$out/avb.pem" ]; then
    echo "generating a 4096-bit AVB key"
    openssl genrsa -out "$out/avb.pem" 4096
    python3 "$root/external/avb/avbtool.py" extract_public_key \
        --key "$out/avb.pem" --output "$out/avb_pkmd.bin"
fi

cp -f "$here/keys/keys.mk" "$out/keys.mk"
chmod 600 "$out/avb.pem" "$out/releasekey.pem" "$out/releasekey.pk8" 2>/dev/null || true
echo "keys are in $out"
