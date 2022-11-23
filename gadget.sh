#!/bin/bash

### Configuration Variables ###

## Settings file
ENVFILE=/etc/gadget.env

## Default settings
ENVFILE_DEF=/etc/gadget.config.default.txt

## Current config
ENVFILE_CUR=gadget.config.current.txt

## New settings file from user
ENVFILE_NEW=gadget.config.txt

## Files to report device status locally
NETSTATUS_LOCAL_FILE=/tmp/gadget.network.txt
DMESG_LOCAL_FILE=/tmp/gadget.dmesg.txt

## Files to report device status in shared folder
DF_STATUS_FILE=gadget.df.txt
DMESG_STATUS_FILE=gadget.dmesg.txt

## Path to image file
IMAGE_FILE=/root/gadget.lun0.img

## Image size in MB
IMAGE_SIZE=2048

## in case of smb failure
FAIL_IMAGE_FILE=/tmp/gadget.lun0.img
FAIL_IMAGE_SIZE=128
SMB_STATUS=fail
SMB_FAIL_CNT=10
SMB_FAIL_DELAY=10
SMB_FAIL_DIR=SMB_ERROR

## Path to mount samba share
SMBMNT=/mnt/gadget.samba

## Update file
UPDATE_FILE=gadget.update.deb

### Code ###

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
	if [ ! -f "$IMAGE_FILE" ]; then
		dd bs=1M count=$IMAGE_SIZE if=/dev/zero of=$IMAGE_FILE
	fi
	mformat -F -i $IMAGE_FILE ::
	## Copy current or default settings
	if [ -f "$ENVFILE" ]; then
		mcopy -i $IMAGE_FILE $ENVFILE ::$ENVFILE_CUR
	else
		mcopy -i $IMAGE_FILE $ENVFILE_DEF ::
	fi
	## report error by creating dir
	if [ "$SMB_STATUS" == "fail" ]; then
		mmd -i $IMAGE_FILE ::$SMB_FAIL_DIR
	fi
	## Report network status
	ip addr > $NETSTATUS_LOCAL_FILE
	ip route >> $NETSTATUS_LOCAL_FILE
	mcopy -i $IMAGE_FILE $NETSTATUS_LOCAL_FILE ::
	## Report logs status
	dmesg > $DMESG_LOCAL_FILE
	mcopy -i $IMAGE_FILE $DMESG_LOCAL_FILE ::

	## Configure mass storage gadget
	mkdir configs/c.1
	mkdir functions/mass_storage.0
	echo $IMAGE_FILE > functions/mass_storage.0/lun.0/file
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

	echo "" > UDC
	echo "Using `ls -1 /sys/class/udc/`"
	echo `ls -1 /sys/class/udc/` > UDC
}

configure_samba()
{
	SMBCREDS=/tmp/gadget.smbcreds

	mkdir -p $SMBMNT
	echo "username=$SMBUSER" > $SMBCREDS
	echo "password=$SMBPASS" >> $SMBCREDS
	ret=1
	cnt=0
	while true
	do
		if [ "$ret" -ne 0 ]
		then
			sleep $SMB_FAIL_DELAY
			mount -v -t cifs -o rw,vers=3.0,credentials=$SMBCREDS //$SMBSRV $SMBMNT
			ret=$?
			cnt=$(( cnt + 1 ))
			if [ $cnt -ge $SMB_FAIL_CNT ]; then
				echo "Samba mount FAIL"
				break
			fi
		else
			SMB_STATUS="ok"
			echo "Samba mount OK"
			break
		fi
	done
}

sync_files()
{
	if [ "$SMB_STATUS" == "fail" ]; then
		return
	fi

	SYNCMNT=/mnt/gadget.lun0/

	## mount image
	mkdir -p $SYNCMNT
	mount -v -o loop,offset=0,ro $IMAGE_FILE $SYNCMNT

	## sync files
	rsync -av $SYNCMNT $SMBMNT

	## test if new settings present and store them
	if [ -f "$SYNCMNT/$ENVFILE_NEW" ]; then
		echo "Updating config from user!"
		cp $SYNCMNT/$ENVFILE_NEW $ENVFILE
		sync $ENVFILE
		sleep 10
		reboot
	fi

	## test if update is available
	if [ -f "$SYNCMNT/$UPDATE_FILE" ]; then
		echo "Updating package!"
		cp $SYNCMNT/$UPDATE_FILE /tmp/$UPDATE_FILE
		dpkg -i $UPDATE_FILE
		sync
		sleep 10
		reboot
	fi

	## log free space before unmounting image
	df -h > $SMBMNT/$DF_STATUS_FILE

	## unmount image
	umount $SYNCMNT

	## write logs
	dmesg > $SMBMNT/$DMESG_STATUS_FILE
}


## START

## Root required
[ $(whoami) != "root" ] && echo "Please run as root" && exit 1

## import settings
source $ENVFILE

## check smb creds
[ -z "$SMBUSER" ] && echo "SMBUSER not set in $ENVFILE" && exit 1
[ -z "$SMBPASS" ] && echo "SMBPASS not set in $ENVFILE" && exit 1
[ -z "$SMBSRV"  ] && echo "SMBSRV  not set in $ENVFILE" && exit 1

configure_samba

## use another image in case of smb failure
if [ "$SMB_STATUS" == "fail" ]; then
	IMAGE_FILE=$FAIL_IMAGE_FILE
	IMAGE_SIZE=$FAIL_IMAGE_SIZE
fi

configure_gadget

while true
do
	echo sync_files
	sync_files
	sleep 10
done

