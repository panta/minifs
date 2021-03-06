
TARGET_META_ARCH=armv7

TARGET_ARCH=arm
TARGET_FULL_ARCH=$TARGET_ARCH-a8-linux-uclibcgnueabi
TARGET_KERNEL_NAME=uImage
TARGET_LIBC_CFLAGS="-g -O2 -march=armv7-a -mtune=cortex-a8 -mfpu=neon -fPIC -mthumb-interwork"
TARGET_CFLAGS="$TARGET_LIBC_CFLAGS"

# this file .dts must exist either in this directory (board)
# or in the linux arch/$TARGET_ARCH/boot/dts/
TARGET_KERNEL_DTB=am335x-bone
TARGET_KERNEL_CMDLINE=${TARGET_KERNEL_CMDLINE:-"console=ttyAMA0,115200 root=/dev/mmcblk0p2 ro rootwait ssp1=mmc quiet"}

TARGET_FS_EXT=0
#TARGET_FS_TAR=0
TARGET_FS_SQUASH=1

board_set_versions() {
	TARGET_SHARED=1
	TARGET_INITRD=1

	hset linux version "3.16"
	hset linux make-extra-parameters "UIMAGE_LOADADDR=0x80008000"
}

board_prepare() {
	TARGET_PACKAGES+=" uboot"
	hset uboot url "git!http://git.denx.de/u-boot.git#uboot-omap-git.tar.bz2"
	hset uboot board "am335x_evm"
	hset uboot target "all"


	# Make sure the target tools are compiled staticaly, as we need
	# "fat_find" to run from the ramdisk
#	hset targetools ldflags "-static"

#	TARGET_PACKAGES+=" gdbserver strace catchsegv"
#	TARGET_PACKAGES+=" ethtool"
#	TARGET_PACKAGES+=" curl rsync"
#	TARGET_PACKAGES+=" openssh sshfs mDNSResponder"

#	TARGET_PACKAGES+=" i2c mtd_utils "
#	hset mtd_utils deploy-list "nandwrite mtd_debug"

	TARGET_PACKAGES+=" targettools"

#	TARGET_PACKAGES+=" update-package"
#	hset update-package basename "realfrt"

}

#
# Create a ramdisk image with just busybox and a few tools, this
# mini ramdisk is responsible for finding were the real linux distro is
# mount it and start it
#
cbstx-setup-initrd() {
	mkdir -p $BUILD/initramfs
	rm -rf $BUILD/initramfs/*
	ROOTFS_INITRD="$BUILD/initramfs"
	echo  " Building trampoline $ROOTFS_INITRD"
	(
		(
			cd $BUILD/busybox
			echo Reinstalling busybox there
			ROOTFS=$ROOTFS_INITRD
			deploy-busybox-local
		)
		mkdir -p $STAGING/static/bin
		make -C $CONF_BASE/target-tools \
			STAGING=$STAGING/static MY_CFLAGS="-static -Os -std=gnu99"\
			TOOLS="waitfor_uevent fat_find" && \
			sstrip $STAGING/static/bin/* && \
			cp $STAGING/static/bin/* \
				$ROOTFS_INITRD/bin/
	)>$BUILD/._initramfs.log
	(
		cd $BUILD/initramfs/
		## Add rootfs overrides for boards
		for pd in $(minifs_locate_config_path initramfs 1); do
			if [ -d "$pd" ]; then
				echo "### Installing initramfs $pd"
				rsync -av --exclude=._\* "$pd/" "./"
			fi
		done
	) >>$BUILD/._initramfs.log
}

#
# Copy some extra files to the firmware update location
#
cbstx-add-update-package() {
	cp $BUILD/BOOT.BIN firmware/
	cp $BUILD/device-tree.dtb firmware/
	cp ../../cbstx/fpga/fpga32.bin firmware/
}

# Adds the files we've added to the manifest file
cbstx-manifest-update-package() {
		cat <<EOF >>manifest.json
	dtb: $(md5sum device-tree.dtb | awk '{printf "{name:\"%s\",hash:\"%s\"}\n", $2,$1;}'),
	boot: $(md5sum BOOT.BIN | awk '{printf "{name:\"%s\",hash:\"%s\"}\n", $2,$1;}'),
	fpga: $(md5sum fpga32.bin | awk '{printf "{name:\"%s\",hash:\"%s\"}\n", $2,$1;}'),
EOF
}
