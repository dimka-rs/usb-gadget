#!/bin/bash

ENVFILE=/etc/gadget.env

## Private
IMAGE=/tmp/lun0.img
SMBMNT=/mnt/samba

configure_gadget()
{
	CONFIGFS=/configfs
	GADGET=$CONFIGFS/usb_gadget/g1

	## prepare gadget FS
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

	## Configure mass storage gadget
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

	logger "Using `ls -1 /sys/class/udc/`"
	echo `ls -1 /sys/class/udc/` > UDC
}

configure_samba()
{
	SMBCREDS=/tmp/smbcreds

	mkdir -p $SMBMNT
	echo "username=$SMBUSER" > $SMBCREDS
	echo "password=$SMBPASS" >> $SMBCREDS
	mount -t cifs -o rw,vers=3.0,credentials=$SMBCREDS //$SMBSRV $SMBMNT
}

sync_files()
{
	SYNCMNT=/mnt/lun0/

	mkdir -p $SYNCMNT
	mount -o loop,offset=0,ro $IMAGE $SYNCMNT
	rsync -aq $SYNCMNT $SMBMNT
	umount $SYNCMNT
}


## START

[ $(whoami) != "root" ] && echo "Please run as root" && exit 1

## check smb creds
source $ENVFILE
[ -z "$SMBUSER" ] && echo "SMBUSER not set in $ENVFILE" && exit 1
[ -z "$SMBPASS" ] && echo "SMBPASS not set in $ENVFILE" && exit 1
[ -z "$SMBSRV"  ] && echo "SMBSRV  not set in $ENVFILE" && exit 1

configure_gadget
configure_samba

while true
do
	sync_files
	sleep 10
done

