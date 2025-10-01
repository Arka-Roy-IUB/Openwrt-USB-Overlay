# 💾 OpenWrt Extroot and Swap Setup Tutorial

This guide details the process of setting up **Extroot** on an OpenWrt router to increase storage space for packages using a USB drive. For routers with limited RAM (like 128MB), it also includes an essential step to create a **swap file** on the new external storage to prevent frequent system crashes.

---

## 🛠️ Requirements

* **OpenWrt Device:** Must have a USB or memory card port (using an SSD on a USB adapter is often more reliable than flash drives).
* **SSH/Terminal Access:** Use software like PuTTY or your system's inbuilt terminal.
* **USB Drive/SSD:** The size depends on your package needs.
* **⚠️ Warning:** This procedure will **cleanly wipe the USB drive**. Please back up any critical data before starting.

---

## 🚀 Part 1: Setup Extroot to Increase Storage

### Step 1. Install Packages for Extroot

1.  Connect to your router via SSH/Terminal as `root`.
2.  Update the package list:

    ```bash
    opkg update
    ```

### Step 2. Prepare USB Device for Extroot

1.  Plug the USB drive into your OpenWrt router.
2.  Identify the USB drive's identifier (e.g., `/dev/sda`).

    ```bash
    fdisk -l
    # or
    ls -l /sys/block
    ```

3.  Partition and format the USB drive. **Replace `/dev/sda` with your device's identifier.**

    ```bash
    DISK="/dev/sda"
    parted -s ${DISK} -- mklabel gpt mkpart extroot 2048s -2048s
    DEVICE="${DISK}1"
    mkfs.ext4 -L extroot ${DEVICE}
    ```

### Step 3. Configure Extroot and Reboot

1.  Set up the `fstab` entry for your Extroot USB:

    ```bash
    eval $(block info ${DEVICE} | grep -o -e 'UUID="\S*"')
    eval $(block info | grep -o -e 'MOUNT="\S*/overlay"')
    uci -q delete fstab.extroot
    uci set fstab.extroot="mount"
    uci set fstab.extroot.uuid="${UUID}"
    uci set fstab.extroot.target="${MOUNT}"
    uci commit fstab
    ```

2.  Create an `fstab` entry for the original overlay (a crucial fail-safe):

    ```bash
    ORIG="$(block info | sed -n -e '/MOUNT="\S*\/overlay"/s/:\s.*$//p')"
    uci -q delete fstab.rwm
    uci set fstab.rwm="mount"
    uci set fstab.rwm.device="${ORIG}"
    uci set fstab.rwm.target="/rwm"
    uci commit fstab
    ```

3.  Transfer data from the original overlay to the new Extroot partition:

    ```bash
    mount ${DEVICE} /mnt
    tar -C ${MOUNT} -cvf - . | tar -C /mnt -xf -
    ```

4.  Reboot the router:

    ```bash
    reboot
    ```

**Verification:** After the reboot, check the **System $\rightarrow$ Software** page in the LuCI Admin GUI. The **Disk space** should now reflect the size of your USB drive. If you have sufficient RAM (more than 128MB), you can stop here.

---

## 🔁 Part 2: Creating a Swap File (For Low-RAM Devices)

If your router frequently runs out of RAM (e.g., a device with 128MB or less), creating a swap file on the external storage will use disk space as virtual memory to stabilize the system.

### 1. Create and Format the Swap File

1.  SSH back into your router.
2.  Run these commands to create and format the swap file. You can change `count=1024` to set the size in MB. **`1024` (1GB) is used here.**

    ```bash
    DIR="$(uci -q get fstab.extroot.target)"
    dd if=/dev/zero of=${DIR}/swap bs=1M count=1024
    mkswap ${DIR}/swap
    ```

### 2. Enable the Swap File on Boot

Configure `fstab` to ensure the swap file is activated every time the router boots:

```bash
uci -q delete fstab.swap
uci set fstab.swap="swap"
uci set fstab.swap.device="${DIR}/swap"
uci commit fstab
service fstab boot
```

### 3. Verify Swap Status
Check the active `swap` partitions to confirm the swap file is working:
```bash
cat /proc/swaps
```

## ✅ Conclusion
This setup ensures that even if your USB drive fails, OpenWrt will revert to the original overlay partition, allowing the router to boot successfully. Enjoy your expanded storage and stabilized system!
