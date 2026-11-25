#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Capture the working-tree change of one project as a patch in patches/.
#
# Usage: ./capture.sh <project-relative-path> "<subject>"
# Example: ./capture.sh frameworks/base "fix the next thing"
#
# The layout mirrors the checkout, the same as apply.sh. Untracked files are
# included as new-file entries; the intent-to-add marker is removed afterwards
# and only those paths are touched, so anything already staged stays staged.

set -eu

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <project> \"<subject>\"" >&2
    exit 1
fi

project="$1"
subject="$2"
root="${ANDROID_BUILD_TOP:-$PWD}"
dir="$root/$project"
patches="$(cd "$(dirname "$0")" && pwd)/patches"
out="$patches/$project"

[ -d "$dir" ] || { echo "$dir does not exist" >&2; exit 1; }
git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || {
    echo "$project is not a git checkout" >&2; exit 1; }

mkdir -p "$out"

slug=$(printf '%s' "$subject" | tr '[:upper:]' '[:lower:]' \
       | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-//' -e 's/-$//')
n=1
while [ -e "$out/$(printf '%04d' "$n")-$slug.patch" ]; do
    n=$((n + 1))
done
file="$out/$(printf '%04d' "$n")-$slug.patch"

# Include untracked files, but remember exactly which ones so the marker can
# be removed without disturbing the index.
mapfile -t untracked < <(git -C "$dir" ls-files --others --exclude-standard)
for f in "${untracked[@]}"; do
    git -C "$dir" add -N -- "$f"
done

git -C "$dir" diff --binary > "$file"

for f in "${untracked[@]}"; do
    git -C "$dir" reset -q -- "$f"
done

echo "wrote $file"
