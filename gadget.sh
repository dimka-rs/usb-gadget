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
JOURNAL_LOCAL_FILE=/tmp/gadget.journal.txt

## Files to report device status in shared folder
DF_STATUS_FILE=gadget.df.txt
DMESG_STATUS_FILE=gadget.dmesg.txt

## Path to image file
IMAGE_FILE=/root/gadget.lun0.img

## Image size in MB
IMAGE_SIZE=2048

## How often check for new files, seconds
SYNC_INTERVAL=10

## in case of smb failure
FAIL_IMAGE_FILE=/tmp/gadget.lun0.img
FAIL_IMAGE_SIZE=128
SMB_STATUS=fail
SMB_FAIL_CNT=3
SMB_FAIL_DELAY=5
SMB_FAIL_DIR=SMB_ERROR

## Path to mount samba share
SMBMNT=/mnt/gadget.samba

## Update file
UPDATE_FILE=gadget.update.deb

##  LEDS
LED_GREEN=/sys/class/leds/orangepi\:green\:pwr
LED_RED=/sys/class/leds/orangepi\:red\:status

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
	## Report journal
	journalctl -u gadget > $JOURNAL_LOCAL_FILE
	mcopy -i $IMAGE_FILE $JOURNAL_LOCAL_FILE ::

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
	mkdir -p $SMBMNT
	ret=1
	cnt=0
	while true
	do
		if [ "$ret" -ne 0 ]
		then
			sleep $SMB_FAIL_DELAY
			## note: 'guest' arg should work, but it does not
			mount -v -t cifs -o rw,vers=3.0,user=$SMBUSER,pass=$SMBPASS //$SMBSRV $SMBMNT
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
	SYNCMNT=/mnt/gadget.lun0/

	## mount image
	mkdir -p $SYNCMNT
	mount -v -o loop,offset=0,ro $IMAGE_FILE $SYNCMNT

	## sync files and update logs if share is mounted
	if [ "$SMB_STATUS" == "ok" ]; then
		rsync -av $SYNCMNT $SMBMNT
		## log free space
		df -h > $SMBMNT/$DF_STATUS_FILE
		## write logs
		dmesg > $SMBMNT/$DMESG_STATUS_FILE
	fi

	## test if new settings present and store them
	if [ -s "$SYNCMNT/$ENVFILE_NEW" ]; then
		## indicate update
		echo default-on > $LED_RED/trigger
		echo "Updating config from user!"
		cp $SYNCMNT/$ENVFILE_NEW $ENVFILE
		sync $ENVFILE
		sleep 10
		reboot
	fi

	## test if update is available
	if [ -s "$SYNCMNT/$UPDATE_FILE" ]; then
		## indicate update
		echo default-on > $LED_RED/trigger
		echo "Updating package!"
		cp $SYNCMNT/$UPDATE_FILE /tmp/$UPDATE_FILE
		dpkg -i /tmp/$UPDATE_FILE
		sync
		sleep 10
		reboot
	fi

	## unmount image
	umount $SYNCMNT
}


## START

## Root required
[ $(whoami) != "root" ] && echo "Please run as root" && exit 1

## Default LEDs state
echo default-on > $LED_GREEN/trigger
echo none > $LED_RED/trigger

## import settings
if [ -f $ENVFILE ]; then
	source $ENVFILE
fi

## check smb creds
if [ -n "$SMBSRV"  ]; then
	configure_samba
else
	echo "Wrong samba configuration"
	echo "SMBUSER=$SMBUSER"
	echo "SMBPASS=$SMBPASS"
	echo "SMBSRV=$SMBSRV"
fi

## use another image in case of smb failure
if [ "$SMB_STATUS" == "fail" ]; then
	IMAGE_FILE=$FAIL_IMAGE_FILE
	IMAGE_SIZE=$FAIL_IMAGE_SIZE
fi

configure_gadget

while true
do
	sync_files
	sleep $SYNC_INTERVAL
done

