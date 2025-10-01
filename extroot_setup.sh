#!/bin/bash

# --- Part 1: Extroot Setup ---

# Step 2: Prepare USB Device
# Replace /dev/sda with your device's identifier
DISK="/dev/sda"
parted -s ${DISK} -- mklabel gpt mkpart extroot 2048s -2048s
DEVICE="${DISK}1"
mkfs.ext4 -L extroot ${DEVICE}

# Step 3: Configure Extroot (fstab entry for USB)
eval $(block info ${DEVICE} | grep -o -e 'UUID="\S*"')
eval $(block info | grep -o -e 'MOUNT="\S*/overlay"')
uci -q delete fstab.extroot
uci set fstab.extroot="mount"
uci set fstab.extroot.uuid="${UUID}"
uci set fstab.extroot.target="${MOUNT}"
uci commit fstab

# Step 3: Configure Extroot (fstab entry for original overlay)
ORIG="$(block info | sed -n -e '/MOUNT="\S*\/overlay"/s/:\s.*$//p')"
uci -q delete fstab.rwm
uci set fstab.rwm="mount"
uci set fstab.rwm.device="${ORIG}"
uci set fstab.rwm.target="/rwm"
uci commit fstab

# Step 3: Transfer Data
mount ${DEVICE} /mnt
tar -C ${MOUNT} -cvf - . | tar -C /mnt -xf -

# --- Part 2: Swap Setup ---

# Step 1: Create and Format Swap File (1024MB)
DIR="$(uci -q get fstab.extroot.target)"
dd if=/dev/zero of=${DIR}/swap bs=1M count=1024
mkswap ${DIR}/swap

# Step 2: Enable Swap File on Boot
uci -q delete fstab.swap
uci set fstab.swap="swap"
uci set fstab.swap.device="${DIR}/swap"
uci commit fstab
service fstab boot

# Note: The 'reboot' command is omitted as users should run it manually.