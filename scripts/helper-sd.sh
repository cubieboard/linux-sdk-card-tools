#!/bin/bash

CB_SD_NAME=
CB_SD_REMOVABLE=
CB_SD_SIZE=
CB_SD_MODEL=

cb_sd_list()
{
    echo "Block Device:"

for device in $(ls /dev/sd[a-z]); do
    CB_SD_NAME=`echo $device|awk -F/ '{print $3}'`
    CB_SD_SIZE=`cat /sys/block/$CB_SD_NAME/size`
    CB_SD_SIZE=$(expr $CB_SD_SIZE / 1024 / 1024 )
    CB_SD_REMOVABLE=`cat /sys/block/$CB_SD_NAME/removable`
    CB_SD_MODEL=`cat /sys/block/$CB_SD_NAME/device/model`

    printf "    $CB_SD_NAME\t$CB_SD_SIZE\t$CB_SD_REMOVABLE\t$CB_SD_MODEL\n"
done
}

cb_sd_check()
{
    local sd_dev=$1
    local full_path="/dev/$sd_dev"
    is_removable=0

    if [ ! -b "$full_path" ]; then
	echo "Invalid: $full_path"
	return 1
    fi

    if [ ! -d "/sys/block/$sd_dev" ]; then
	echo "Invalid: $sd_dev"
	return 2
    fi

    is_removable=`cat /sys/block/$sd_dev/removable`

    if [ ${is_removable} -ne "1" ]; then
	echo "is not a removable disk"
	return 3
    fi

    return 0
}

cb_sd_sunxi_part()
{
    local card="$1"
	local Part1Size=24576
    if cb_sd_check $card
    then
	echo "Cleaning /dev/$card"
    else
	return 1
    fi
	if [ $CB_BOOTFS_SIZE ]; then
		Part1Size=$(expr $CB_BOOTFS_SIZE \* 2048)
	fi
    sudo sfdisk -R /dev/$card
    sudo sfdisk --force --in-order -uS /dev/$card <<EOF
2048,${Part1Size},L
,,L
EOF

    sync
    
    sudo mkfs.ext2 /dev/${card}1
    sudo mkfs.ext4 /dev/${card}2

    return 0
}

cb_sd_sunxi_flash_part()
{
    local card="$1"
	local Part1Size=24576

    if cb_sd_check $card
    then
	echo "Cleaning /dev/$card"
    else
	return 1
    fi

	if [ $CB_BOOTFS_SIZE ]; then
		Part1Size=$(expr $CB_BOOTFS_SIZE \* 2048)
	fi

	Part2Size=$(expr $2 + $Part1Size)
	echo $Part2Size
    sudo sfdisk -R /dev/$card
    sudo sfdisk --force --in-order -uS /dev/$card <<EOF
2048,${Part1Size},L
,${Part2Size},L
EOF

   sync

    sudo mkfs.ext2 /dev/${card}1
    sudo mkfs.ext4 /dev/${card}2

    return 0
}

cb_sd_make_boot()
{
    local card="$1"
    local sunxi_spl=$2
    local sunxi_uboot=$3

    if cb_sd_check $card
    then
	echo "Check ok: /dev/$card"
    else
	return 1
    fi

    sudo dd if=$sunxi_spl of=/dev/$card bs=1024 seek=8
    sudo dd if=$sunxi_uboot of=/dev/$card bs=1024 seek=32

    return 0
}

cb_sd_make_boot2()
{
    local card="$1"
    local sunxi_uboot_with_spl=$2

    if cb_sd_check $card
    then
	echo "Check ok: /dev/$card"
    else
	return 1
    fi

    sudo dd if=$sunxi_uboot_with_spl of=/dev/$card bs=1024 seek=8

    return 0
}

cb_sd_make_recovery_part()
{
    local card="$1"
	local part1=$(expr $2 \* 2048)
	local part2=$(expr $3 \* 2048)
	local part3=$(expr $4 \* 2048)

    if cb_sd_check $card
    then
	echo "Cleaning /dev/$card"
    else
	return 1
    fi

	echo $Part2Size
    sudo sfdisk -R /dev/$card
    sudo sfdisk --force --in-order -uS /dev/$card <<EOF
2048,${part1},L
,${part2},L
,${part3},L
,,L
EOF

   sync

    sudo mkfs.ext2 /dev/${card}1
    sudo mkfs.ext4 /dev/${card}2
    sudo mkfs.ext4 /dev/${card}3
    sudo mkfs.ext4 /dev/${card}4

}
