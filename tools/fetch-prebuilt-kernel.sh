#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Reconstruct device/xiaomi/zephyr-kernel for this port.
#
# The kernel is intentionally the stock Xiaomi 5.15.194 Image and its modules:
# MiCode's zephyr-w-oss drop has no techpack/, so a source-built kernel has no
# display, GPU, video or audio. The published LineageOS 24.0 OTA already
# carries the exact boot.img / dtbo.img / vendor_boot.img / vendor_dlkm /
# system_dlkm this port uses, so it is the source of the prebuilt tree.
#
# Usage: tools/fetch-prebuilt-kernel.sh [work-dir]
#
# Requires: gh (authenticated), unzip, python3 + venv, fsck.erofs, lz4, cpio.
# Run from the root of the Infinity X checkout.

set -euo pipefail

root="${ANDROID_BUILD_TOP:-$PWD}"
work="${1:-/tmp/zephyr-kernel-fetch}"
ota="$work/lineage-24.0-VANILLA-zephyr.zip"

if [ ! -f "$root/build/make/core/main.mk" ]; then
    echo "$root is not an Android tree" >&2
    exit 1
fi

mkdir -p "$work/images" "$work/vendor_dlkm" "$work/system_dlkm"

if [ ! -f "$ota" ]; then
    echo "downloading the LineageOS 24.0 VANILLA OTA (kernel donor)"
    gh release download 24.0 -R uzbforce/LineageOS-zephyr \
        -p 'lineage-24.0-*-VANILLA-zephyr.zip' -D "$work" --clobber
    ota=$(find "$work" -maxdepth 1 -name 'lineage-24.0-*-VANILLA-zephyr.zip' | head -1)
fi

if [ ! -f "$work/payload.bin" ]; then
    unzip -o -q "$ota" payload.bin payload_properties.txt -d "$work"
fi

if [ ! -x "$work/venv/bin/payload_dumper" ]; then
    python3 -m venv "$work/venv"
    "$work/venv/bin/pip" -q install payload_dumper
fi

if [ -z "$(find "$work/images" -name boot.img -print -quit)" ]; then
    "$work/venv/bin/payload_dumper" --out "$work/images" "$work/payload.bin"
fi

# The module partitions are EROFS, not ext4.
if [ -z "$(find "$work/vendor_dlkm" -name '*.ko' -print -quit)" ]; then
    fsck.erofs --extract="$work/vendor_dlkm" "$work/images/vendor_dlkm.img"
fi
if [ -z "$(find "$work/system_dlkm" -name '*.ko' -print -quit)" ]; then
    fsck.erofs --extract="$work/system_dlkm" "$work/images/system_dlkm.img"
fi

mkdir -p "$work/firmware/images"
for img in boot.img dtbo.img vendor_boot.img; do
    cp -f "$work/images/$img" "$work/firmware/images/$img"
done
ln -sfn "$work/vendor_dlkm" "$work/firmware/vendor_dlkm"
ln -sfn "$work/system_dlkm" "$work/firmware/system_dlkm"

python3 "$root/device/xiaomi/zephyr/tools/gen-prebuilt-kernel.py" \
    --dump "$work/firmware" --firmware "$work/firmware" \
    --out "$root/device/xiaomi/zephyr-kernel"

# The stock DT spends the whole 2 MB ramoops region on pmsg, so a boot that
# dies leaves no console log. Rebalance it to record-size/console-size/pmsg-size
# so recovery can read /sys/fs/pstore/console-ramoops-0 after a failed boot.
python3 "$root/device/xiaomi/zephyr/tools/patch-ramoops-dt.py" \
    "$root/device/xiaomi/zephyr-kernel"

# The uapi headers come from the matching Xiaomi source drop. Only the
# sched_param guard is needed on the prebuilt route; it is part of the kernel
# patch this repository carries.
if [ ! -f "$root/kernel/xiaomi/zephyr/Makefile" ]; then
    git clone --depth 1 -b zephyr-w-oss \
        https://github.com/MiCode/Xiaomi_Kernel_OpenSource \
        "$root/kernel/xiaomi/zephyr"
fi

kpatch="$(cd "$(dirname "$0")/.." && pwd)/patches/kernel/xiaomi/zephyr/0003-sync-the-current-kernel-and-techpack-changes.patch"
if ! git -C "$root/kernel/xiaomi/zephyr" apply --reverse --check "$kpatch" >/dev/null 2>&1; then
    git -C "$root/kernel/xiaomi/zephyr" apply "$kpatch"
fi

ANDROID_BUILD_TOP="$root" "$root/device/xiaomi/zephyr/tools/gen-kernel-headers.sh"

echo
echo "device/xiaomi/zephyr-kernel is ready."
