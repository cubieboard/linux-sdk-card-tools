
cb_build_tf_with_recovery_img()
{
    cb_build_linux

    sudo rm -rf ${CB_OUTPUT_DIR}/recovery-part1 ${CB_OUTPUT_DIR}/recovery-part4
    mkdir -pv ${CB_OUTPUT_DIR}/recovery-part1 ${CB_OUTPUT_DIR}/recovery-part4

   # sudo tar -C ${CB_OUTPUT_DIR}/card0-part2 --strip-components=1 -zxpf ${CB_PRODUCT_ROOTFS_IMAGE}
    sudo make -C ${CB_KSRC_DIR} O=${CB_KBUILD_DIR} ARCH=arm CROSS_COMPILE=${CB_CROSS_COMPILE} -j4 INSTALL_MOD_PATH=${CB_OUTPUT_DIR}/recovery-part4 modules_install
    (cd ${CB_PRODUCT_DIR}/overlay; tar -c *) |sudo tar -C ${CB_OUTPUT_DIR}/recovery-part4  -x --no-same-owner
    (cd ${CB_OUTPUT_DIR}/recovery-part4; sudo tar -c * )|gzip -9 > ${CB_OUTPUT_DIR}/recovery-part4.tar.gz
	cat  ${CB_TOOLS_DIR}/scripts/readme.txt
	
}

cb_build_flash_recovery_img()
{
	cb_build_linux
    sudo rm -rf ${CB_OUTPUT_DIR}/card0-rootfs
    mkdir -pv ${CB_OUTPUT_DIR}/card0-rootfs
    rm -rf /tmp/tmp_${CB_PRODUCT_NAME}
	rm -rf /tmp/tmp_${CB_BOARD_NAME}
    mkdir -p /tmp/tmp_${CB_PRODUCT_NAME}
	cp	${CB_PRODUCT_ROOTFS_EXT4}	${CB_OUTPUT_ROOTFS_EXT4}
	sync
    sudo mount -o loop ${CB_OUTPUT_ROOTFS_EXT4} /tmp/tmp_${CB_PRODUCT_NAME}
    (cd /tmp/tmp_${CB_PRODUCT_NAME}; sudo tar -cp *) |sudo tar -C ${CB_OUTPUT_DIR}/card0-rootfs -xp
    sudo make -C ${CB_KSRC_DIR} O=${CB_KBUILD_DIR} ARCH=arm CROSS_COMPILE=${CB_CROSS_COMPILE} -j4 INSTALL_MOD_PATH=${CB_OUTPUT_DIR}/card0-rootfs modules_install
    (cd ${CB_PRODUCT_DIR}/overlay; tar -c *) |sudo tar -C ${CB_OUTPUT_DIR}/card0-rootfs  -x --no-same-owner
    (cd ${CB_OUTPUT_DIR}/card0-rootfs;  sudo tar -cp *) |gzip -9 > ${CB_OUTPUT_DIR}/rootfs.tar.gz
    sudo chmod 666 ${CB_OUTPUT_DIR}/rootfs.tar.gz
    sudo umount /tmp/tmp_${CB_PRODUCT_NAME}
	cat  ${CB_TOOLS_DIR}/scripts/readme.txt
}

