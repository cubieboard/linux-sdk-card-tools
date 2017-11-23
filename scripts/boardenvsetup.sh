#!/bin/bash

cb_build_linux()
{
    if [ ! -d ${CB_KBUILD_DIR} ]; then
	mkdir -pv ${CB_KBUILD_DIR}
    fi

    echo "Start Building linux"
    cp -v ${CB_PRODUCT_DIR}/kernel_defconfig ${CB_KSRC_DIR}/arch/arm/configs/
    make -C ${CB_KSRC_DIR} O=${CB_KBUILD_DIR} ARCH=arm CROSS_COMPILE=${CB_CROSS_COMPILE} kernel_defconfig
    rm -rf ${CB_KSRC_DIR}/arch/arm/configs/kernel_defconfig
    cp -v ${CB_PRODUCT_DIR}/rootfs.cpio.gz ${CB_KBUILD_DIR}
    make -C ${CB_KSRC_DIR} O=${CB_KBUILD_DIR} ARCH=arm CROSS_COMPILE=${CB_CROSS_COMPILE} -j${CB_CPU_NUM} INSTALL_MOD_PATH=${CB_TARGET_DIR} uImage modules
    ${CB_CROSS_COMPILE}objcopy -R .note.gnu.build-id -S -O binary ${CB_KBUILD_DIR}/vmlinux ${CB_KBUILD_DIR}/bImage
    echo "Build linux successfully"
}

