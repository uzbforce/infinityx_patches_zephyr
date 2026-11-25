#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Apply every patch in patches/ to a Project Infinity X checkout. Layout of
# patches/ mirrors the checkout, so a patch at patches/a/b/foo.patch applies
# inside $ANDROID_BUILD_TOP/a/b.
#
# Usage: ./apply.sh [checkout-root]

set -u

root="${1:-${ANDROID_BUILD_TOP:-$PWD}}"
here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$here/patches"

if [ ! -d "$repo_root" ]; then
    echo "no patches/ directory next to $0" >&2
    exit 1
fi

if [ ! -d "$root/build/make" ]; then
    echo "$root does not look like a ROM checkout (no build/make)" >&2
    exit 1
fi

# Signing keys are not part of the public repository. When a local keys/
# directory is present (copy of the working checkout's vendor/infinity-priv/
# keys), install it first so the build signs with the same keys.
if [ -d "$here/keys" ]; then
    echo "installing signing keys into vendor/infinity-priv/keys"
    mkdir -p "$root/vendor/infinity-priv/keys"
    cp -a "$here/keys/." "$root/vendor/infinity-priv/keys/"
    chmod 600 "$root/vendor/infinity-priv/keys/"*.pem \
              "$root/vendor/infinity-priv/keys/"*.pk8 2>/dev/null || true
fi

applied=0
skipped=0
failed=0

while IFS= read -r patch; do
    rel="${patch#\"$repo_root\"/}"
    project="${rel%/*}"
    [ "$project" = "$rel" ] && project="."   # patch at the repo root
    dir="$root/$project"

    printf '%-78s ' "$project/${rel##*/}"

    if [ ! -d "$dir" ]; then
        echo "SKIP (no such project in this checkout)"
        skipped=$((skipped + 1))
        continue
    fi

    if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
        echo "SKIP (not a git checkout)"
        skipped=$((skipped + 1))
        continue
    fi

    # Already there? Then applying it again is a no-op.
    if git -C "$dir" apply --reverse --check "$patch" >/dev/null 2>&1; then
        echo "already applied"
        skipped=$((skipped + 1))
        continue
    fi

    # Infinity's copies of some AOSP projects differ by a nearby line; the
    # one-line reduction lets those hunks land without weakening the check.
    if git -C "$dir" apply --check "$patch" >/dev/null 2>&1; then
        git -C "$dir" apply "$patch" && echo "applied"
        applied=$((applied + 1))
    elif git -C "$dir" apply -C1 --check "$patch" >/dev/null 2>&1; then
        git -C "$dir" apply -C1 "$patch" && echo "applied (-C1)"
        applied=$((applied + 1))
    else
        echo "FAILED (does not apply cleanly)"
        git -C "$dir" apply --check "$patch" 2>&1 | sed 's/^/    /'
        failed=$((failed + 1))
    fi
done < <(find "$repo_root" -type f -name '*.patch' | sort)

echo
echo "applied $applied, skipped $skipped, failed $failed"
echo "changes are unstaged: review with 'git -C $root/<project> diff'"
echo
echo "The prebuilt kernel tree (device/xiaomi/zephyr-kernel) is not a repo"
echo "project. Run tools/fetch-prebuilt-kernel.sh once if it is missing; see"
echo "the README section 'Prebuilt kernel'."

[ "$failed" -eq 0 ]
