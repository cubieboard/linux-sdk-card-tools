--------------------------------------------------------------


        * Building Micro-sd Card Image Step: 
        0.Insert Micro-sd Card into host PC 
        !!!!! WARNNING !!!!!
        The below steps will format your Micro-sd Card 
	Please make sure your Micro-sd Card label 
        $ sudo fdisk -l 
        $ sudo umount /dev/sdx 

        1.Micro-sd Card Image packing:
        (1)$ cb_build_card_image
        (2)$ cb_part_install_tfcard nand/tfx2/tsd sdx pack 
        (3)$ cb_install_tfcard nand/tfx2/tsd sdx [pack]

	2.Micro-sd Card flash TSD: 
	(1)$ cb_build_flash_card_image 
        (2)$ cb_part_install_flash_card tsd sdx 
	(3)$ cb_install_flash_card tsd sdx [pack]

        
        * Explanation of parameters
        - nand:   Nand flash storage version for cbs 
        - tfx2:   Cubieboard2-dualcard version 
        - tsd:    Tsd flash storage version for cbs 
        - sdx:    Micro-sd Card label on host PC 
        - pack:   Calculation Micro-sd Card  partition size
        - [pack]: Optional parameters,backup and release image

 
        * Building example for nand version Micro-sd Card Image 
        $ cb_build_card_image
        $ cb_part_install_tfcard nand pack 
        $ cb_install_tfcard nand sdc 
                
-----------------------------------------------------------------