cb_install_flash_recovery_card()
{
    local sd_dev=$1
	local pack_install="install"
	if [ $# -eq 2 ]; then
		if [ $2 = "pack" ]; then
			pack_install="pack"
		else
			echo -e "\e[0;31;1m   only support pack option now! \e[0m"
			return 1
		fi
	fi


	sizeByte=$(sudo du -sb ${CB_OUTPUT_DIR}/rootfs.tar.gz | awk '{print $1}')
	RootfsSizeKB=$(expr $sizeByte / 1000 + $CB_FLASH_TSD_ROOTFS_SIZE \* 1024 +  50 \* 1024)
	PartExt4=$(expr $RootfsSizeKB + $RootfsSizeKB / 15)
	PartSize=$(expr $PartExt4 \* 2)
	echo "PartSize=${PartSize}  sizeByte=${sizeByte}"

	if cb_sd_sunxi_flash_part $1 ${PartSize}
    then
    echo "Make sunxi partitons successfully"
    else
    echo "Make sunxi partitions failed"
    return 1
    fi

	if [ -d ${CB_PRODUCT_DIR}/configs/tsd ]; then
		CONFIG_DIR=${CB_PRODUCT_DIR}/configs/tsd
	else
		CONFIG_DIR=${CB_BOARD_DIR}/common_default/configs/tsd
	fi

    mkdir /tmp/sdc1
    sudo mount /dev/${sd_dev}1 /tmp/sdc1
    cp -v ${CB_PACKAGES_DIR}/card_flash_rootfs.tar.gz ${CB_OUTPUT_DIR}/
    cp -v ${CB_PACKAGES_DIR}/little_rootfs.tar.gz ${CB_OUTPUT_DIR}/
    sudo sync
	sudo cp -v ${CB_KBUILD_DIR}/arch/arm/boot/uImage /tmp/sdc1/
	sudo cp -v ${CONFIG_DIR}/uEnv-mmc.txt	/tmp/sdc1/uEnv.txt
    sudo fex2bin ${CONFIG_DIR}/install_sys_config.fex  /tmp/sdc1/script.bin
    sync
    sudo umount /tmp/sdc1
    rm -rf /tmp/sdc1

    if cb_sd_make_boot2 $1 $U_BOOT_WITH_SPL
    then
    echo "Build successfully"
    else
    echo "Build failed"
    return 2
    fi

    mkdir /tmp/sdc2
    sudo mount /dev/${sd_dev}2 /tmp/sdc2
    echo "mount ok"
    sudo cp -v  ${CB_OUTPUT_DIR}/rootfs.tar.gz /tmp/sdc2
    sudo mkdir -pv /tmp/sdc2/bootfs
    #part1
    sudo cp -v ${CB_KBUILD_DIR}/arch/arm/boot/uImage /tmp/sdc2/bootfs
    sudo fex2bin ${CONFIG_DIR}/sys_config.fex  /tmp/sdc2/bootfs/script.bin
    sudo cp -v ${CONFIG_DIR}/uEnv-tsd-recovery.txt /tmp/sdc2/bootfs/uEnv.txt
    sudo cp -v ${U_BOOT_WITH_SPL_MMC2} /tmp/sdc2/bootfs/u-boot.bin
    sync
    echo "part1 cp ok"
    sudo tar -C /tmp/sdc2 -xpf ${CB_OUTPUT_DIR}/card_flash_rootfs.tar.gz
	sudo cp -v ${CB_OUTPUT_DIR}/little_rootfs.tar.gz /tmp/sdc2/
    sudo cp  -v ${CONFIG_DIR}/install_recovery.sh /tmp/sdc2/bin/install.sh
    sudo chmod +x /tmp/sdc2/bin/install.sh

    sudo sync
    echo "part2 cp tar ok"
    sudo umount /tmp/sdc2
    rm -rf /tmp/sdc2

	if [ $pack_install =  "pack" ]; then
		PartSizeMB=$(expr $PartSize / 1000)
		ddSize=$(expr $PartSizeMB + 25)
		echo "ddsize=$ddSize !"
		sudo dd if=/dev/${sd_dev} of=${CB_OUTPUT_DIR}/${CB_SYSTEM_NAME}-tsd_flash.img bs=1M count=$ddSize
		sync
	fi
    return 0
}

cb_tf_with_recovery_part()
{
    local sd_dev=$1
	local part1=32
	local part2=64
	local part3=1024
	if [ -z "$sd_dev" ]; then
		echo "please input udisk label"
		return 1
	fi

	echo "if you input 32 the partition size is 32M"
    read -p "the first partition size [default 32]" part1
	if [ -z "$part1" ]; then
		part1=32
	fi

	if [ $part1 -lt 32 ]; then
		echo "the first partition size must large than 32M"
		return 1
	fi

    read -p "the second partition size [default 64]" part2
	if [ -z "$part1" ]; then
		part1=64
	fi

	if [ $part2 -lt 64 ]; then
		echo "the second partition size must large than 64M"
		return 1
	fi

    read -p "the third partition size [default 1024]" part3
	if [ -z "$part1" ]; then
		part1=1024
	fi

	if [ $part3 -lt 512 ]; then
		echo "the second partition size must large than 512M"
		return 1
	fi

	cb_sd_make_recovery_part $sd_dev  $part1 $part2 $part3
}

cb_tf_with_recovery_pack()
{
	local	STORAGE_MEDIUM=$1
	local   sd_dev=$2
	if [  $STORAGE_MEDIUM = "tfx2" ]; then
		U_BOOT_BIN=${U_BOOT_WITH_SPL_MMC2}
		else
		U_BOOT_BIN=${U_BOOT_WITH_SPL}
	fi
	echo "$U_BOOT_BIN"
	if [ -d ${CB_PRODUCT_DIR}/configs/${STORAGE_MEDIUM} ]; then
		CONFIG_DIR=${CB_PRODUCT_DIR}/configs/${STORAGE_MEDIUM}
	else
		CONFIG_DIR=${CB_BOARD_DIR}/common_default/configs/${STORAGE_MEDIUM}
	fi
    #part1
	if [ -d /tmp/sdc1 ]; then
		sudo rm -rf /tmp/sdc1
	fi

    mkdir /tmp/sdc1
    sudo mount /dev/${sd_dev}1 /tmp/sdc1
    cp -v ${CB_KBUILD_DIR}/arch/arm/boot/uImage ${CB_OUTPUT_DIR}/recovery-part1
    fex2bin ${CONFIG_DIR}/sys_config.fex ${CB_OUTPUT_DIR}/recovery-part1/script.bin
    cp -v ${CONFIG_DIR}/uEnv-mmc.txt ${CB_OUTPUT_DIR}/recovery-part1/uEnv.txt
	sudo cp ${CB_OUTPUT_DIR}/recovery-part1/* /tmp/sdc1
    sync
    sudo umount /tmp/sdc1
    rm -rf /tmp/sdc1

    #part2
	if [ -d /tmp/sdc2 ]; then
		sudo rm -rf /tmp/sdc2
	fi

	mkdir /tmp/sdc2
    sudo mount /dev/${sd_dev}2 /tmp/sdc2
	sudo tar -C /tmp/sdc2 -zxpf ${CB_RECOVERY_GZ}
	sync
	
    sudo umount /tmp/sdc2
	if [ -d /tmp/sdc2 ]; then
		sudo rm -rf /tmp/sdc2
	fi



	#part4
	if [ -d /tmp/sdc4 ]; then
		sudo rm -rf /tmp/sdc4
	fi
    mkdir /tmp/sdc4
    sudo mount /dev/${sd_dev}4 /tmp/sdc4
    sudo tar -C /tmp/sdc4 --strip-components=1 -zxpf ${CB_PRODUCT_ROOTFS_IMAGE}
    sudo tar -C /tmp/sdc4 -zxpf ${CB_OUTPUT_DIR}/recovery-part4.tar.gz
    sync

	#part3
	if [ -d /tmp/sdc3 ]; then
		sudo rm -rf /tmp/sdc3
	fi
    mkdir /tmp/sdc3
    sudo mount /dev/${sd_dev}3 /tmp/sdc3
    (cd /tmp/sdc4;  sudo tar -cp *) |gzip -9 > ${CB_OUTPUT_DIR}/rootfs.tar.gz
	sudo cp ${CB_OUTPUT_DIR}/rootfs.tar.gz /tmp/sdc3/rootfs.tar.gz

    sudo umount /tmp/sdc3
    rm -rf /tmp/sdc3

    sudo umount /tmp/sdc4
    rm -rf /tmp/sdc4

	#dd u-boot
    if cb_sd_make_boot2 $sd_dev $U_BOOT_BIN
    then
	echo "Build successfully"
    else
	echo "Build failed"
	return 2
    fi
}
