# infinityx_patches_zephyr

Project Infinity X 4.2 (Android 17, `cp2a`) for the **Redmi Note 17 4G**
(codename `zephyr`, Xiaomi `p19a`, SM6225-AF / `bengal`), built from the
working LineageOS 24.0 port plus only the patches Infinity X actually needs.

This is the third leg of the port:

| Repository | Holds |
|---|---|
| [android_device_xiaomi_zephyr](https://github.com/uzbforce/android_device_xiaomi_zephyr) (`lineage-24.0`) | device tree: `BoardConfig.mk`, product makefiles, `rootdir/`, `configs/`, overlays, recovery files, `tools/` |
| [android_vendor_xiaomi_zephyr](https://github.com/uzbforce/android_vendor_xiaomi_zephyr) (`lineage-24.0`) | blobs extracted from the stock firmware |
| **this repository** | patches against Infinity X source projects, the local manifest, the Infinity product configuration, and the helpers that reproduce the build |

## Resulting build

```text
Lunch target : infinity_zephyr-userdebug
Build ID     : CP2A.260605.016
Build type   : UNOFFICIAL (community build, not an Infinity maintainer build)
Package type : VANILLA (no GMS)
Maintainer   : uzbforce
Market name  : Redmi Note 17 4G
SoC          : Snapdragon 6s Gen2
Camera       : 50MP + 16MP
UDFPS        : enabled (TARGET_HAS_UDFPS := true)
Signing      : local vendor/infinity-priv/keys, release key + 4096-bit AVB key
OTA          : signed by `mka bacon`
Kernel       : prebuilt 5.15.194-android13-8 from the stock firmware
Props        : stock spoof (user build type/fingerprint, release-keys,
               verified-boot green; see "Stock spoof" below)
```

The product is named `infinity_zephyr`, but `INFINITY_BUILD` is `zephyr`:
Infinity's `gen_build_prop.py` writes `ro.infinity.device=<DeviceName>`
unconditionally, and `version.mk` writes the same property. With the full
product name the two values differ and `post_process_props` rejects the
duplicate; with the codename they agree. `lunch` expects
`infinity_<device>[-<release>]-<variant>`; the release is read from
`vendor/infinity/vars/aosp_target_release` (`cp2a`).

## Fresh checkout

```bash
repo init -u https://github.com/ProjectInfinity-X/manifest -b 17 --git-lfs
git clone https://github.com/uzbforce/infinityx_patches_zephyr \
    infinityx_patches_zephyr
cp infinityx_patches_zephyr/local_manifests/zephyr.xml .repo/local_manifests/
repo sync -c -j"$(nproc --all)" --no-clone-bundle --optimized-fetch --prune --force-sync
./infinityx_patches_zephyr/apply.sh
```

`apply.sh` applies everything in `patches/` in filename order, validates each
one with `git apply --check`, skips patches already present, and retries with a
one-line context reduction where Infinity's copy of a project differs by a
nearby line. Patches that do not belong to the checkout are reported as
`SKIP`, not as failures. Nothing is committed.

Two inputs are not repo projects:

1. **Prebuilt kernel tree** — `device/xiaomi/zephyr-kernel` (Image, DTBO,
   27 base DTBs, `vendor_dlkm`/`system_dlkm`/`vendor_ramdisk` modules, and the
   uapi `kernel-headers`). Run once:

   ```bash
   ./infinityx_patches_zephyr/tools/fetch-prebuilt-kernel.sh
   ```

   It downloads the published LineageOS 24.0 VANILLA OTA (the build that used
   this exact kernel), extracts `boot.img`, `dtbo.img`, `vendor_boot.img`,
   `vendor_dlkm.img` and `system_dlkm.img` from `payload.bin`, assembles the
   tree with the device tree's `tools/gen-prebuilt-kernel.py`, then exports the
   uapi headers from Xiaomi's `zephyr-w-oss` kernel source. The header step
   needs the `sched_param` guard in `patches/kernel/xiaomi/zephyr/0003`.

   The stock firmware route (`extract-firmware.sh` + the same generator) works
   too; it is what the device tree README documents. The OTA route is used
   here because the previous Lineage build is the known-good donor, and it is
   the only route that reproduces the kernel the vendor blobs were tested
   against without a multi-gigabyte HyperOS package.

2. **Signing keys** — `vendor/infinity-priv/keys`. This repository contains
   `keys/keys.mk` and the public certificates, and deliberately does not track
   the private keys. Copy the working checkout's `keys/` directory here (it is
   `.gitignore`d) or generate a new set with `tools/setup-keys.sh`. A new set
   changes the OTA certificate but nothing functional; reuse the original for
   byte-identical signatures.

## Build

```bash
source build/envsetup.sh
lunch infinity_zephyr-userdebug
mka bacon
```

Artifacts land in `out/target/product/zephyr/`:

```text
Project_Infinity-X-4.2-zephyr-<date>-VANILLA-UNOFFICIAL.zip
Project_Infinity-X-4.2-zephyr-<date>-VANILLA-UNOFFICIAL.zip.json
```

The zip is the signed full OTA (`payload.bin`, Virtual A/B), not a recovery
zip and not a separate `-ota.zip`. `mka bacon` also leaves the individual
images (`boot.img`, `init_boot.img`, `vendor_boot.img`, `dtbo.img`, `vbmeta.img`,
`recovery.img`, `system.img`, `vendor.img`, `product.img`, `system_ext.img`,
`odm.img`, `vendor_dlkm.img`, `system_dlkm.img`) in the same directory.

## Flashing the build

The OTA is signed with the local `releasekey`. Sideload it with the recovery
that is already installed: that recovery comes from the previous insecure-ADB
build, so `adb devices` works there before authorization.

```bash
# reboot to recovery, then:
adb devices
adb sideload out/target/product/zephyr/Project_Infinity-X-4.2-zephyr-25.11.2026-VANILLA-UNOFFICIAL.zip
adb reboot
```

If the installed recovery rejects the OTA, flash the new recovery/boot/
vendor_boot images with fastboot (they are signed with the same local key),
then boot recovery and sideload:

```bash
fastboot flash recovery   out/target/product/zephyr/recovery.img
fastboot flash boot       out/target/product/zephyr/boot.img
fastboot flash init_boot  out/target/product/zephyr/init_boot.img
fastboot flash vendor_boot out/target/product/zephyr/vendor_boot.img
fastboot flash dtbo       out/target/product/zephyr/dtbo.img
fastboot flash vbmeta     out/target/product/zephyr/vbmeta.img
```

The new build restores the stock spoof, so after the first boot `adb devices`
shows `unauthorized` until you accept the host key in SystemUI. `adb root` is
not available; that is the intended stock identity. Do **not** flash only
`system.img` over the old `system_ext`: the OTA is the supported update path.

## Capturing the bootloop

On a normal boot adb requires authorization, so accept the host key in
SystemUI first. The stock spoof reports `ro.build.type=user`, so `adb root` and
`dmesg` are unavailable, but logcat and pstore still work:

```bash
adb logcat -b all -v threadtime > logcat.txt
adb shell 'cat /sys/fs/pstore/console-ramoops-0' > ramoops.txt
```

If the boot never reaches adbd, boot recovery and pull the kernel ring instead:

```bash
adb exec-out cat /sys/fs/pstore/console-ramoops-0 > ramoops.txt
```

The `console-size` in the rebuilt `vendor_boot` is what makes that file exist;
the stock DT only had a `pmsg` zone. A bootloop at the animation with a live
adbd is almost always `system_server` crashing or waiting on a HAL, so the
first interesting lines are `FATAL EXCEPTION IN SYSTEM PROCESS`, `Watchdog`,
`avc: denied`, and `waitForService`/`getService` timeouts.

## Stock spoof

This is an unofficial Android 17 port of the stock Android 16 firmware, and it
keeps presenting the stock identity on purpose. Two mechanisms do that:

1. `infinity_zephyr.mk` applies `PRODUCT_BUILD_PROP_OVERRIDES` on every build,
   so `ro.build.fingerprint` (and the per-partition fingerprints) are the
   stock `Redmi/zephyr_global/zephyr:16/...:user/release-keys` values.
   Infinity's `gen_build_prop.py` reports every non-eng build as `user`.
2. `system/core/init` is built with `SPOOF_SAFETYNET=1`. Before adbd starts,
   `SetSafetyNetProps()` rewrites `ro.boot.verifiedbootstate=green`,
   `ro.boot.flash.locked=1`, `ro.boot.vbmeta.device_state=locked`,
   `ro.debuggable=0`, `ro.adb.secure=1`, `ro.build.type=user` and the
   per-partition `ro.*.build.type` properties, after the partition build.prop
   files have been loaded.

The stock vendor blobs and Play Integrity see a locked, user/release-keys
device even though the bootloader is unlocked and lunch selected `userdebug`.
The trade-off is that ADB authentication is on: accept the host key in
SystemUI the first time, and `adb root` is unavailable. If a future boot hangs
before SystemUI and ADB is needed to diagnose it, undo all three temporarily:
build with `WITH_ADB_INSECURE := true`, add
`-USPOOF_SAFETYNET`/`-DSPOOF_SAFETYNET=0` to the `debuggable` cppflags in
`system/core/init/Android.bp`, and gate `PRODUCT_BUILD_PROP_OVERRIDES` behind
`ifeq ($(TARGET_BUILD_VARIANT),user)`. That is the debug configuration this
port used while fixing the sensors HAL.

## Reading a boot that fails

The stock DT gives the whole 2 MB ramoops region to `pmsg`, so a boot that
stops before ADB leaves nothing in `/sys/fs/pstore`. `tools/fetch-prebuilt-kernel.sh`
runs the device tree's `patch-ramoops-dt.py` after generating the kernel tree;
it rebalances 19 of the 27 DTBs to `record-size=0x40000`,
`console-size=0x80000`, `pmsg-size=0x80000`, keeping the stock blobs under
`dtbs/.dtb-stock/`. Re-run it after any regeneration:

```bash
python3 device/xiaomi/zephyr/tools/patch-ramoops-dt.py device/xiaomi/zephyr-kernel
mka vendorbootimage
```

After a failed boot, boot recovery and read the kernel log:

```bash
adb exec-out cat /sys/fs/pstore/console-ramoops-0 > ramoops.txt
```

The build now presents the stock user identity, so adb needs authorization and
`dmesg` is unavailable. `adb logcat` works once the host key is accepted, and
pstore is readable from recovery even when the boot never reaches SystemUI.

## The sensors HAL bootloop

Once ADB worked, the next boot showed a live adbd, `system_server` and
`surfaceflinger`, but `sys.boot_completed` stayed unset and logcat repeated:

```text
Watchdog: *** WATCHDOG KILLING SYSTEM PROCESS: Blocked in handler on main
thread (main) for 66s
    at android.hardware.SystemSensorManager.nativeCreate(Native Method)
    at com.android.server.wm.ActivityTaskManagerService.installSystemProviders
```

`SensorService: nuSensorService starting...` was the last SensorService line
and `lshal` showed `android.hardware.sensors@2.1::ISensors/default` declared
but never registered. Two independent faults produced that:

1. `hardware/xiaomi/aidl/sensors` builds the AIDL multihal
   `android.hardware.sensors-service.xiaomi-multihal`, and its VINTF fragment
   declares `android.hardware.sensors.ISensors/default`. AOSP's
   `vendor_file_contexts` has `hal_sensors_default_exec` patterns for
   `...sensors-service(.multihal)?` and `...sensors@X.Y-service.multihal`, but
   not for the `.xiaomi-multihal` suffix, so the binary stayed `vendor_file`
   and init had no domain for the service. The AIDL instance therefore never
   appeared, and `AidlSensorHalWrapper::connect()` called
   `AServiceManager_waitForService()` 20 times (5 s each) on the system_server
   main thread - longer than the 60 s watchdog. The device tree now labels the
   binary `hal_sensors_default_exec`.
2. The stock HIDL 2.1 multihal is also shipped by the vendor blobs and starts
   as `class hal`. It loads the same `sensors.ssc.so`,
   `sensors.touch.detect.so` and `sensors.xiaomi.zephyr.udfps.so` sub-HALs and
   stayed blocked in sub-HAL init. `configs/init/android.hardware.sensors@2.1-service-multihal.rc`
   overrides the stock rc with a `disabled` service so only the AIDL HAL runs.

`frameworks/native` no longer blocks on a declared-but-missing HAL. The AIDL
wrapper probes with `AServiceManager_getService()` five times and returns
false, and the HIDL wrapper uses `tryGetService()`: `getService()` never
returns while an interface is in VINTF but not running, which is exactly the
state the disabled stock HAL leaves behind. A HAL that never registers can now
only cost sensors, not the boot.

Two labels the stock vendor policy has and `device/qcom/sepolicy_vndr/sm6225`
does not were added as well: the touch controller's `chip_name`
(`sysfs_chip_name`, read by `sscrpcd` before the SSC registry starts) and
`palm_sensor` (`vendor_sysfs_touch_node`, written by the touch detect
sub-HAL). Without them sscrpcd kept retrying the denied read and the registry
never became ready.

## What was ported from `lineage_patches_zephyr`

The Lineage patch set contains two kinds of changes: generic Android 17 /
SM6225 / zephyr device fixes, and LineageOS feature work. Only the first kind
belongs here.

### Kept (device/generic)

| Patch | Fix |
|---|---|
| `bootable/recovery` | Android 17 libc++ no longer transitively includes `<memory>`, `<string>`, etc.; add the direct includes the recovery UI/sideload/volume-manager sources use |
| `external/tinyalsa` | vendor mixer can expose an enum entry with no text; don't hand NULL to `strncpy()` |
| `frameworks/av` | export `GraphicBufferSource::getHGraphicBufferProducer()` in both flag variants; `OmxInfoBuilder` uses `tryGetService()` because the stock OMX HAL is 32-bit and this product is 64-bit only; test the local `AidlGraphicBufferSource` path before the HIDL store call so screenrecord/encoders get an input surface |
| `hardware/interfaces` | skip the multi-STA "primary connection" hint when only one STA iface exists; the QCA driver returns `-ENODEV` and the AIDL HAL otherwise tears down `createStaIface` |
| `hardware/lineage/compat` | export protobuf 3.9 symbols (`CopyWithSourceCheck`, `ParseFromString(const std::string&)`, legacy `AssignDescriptors`) and out-of-line `DynamicDisplayInfo`/`StaticDisplayInfo` that the stock `qccsyshal@1.2` / `libgui_vendor` import |
| `hardware/lineage/interfaces` | drive the vendor FOD `extCmd` from `onPointerDown`/`onPointerUp` so the stock Goodix `fingerprint.goodix_fod.so` capture window arms; set/release local 1000-nit HBM on press with a 5 s watchdog |
| `hardware/qcom-caf/thermal` | shift the SKIN ramp up ~5 °C: zephyr reads `xo-therm`, which idles at ~39.5 °C, so thermalservice started at `MODERATE` and camera video was refused |
| `hardware/qcom-caf/wlan` | the legacy HAL also reports success without sending `CONCURRENT_STA_PRIMARY`, which the firmware rejects with `-ENODEV` |
| `hardware/qcom-caf/sm6225/audio/primary-hal` | don't build `libqcompostprocbundle`: it needs the audio techpack header the kernel drop does not ship; the stock library is used |
| `lineage-sdk` | don't throw from `LineageGlobalActions` when the `lineageglobalactions` service is absent; return the local list |
| `system/libbase` | keep the pre-`string_view` `WriteStringToFd(const std::string&, borrowed_fd)` / `Trim(const std::string&)` symbols the prebuilt health and sensors HALs import |
| `system/sepolicy` | treat an absent `treble_labeling_violators` attribute as an empty set instead of aborting `treble_labeling_tests` |
| `system/vold` | add the standard library includes Android 17's libc++ no longer pulls in |
| `tools/extract-utils` | symlink modules take their soong name from the path; `vendor/bin/[` is not a valid identifier |
| `vendor/qcom/opensource/power` | declare `interface aidl` in the QTI power rc and join the input group so the FTS double-tap gesture can be armed |
| `vendor/qcom/opensource/vibrator` | select the LED trigger only when its attributes are missing, chown the attributes and restart once boot completes |
| `kernel/xiaomi/zephyr/0003` | `sched_param` guard in `include/uapi/linux/sched/types.h` (needed by the header export); also the techpack/defconfig changes for a source rebuild |
| `device/qcom/sepolicy_vndr/sm6225/0001-0003` | Android 16 prebuilt-dir variables, Tango seapp fallback, conflicting `/class/typec` genfscon. The pinned mirror already carries them, so these normally report `already applied` |

### Adapted

| Patch | Why it had to change |
|---|---|
| `frameworks/base/0001-zephyr-device-and-udfps-fixes.patch` | only the device fixes that were genuinely missing from Infinity: `StorageManagerService` transcoding on its own thread + a post-boot emulated-volume retry, `HardeningEnforcer` media focus for non-while-in-use services, legacy keyguard occlusion mirrored into the shade window, UDFPS wakeup sensor selection and `config_udfps_sensor_props` coordinates, the biometric prompt position above the sensor, the real display cutout for the face-scanning provider, and the `TelephonyBaseUtilsStub.isMiuiRom()` stub the stock IMS/`QtiTelephony` blobs link against |
| `packages/apps/Settings/0001-...dumpstate...` | only the non-blocking `getService()` fix for `EnableVerboseVendorLoggingPreferenceController`. Infinity has its own `EnableBlursPreferenceController`/`BlurSettings` UI, so the Lineage blur preference and `DISABLE_WINDOW_BLURS` hunks are not here |
| `packages/apps/Dialer` | re-captured against Infinity's Dialer, which already has the "disable proximity sensor" preference. The patch adds the `AudioManager.getCommunicationDevice()` route tracking on top |
| `vendor/infinity/0001-fall-back-to-the-unpinned-build-manifest.patch` | the Lineage `vendor/lineage` manifest fix, adapted to Infinity's `build/tasks/build-manifest_xml.mk`: `repo manifest -r` fails when an intentionally absent project is not checked out; fall back to the unpinned manifest instead of failing the OTA |
| `device/xiaomi/zephyr/0001-configure-the-infinity-x-product.patch` | the product port itself: `infinity_zephyr.mk`, `AndroidProducts.mk`, the Infinity/AVB key paths, device-tree props (`ro.product.marketname`, `ro.infinity.{codename,soc,camera}`), the `hardware/xiaomi` namespace, and dropping the stale `libudfpshandler` package (no such module exists in current Lineage hardware/xiaomi; the AIDL HAL drives the Goodix blob directly) |

### Deliberately excluded as Lineage-specific

| Patch | Why Infinity does not need it |
|---|---|
| `packages/apps/Launcher3/0001-respect-the-live-window-blur-state.patch` | Lineage Launcher3's `WindowBlurState`; Infinity's Launcher3 from `lfs` does not have that class, so the patch would not compile |
| `packages/apps/Settings` blur hunks | Infinity ships its own blur settings (`EnableBlursPreferenceController`, `BlurSwitchPreference`); porting Lineage's preference and `DISABLE_WINDOW_BLURS` controller would duplicate it |
| `frameworks/base` face-indicator / keyguard UI hunks | Infinity already contains the Paranoid Sense provider, `FaceUnlockImageView`, `KeyguardIndicationAreaTop` and the face bouncer callbacks. Re-applying Lineage's presentation would conflict |
| `frameworks/base` IMS/VoLTE status-bar icon hunks | Infinity has its own IMS icon pipeline (`ImsStatusBarIconViewModel`, `VoLteBindableIcon`) |
| `frameworks/base` `BlurController` hunk and `services/core/Android.bp` Sense dependency | Lineage feature work / already present |
| `build/soong/0002` (the original Lineage patch) | already applied in Infinity's `build/soong` |
| `vendor/lineage/0005` | replaced by the `vendor/infinity` adaptation above |
| `kernel/xiaomi/zephyr/0004` | adds the 5,291-file vendor DTS tree for a source kernel build; this port uses the prebuilt stock kernel. Re-apply it only if rebuilding the kernel from `MiCode/Xiaomi_Kernel_OpenSource` |

The SM6225 platform repos are pinned by `local_manifests/zephyr.xml`; the
three sepolicy fixes and the primary-hal patch are also carried here so a
fresh sync that resolves a different mirror revision still gets them.

## Verification

```bash
# OTA certificate matches the release key
unzip -p out/target/product/zephyr/Project_Infinity-X-*-ota.zip \
    META-INF/com/android/otacert | openssl x509 -noout -fingerprint -sha256
openssl x509 -in vendor/infinity-priv/keys/releasekey.x509.pem \
    -noout -fingerprint -sha256

# product identity
grep -E 'ro\.(product\.marketname|infinity\.(codename|soc|camera|maintainer|buildstatus))' \
    out/target/product/zephyr/*/build.prop 2>/dev/null
```

The device tree README's "Known gaps" still apply: this is the same hardware
bring-up, not a different one. FOD, IMS, Wi-Fi, audio, thermal and the
recovery touch modules are the areas to check first on a real boot.

## Credits

Base port and the original patch analysis:
[lineage_patches_zephyr](https://github.com/uzbforce/lineage_patches_zephyr).
The filtering follows the same policy used for the
[RisingOS Revived port](https://github.com/uzbforce/risingosr_patches_zephyr)
and the [MistOS port](https://github.com/uzbforce/mistos_patches_zephyr).
