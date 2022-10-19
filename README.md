# usb-gadget

## Download

Download image: https://www.armbian.com/orange-pi-zero/
My shared folder: https://disk.yandex.ru/d/vlGMVMleu1ndrw


## Armbian docs

https://docs.armbian.com/Developer-Guide_Build-Preparation/

Must reconfigure, rebuild and install kernel.
Reconfiguration is required to support USB GADGET and CONFIGFS

## Gadget docs

* https://www.kernel.org/doc/Documentation/usb/gadget_configfs.txt
* https://gist.github.com/eballetbo/e55ac48a620476a3ec1f860947194c55
* https://wiki.tizen.org/USB/Linux_USB_Layers/Configfs_Composite_Gadget/Usage_eq._to_g_mass_storage.ko
* https://docs.kernel.org/usb/gadget_configfs.html

## armbian-config

Remember to use armbian-config to enable usbhost0 in "System -> Hardware"

## Additional packages

* mtools
* cifs-utils

## Monitoring files

### mtools

        mdir -b -i /tmp/lun0.img ::

This way we can list files and check for new ones. Listing files in a loop may be a valid approach.
**-b** flag shows long file names without extra details

### loop device + inotify

        sudo mount -o loop,offset=0,ro /tmp/lun0.img /mnt/lun0/

This way we can mount image, but it will not update us on new files. Maybe remount in a loop?