cb_build_clean()
{
    sudo rm -rf ${CB_OUTPUT_DIR}/*
    sudo rm -rf ${CB_BUILD_DIR}/*
}

partition_Mechanism()
{
	if [ $# -eq 2 ]; then
		if [ $2 = "pack" ];then
			pack_install="pack"
			RootfsSize=$(sudo du -sh ${CB_OUTPUT_DIR}/card0-part2 | awk '{print $1}')
			RootfsSizeMB_ADD=`echo "$RootfsSize" | cut -d M -f 1`
			RootfsSizeMB=$(expr $RootfsSizeMB_ADD + $CB_ROOTFS_SIZE)
			PartSize=$(expr $RootfsSizeMB + $RootfsSizeMB / 12 + 100)
			RootfsSizeSect=$(expr $PartSize \* 1000 \* 2)
			echo "partisionSize=$PartSize ! RootfsSize=$RootfsSizeSect !"
		    if cb_sd_sunxi_flash_part $1 ${RootfsSizeSect}
			    then
			    echo "Make sunxi partitons successfully"
			    else
			    echo "Make sunxi partitions failed"
			    return 1
		    fi
		else
			echo "parameter 2 only support pack options now"
			return 1
		fi
	else
	    if cb_sd_sunxi_part $1
	    then
		echo "Make sunxi partitons successfully"
	    else
		echo "Make sunxi partitions failed"
		return 1
	    fi
	fi
	return 0
}

cb_build_card_image()
{
    cb_build_linux

    sudo rm -rf ${CB_OUTPUT_DIR}/card0-part1 ${CB_OUTPUT_DIR}/card0-part2
    mkdir -pv ${CB_OUTPUT_DIR}/card0-part1 ${CB_OUTPUT_DIR}/card0-part2

   # sudo tar -C ${CB_OUTPUT_DIR}/card0-part2 --strip-components=1 -zxpf ${CB_PRODUCT_ROOTFS_IMAGE}
   # sudo tar -C ${CB_OUTPUT_DIR}/card0-part2 -zxpf ${CB_PRODUCT_ROOTFS_IMAGE}
	echo $CB_SYSTEM_NAME |grep -q "fedora"
	if [ $? -eq 0  ];then

		make -C ${CB_KSRC_DIR} O=${CB_KBUILD_DIR} ARCH=arm CROSS_COMPILE=${CB_CROSS_COMPILE} -j${CB_CPU_NUM} INSTALL_MOD_PATH=${CB_OUTPUT_DIR}/card0-part2/usr modules_install
		echo "this is fedora"
	else
		make -C ${CB_KSRC_DIR} O=${CB_KBUILD_DIR} ARCH=arm CROSS_COMPILE=${CB_CROSS_COMPILE} -j${CB_CPU_NUM} INSTALL_MOD_PATH=${CB_OUTPUT_DIR}/card0-part2 modules_install
	fi

    (cd ${CB_PRODUCT_DIR}/overlay; tar -c *) |sudo tar -C ${CB_OUTPUT_DIR}/card0-part2  -x --no-same-owner
    (cd ${CB_OUTPUT_DIR}/card0-part2; sudo tar -c * )|gzip -9 > ${CB_OUTPUT_DIR}/rootfs-part2.tar.gz
	cat  ${CB_TOOLS_DIR}/scripts/readme.txt
}

cb_part_install_tfcard()
{
	echo  "pack_install=$pack_install"
	if [ $# -eq 2 ]; then
		if	partition_Mechanism $2
			then
			echo "partition_Mechanism ok !"
		else
			echo "partition_Mechanism err !"
			return 1
		fi
	elif [ $# -eq 3 ]; then
		if partition_Mechanism $2 $3
			then
			echo "partition_Mechanism ok !"
		else
			echo "partition_Mechanism err !"
			return 1
		fi
	else
		echo "cb_install_tfcard storage_medium dev_label [pack]"
		echo "storage_medium: nand tsd emmc tfx2"
		echo "dev_label: sdb sdc sdd ..."
		echo "pack: the parameter mean we will make a img for dd or win32writer"
		return 1
	fi
	cat  ${CB_TOOLS_DIR}/scripts/readme.txt
}

cb_install_tfcard()
{
	local	STORAGE_MEDIUM=$1
	local   sd_dev=$2

	if [ $# -eq 3 ]; then
		if [ $3 = "pack" ];then
			pack_install="pack"
		else
			echo "parameter 2 only support pack options now"
			return 1
		fi
	else
		pack_install="install"
	fi

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
    cp -v ${CB_KBUILD_DIR}/arch/arm/boot/uImage ${CB_OUTPUT_DIR}/card0-part1
    fex2bin ${CONFIG_DIR}/sys_config.fex ${CB_OUTPUT_DIR}/card0-part1/script.bin
    cp -v ${CONFIG_DIR}/uEnv-mmc.txt ${CB_OUTPUT_DIR}/card0-part1/uEnv.txt
	sudo cp ${CB_OUTPUT_DIR}/card0-part1/* /tmp/sdc1
    sync
    sudo umount /tmp/sdc1
    rm -rf /tmp/sdc1

	#dd u-boot
    if cb_sd_make_boot2 $sd_dev $U_BOOT_BIN
    then
	echo "Build successfully"
    else
	echo "Build failed"
	return 2
    fi

    #part2
	if [ -d /tmp/sdc2 ]; then
		sudo rm -rf /tmp/sdc2
	fi

    mkdir /tmp/sdc2
    sudo mount /dev/${sd_dev}2 /tmp/sdc2
    #sudo tar -C /tmp/sdc2 -zxpf ${CB_PRODUCT_ROOTFS_IMAGE}
    sudo tar -C /tmp/sdc2 --strip-components=1 -zxpf ${CB_PRODUCT_ROOTFS_IMAGE}
    sudo tar -C /tmp/sdc2 -xpf ${CB_OUTPUT_DIR}/rootfs-part2.tar.gz
	if [ $pack_install =  "pack" ]; then
		if [ -e ${CONFIG_DIR}/firstrun ]; then
			sudo cp -v ${CONFIG_DIR}/firstrun /tmp/sdc2/etc/init.d/firstrun
			sudo chmod +x /tmp/sdc2/etc/init.d/firstrun
		fi
	fi

	echo $CB_SYSTEM_NAME |grep -q "test"

        if [ $? -eq 0  ];then
	        if [ "${STORAGE_MEDIUM}" = "nand" ];then
			sudo cp -v ${CB_PRODUCT_DIR}/cb2-test.sh  /tmp/sdc2/tools/ 
		fi

	fi
    sync
    sudo umount /tmp/sdc2
    rm -rf /tmp/sdc2

	#dd card.img for pack mode
	if [ $pack_install =  "pack" ]; then
		sizeByte=$(sudo du -sb ${CB_OUTPUT_DIR}/rootfs-part2.tar.gz | awk '{print $1}')
		if [ "${STORAGE_MEDIUM}" = "tsd" ]; then
			CONFIG_DIR=${CB_PRODUCT_DIR}/configs/tsd
			RootfsSizeKB=$(expr $sizeByte / 1000 + $CB_ROOTFS_SIZE \* 1024 +  50 \* 1024)
		elif [ "${STORAGE_MEDIUM}" = "emmc" ]; then
			CONFIG_DIR=${CB_PRODUCT_DIR}/configs/emmc
			RootfsSizeKB=$(expr $sizeByte / 1000 + $CB_ROOTFS_SIZE \* 1024 +  50 \* 1024)
		elif [ "${STORAGE_MEDIUM}" = "nand" ]; then
			RootfsSizeKB=$(expr $sizeByte / 1000 + $CB_ROOTFS_SIZE \* 1024 +  100 \* 1024)
			CONFIG_DIR=${CB_PRODUCT_DIR}/configs/nand
		else
			echo "first option only support tsd emmc nand now"
			return 1
		fi
		PartExt4=$(expr $RootfsSizeKB + $RootfsSizeKB / 15)
		PartSize=$(expr $PartExt4 )
		PartSizeMB=$(expr $PartSize / 1000)
		echo "PartSizeMB=$PartSizeMB !"
		ddSize=$(expr $PartSizeMB + $PartSizeMB / 30  + 200)
		echo "ddsize=$ddSize !"
		sudo dd if=/dev/${sd_dev} of=${CB_OUTPUT_DIR}/${CB_SYSTEM_NAME}-${STORAGE_MEDIUM}-tfcard.img bs=1M count=$ddSize
		sync
	fi

    return 0
}

cb_build_flash_card_image()
{
    cb_build_linux

    sudo rm -rf ${CB_OUTPUT_DIR}/card0-rootfs
    mkdir -pv ${CB_OUTPUT_DIR}/card0-rootfs
    sudo rm -rf /tmp/tmp_${CB_PRODUCT_NAME}
    sudo rm -rf /tmp/tmp_${CB_BOARD_NAME}
    mkdir -p /tmp/tmp_${CB_PRODUCT_NAME}
#	cp	${CB_PRODUCT_ROOTFS_EXT4}	${CB_OUTPUT_ROOTFS_EXT4}
	dd if=/dev/zero of=${CB_OUTPUT_ROOTFS_EXT4} bs=1M count=${CB_ROOTFS_SIZE}
	sync
	sudo echo y | mkfs.ext4 ${CB_OUTPUT_ROOTFS_EXT4}
    sudo mount -o loop ${CB_OUTPUT_ROOTFS_EXT4} /tmp/tmp_${CB_PRODUCT_NAME}
	sudo tar -C /tmp/tmp_${CB_PRODUCT_NAME} --strip-components=1 -zxpf ${CB_PRODUCT_ROOTFS_IMAGE}
    (cd /tmp/tmp_${CB_PRODUCT_NAME}; sudo tar -cp *) |sudo tar -C ${CB_OUTPUT_DIR}/card0-rootfs -xp
	echo $CB_SYSTEM_NAME |grep -q "fedora"
	if [ $? -eq 0  ];then
			sudo make -C ${CB_KSRC_DIR} O=${CB_KBUILD_DIR} ARCH=arm CROSS_COMPILE=${CB_CROSS_COMPILE} -j${CB_CPU_NUM} INSTALL_MOD_PATH=${CB_OUTPUT_DIR}/card0-rootfs/usr modules_install
			echo "this is fedora"
	else
		sudo make -C ${CB_KSRC_DIR} O=${CB_KBUILD_DIR} ARCH=arm CROSS_COMPILE=${CB_CROSS_COMPILE} -j${CB_CPU_NUM} INSTALL_MOD_PATH=${CB_OUTPUT_DIR}/card0-rootfs modules_install
	fi
    (cd ${CB_PRODUCT_DIR}/overlay; tar -c *) |sudo tar -C ${CB_OUTPUT_DIR}/card0-rootfs  -x --no-same-owner
    (cd ${CB_OUTPUT_DIR}/card0-rootfs;  sudo tar -cp *) |gzip -9 > ${CB_OUTPUT_DIR}/rootfs.tar.gz
    sudo chmod 666 ${CB_OUTPUT_DIR}/rootfs.tar.gz
    sudo umount /tmp/tmp_${CB_PRODUCT_NAME}
	cat  ${CB_TOOLS_DIR}/scripts/readme.txt
}


cb_part_install_flash_card()
{
	local STORAGE_MEDIUM=$1
	local sd_dev=$2

	sizeByte=$(sudo du -sb ${CB_OUTPUT_DIR}/rootfs.tar.gz | awk '{print $1}')
	if [ "${STORAGE_MEDIUM}" = "tsd" ]; then
		CONFIG_DIR=${CB_PRODUCT_DIR}/configs/tsd
		RootfsSizeKB=$(expr $sizeByte / 1000 + $CB_FLASH_TSD_ROOTFS_SIZE \* 1024 +  50 \* 1024)
	elif [ "${STORAGE_MEDIUM}" = "emmc" ]; then
		CONFIG_DIR=${CB_PRODUCT_DIR}/configs/emmc
		RootfsSizeKB=$(expr $sizeByte / 1000 + $CB_FLASH_TSD_ROOTFS_SIZE \* 1024 +  50 \* 1024)
	elif [ "${STORAGE_MEDIUM}" = "nand" ]; then
		RootfsSizeKB=$(expr $sizeByte / 1000 + $CB_FLASH_TSD_ROOTFS_SIZE \* 1024 +  100 \* 1024)
		CONFIG_DIR=${CB_PRODUCT_DIR}/configs/nand
	else
		echo "first option only support tsd emmc nand now"
		return 1
	fi
	PartExt4=$(expr $RootfsSizeKB + $RootfsSizeKB / 15)
	PartSize=$(expr $PartExt4 \* 2)
	echo "PartSize=${PartSize}  sizeByte=${sizeByte}"
	
    if cb_sd_sunxi_flash_part ${sd_dev} ${PartSize}
    then
    echo "Make sunxi partitons successfully"
    else
    echo "Make sunxi partitions failed"
    return 1
    fi
	cat  ${CB_TOOLS_DIR}/scripts/readme.txt
}

cb_install_flash_card()
{

	local STORAGE_MEDIUM=$1
	local sd_dev=$2
	local pack_install="install"
	if [ $# -eq 3 ]; then
		if [ $3 = "pack" ]; then
			pack_install="pack"
		else
			echo -e "\e[0;31;1m   only support pack option now! \e[0m"
			return 1
		fi
	fi
	if [ "${STORAGE_MEDIUM}" = "tsd" ]; then
		CONFIG_DIR=${CB_PRODUCT_DIR}/configs/tsd
	elif [ "${STORAGE_MEDIUM}" = "emmc" ]; then
		CONFIG_DIR=${CB_PRODUCT_DIR}/configs/emmc
	else
		CONFIG_DIR=${CB_PRODUCT_DIR}/configs/nand
	fi

    mkdir /tmp/sdc1
    sudo mount /dev/${sd_dev}1 /tmp/sdc1
    cp -v ${CB_PACKAGES_DIR}/card_flash_nand_rootfs.tar.gz ${CB_OUTPUT_DIR}/
    cp -v ${CB_PACKAGES_DIR}/card_flash_rootfs.tar.gz ${CB_OUTPUT_DIR}/
    sudo sync
	sudo cp -v ${CB_KBUILD_DIR}/arch/arm/boot/uImage /tmp/sdc1/
	sudo cp -v ${CONFIG_DIR}/uEnv-mmc.txt	/tmp/sdc1/uEnv.txt
    sudo fex2bin ${CONFIG_DIR}/install_sys_config.fex  /tmp/sdc1/script.bin
    sync
    sudo umount /tmp/sdc1
    rm -rf /tmp/sdc1

    if cb_sd_make_boot2 ${sd_dev} $U_BOOT_WITH_SPL
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
    #part1
    sudo mkdir -pv /tmp/sdc2/bootfs
	if [ "${STORAGE_MEDIUM}" = "tsd" -o "${STORAGE_MEDIUM}" = "emmc" ]; then
		sudo cp -v ${U_BOOT_WITH_SPL_MMC2} /tmp/sdc2/bootfs/u-boot.bin
	fi
    sudo cp -v ${CB_KBUILD_DIR}/arch/arm/boot/uImage /tmp/sdc2/bootfs
    sudo cp -v ${CONFIG_DIR}/uEnv-${STORAGE_MEDIUM}.txt /tmp/sdc2/bootfs/uEnv.txt
    sudo fex2bin ${CONFIG_DIR}/sys_config.fex  /tmp/sdc2/bootfs/script.bin
    sync
    echo "cp ok"
	if [ "${STORAGE_MEDIUM}" = "nand" ]; then
		sudo cp ${CONFIG_DIR}/sys_partition_4 /tmp/sdc2/sys_partition
		sudo tar -C /tmp/sdc2 -xpf ${CB_OUTPUT_DIR}/card_flash_nand_rootfs.tar.gz
		sudo cp ${CONFIG_DIR}/bootloader.fex /tmp/sdc2
		sudo cp ${U_BOOT_NAND}	/tmp/sdc2/bootfs/u-boot.bin
	else
		sudo tar -C /tmp/sdc2 -xpf ${CB_OUTPUT_DIR}/card_flash_rootfs.tar.gz
	fi
    sudo cp  -v ${CONFIG_DIR}/install.sh /tmp/sdc2/bin
    sudo chmod +x /tmp/sdc2/bin/install.sh

    sudo sync
    echo "tar ok"
    sudo umount /tmp/sdc2
    rm -rf /tmp/sdc2

	if [ $pack_install =  "pack" ]; then
		sizeByte=$(sudo du -sb ${CB_OUTPUT_DIR}/rootfs.tar.gz | awk '{print $1}')
		if [ "${STORAGE_MEDIUM}" = "tsd" ]; then
			CONFIG_DIR=${CB_PRODUCT_DIR}/configs/tsd
			RootfsSizeKB=$(expr $sizeByte / 1000 + $CB_FLASH_TSD_ROOTFS_SIZE \* 1024 +  50 \* 1024)
		elif [ "${STORAGE_MEDIUM}" = "emmc" ]; then
			CONFIG_DIR=${CB_PRODUCT_DIR}/configs/emmc
			RootfsSizeKB=$(expr $sizeByte / 1000 + $CB_FLASH_TSD_ROOTFS_SIZE \* 1024 +  50 \* 1024)
		elif [ "${STORAGE_MEDIUM}" = "nand" ]; then
			RootfsSizeKB=$(expr $sizeByte / 1000 + $CB_FLASH_TSD_ROOTFS_SIZE \* 1024 +  100 \* 1024)
			CONFIG_DIR=${CB_PRODUCT_DIR}/configs/nand
		else
			echo "first option only support tsd emmc nand now"
			return 1
		fi
		PartExt4=$(expr $RootfsSizeKB + $RootfsSizeKB / 15)
		PartSize=$(expr $PartExt4 \* 2)
		PartSizeMB=$(expr $PartSize / 1000)
		ddSize=$(expr $PartSizeMB + 100)
		echo "ddsize=$ddSize !"
		sudo dd if=/dev/${sd_dev} of=${CB_OUTPUT_DIR}/${CB_SYSTEM_NAME}-${STORAGE_MEDIUM}_flash.img bs=1M count=$ddSize
		sync
	fi
    return 0
}

cb_build_release()
{
	local IMG
	STORAGE_MEDIUM=$1
    if [ ! -d ${CB_RELEASE_DIR} ]; then
        mkdir -p ${CB_RELEASE_DIR}
    fi
    if [ -f ${CB_OUTPUT_DIR}/${CB_SYSTEM_NAME}-${STORAGE_MEDIUM}-tfcard*.img ]; then
        echo "copy tfcard image"
		cd ${CB_OUTPUT_DIR} ;
		IMG=(`ls  ${CB_SYSTEM_NAME}-${STORAGE_MEDIUM}*.img |sort`)
		VERSION=(`(ls |awk '{print $1}')|cut -c31-34`)
		mkdir -p ${CB_RELEASE_DIR}/${STORAGE_MEDIUM}_${VERSION}
		cd -

        cp  ${CB_OUTPUT_DIR}/${IMG} ${CB_RELEASE_DIR}/${STORAGE_MEDIUM}_${VERSION}
		(cd ${CB_RELEASE_DIR}/${STORAGE_MEDIUM}_${VERSION};gzip -c  ${IMG} >  ${IMG}.gz
        md5sum  ${IMG}.gz > ${IMG}.gz.md5
		awk 'NR == 1,NR == 3' ${CB_KSRC_DIR}/Makefile  > ${CB_RELEASE_DIR}/${STORAGE_MEDIUM}_${VERSION}/kernel_version.txt
		)
        echo "copy kernel source"
        cp ${CB_KBUILD_DIR}/.config ${CB_RELEASE_DIR}/${STORAGE_MEDIUM}_${VERSION}/${IMG}_defconfig
        (
        cd ${CB_KSRC_DIR}
        git archive --prefix kernel-source/ HEAD |gzip > ${CB_RELEASE_DIR}/${STORAGE_MEDIUM}_${VERSION}/kernel-source.tar.gz
        )
        md5sum ${CB_RELEASE_DIR}/${STORAGE_MEDIUM}_${VERSION}/kernel-source.tar.gz > ${CB_RELEASE_DIR}/${STORAGE_MEDIUM}_${VERSION}/kernel-source.tar.gz.md5
		mkdir -pv  ${CB_RELEASE_DIR}/${STORAGE_MEDIUM}_${VERSION}/config 
        cp -rv ${CB_PRODUCT_DIR}/configs/${STORAGE_MEDIUM}/* ${CB_RELEASE_DIR}/${STORAGE_MEDIUM}_${VERSION}/config
        date +%Y%m%d > ${CB_RELEASE_DIR}/${STORAGE_MEDIUM}_${VERSION}/build.log

	echo "done"
    fi
}
