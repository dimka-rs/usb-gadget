#/bin/sh

[ $(whoami) != "root" ] && echo "Please run as root" && exit 1

CONFIGFS=/configfs
GADGET=$CONFIGFS/usb_gadget/g1
IMAGE=/tmp/lun0.img

start() {
modprobe libcomposite
mkdir -p $CONFIGFS
mount none $CONFIGFS -t configfs

mkdir $GADGET
cd $GADGET


## Prepare FAT32 Disk
dd bs=1M count=128 if=/dev/zero of=$IMAGE
mformat -F -i $IMAGE ::
echo "Test" > /tmp/example.txt
mcopy -i $IMAGE /tmp/example.txt ::


mkdir configs/c.1
mkdir functions/mass_storage.0
echo $IMAGE > functions/mass_storage.0/lun.0/file
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
echo "" > $GADGET/UDC
rm	$GADGET/configs/c.1/mass_storage.0
rmdir 	$GADGET/configs/c.1/strings/0x409
rmdir	$GADGET/configs/c.1
rmdir --ignore-fail-on-non-empty $GADGET/functions/mass_storage.0
rmdir	$GADGET/strings/0x409

#rm -rf $CONFIGFS/usb_gadget/g1
#umount $CONFIGFS
#modprobe -r libcomposite

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
