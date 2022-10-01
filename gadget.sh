#/bin/sh

[ $(whoami) != "root" ] && echo "Please run as root" && exit 1

CONFIGFS=/configfs


start() {
modprobe libcomposite
mount none $CONFIGFS -t configfs
 
mkdir $CONFIGFS/usb_gadget/g1
cd $CONFIGFS/usb_gadget/g1


dd bs=1M count=16 if=/dev/zero of=/tmp/lun0.img # 16MB
dd bs=1M count=16 if=/dev/zero of=/tmp/lun1.img # 16MB
mkdir configs/c.1
mkdir functions/mass_storage.0
echo /tmp/lun0.img > functions/mass_storage.0/lun.0/file
mkdir functions/mass_storage.0/lun.1
echo /tmp/lun1.img > functions/mass_storage.0/lun.1/file
mkdir strings/0x409
mkdir configs/c.1/strings/0x409
 
echo 0xa4a2 > idProduct
echo 0x0525 > idVendor
echo samsung123 > strings/0x409/serialnumber
echo Samsung > strings/0x409/manufacturer
echo "Mass Storage Gadget" > strings/0x409/product
 
echo "Conf 1" > configs/c.1/strings/0x409/configuration
echo 120 > configs/c.1/MaxPower
ln -s functions/mass_storage.0 configs/c.1

echo "Using `ls -1 /sys/class/udc/`"
echo `ls -1 /sys/class/udc/` > UDC
}

stop()
{
echo "" > $CONFIGFS/usb_gadget/g1/UDC
rm -rf $CONFIGFS/usb_gadget/g1
umount $CONFIGFS
modprobe -r libcomposite

}

usage()
{
	echo "Usage $0 start|stop"
}


case "$1" in
	start) start;;
	stop) stop ;;
	*) usage;;
esac
