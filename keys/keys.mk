# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# Release signing keys for infinity_zephyr.
#
# PRODUCT_DEFAULT_DEV_CERTIFICATE signs the target-files APKs and, through
# sign_target_files_apks, the OTA package itself. The .pk8/.x509.pem files are
# the maintainer's release key (not AOSP testkey), so `mka bacon` produces a
# release-key-signed OTA and the otacert in META-INF matches releasekey.
#
# AVB is a separate 4096-bit key; BoardConfig.mk points BOARD_AVB_*_KEY_PATH at
# avb.pem directly.

PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/infinity-priv/keys/releasekey
PRODUCT_MAINLINE_BLUETOOTH_SEPOLICY_DEV_CERTIFICATES := $(dir $(PRODUCT_DEFAULT_DEV_CERTIFICATE))
