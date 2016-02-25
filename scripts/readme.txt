Build sdcard image:
	1. tf card boot
	(1)cb_build_card_image  (compile code to prepare cb_install_tfcard)
	(2)cb_part_install_tfcard storage_medium dev_label [pack]
		(if part card too many times, the card will be broken. So the it should not use the command usually)
		storage_medium: emmc
		dev_label:      sdb or sdc ... , your card device ,use it replace sdx
		pack:           the parameter mean we will make a img for dd or win32writer
		cmd for example: cb_part_install_tfcard emmc sdx

	(3)cb_install_tfcard  storage_medium dev_label [pack]
		storage_medium: emmc
		dev_label:      sdb or sdc ... , your card device ,use it replace sdx
		pack:           the parameter mean we will make a img for dd or win32writer
		cmd for example: cb_install_tfcard emmc sdx

	2. emmc card boot
	(1)cb_build_flash_card_image  (compile code to prepare cb_install_flash_card)
	(2)cb_part_install_flash_card storage_medium dev_label
		storage_medium: emmc
		dev_label:      sdb or sdc ... , your card device ,use it replace sdx
		cmd for example: cb_part_install_flash_card emmc sdx

	(3)cb_install_flash_card storage_medium dev_label [pack]
		(install TF card to flash img to emmc ,sdx is your sdcard label pc)
		storage_medium: emmc
		dev_label:      sdb or sdc ... , your card device ,use it replace sdx
		pack:           the parameter mean we will make a img for dd or win32writer
		cmd for example: cb_install_flash_card emmc sdx

