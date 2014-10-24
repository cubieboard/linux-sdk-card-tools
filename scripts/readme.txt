Build sdcard image:
	1. tf card boot
	(1)cb_build_card_image (compile code to prepare cb_install_tfcard)
	(2)cb_install_tfcard  storage_medium dev_label [pack]
		storage_medium: nand tsd tfx2
		dev_label:      sdb sdc sdd ...
		pack:           the parameter mean we will make a img for dd or win32writer
		cmd for example: cb_install_tfcard tsd sdb

	2. tsd or nand card boot
	(1)cb_build_flash_card_image(compile code to prepare cb_install_flash_card)
	(2)cb_install_flash_card storage_medium dev_label [pack]
		(install TF card to flash img to tsd/emmc sdx is your sdcard label pc)
		storage_medium: nand tsd (tfx2 don`t need this mode)
		dev_label:      sdb sdc sdd ...
		pack:           the parameter mean we will make a img for dd or win32writer
		cmd for example: cb_install_flash_card tsd sdb

