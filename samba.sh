#!/bin/sh

MNT=/mnt/samba
CREDS=/tmp/smbcreds
USER=user
PASS=pass
SRV=FUJITSU/shared_folder


start()
{
	mkdir -p $MNT
	echo "username=$USER" > $CREDS
	echo "password=$PASS" >> $CREDS
	mount -t cifs -o rw,vers=3.0,credentials=$CREDS //$SRV $MNT

}

stop()
{
	umount $MNT
	rm $CREDS
}

usage()
{
	echo "Usage: $0 start|stop"
	exit
}

if [ $(whoami) != "root" ]; then
	echo "Please run as root"
	exit 1
fi

case "$1" in
	start)	start ;;
	stop)  	stop  ;;
	*)	usage ;;
esac

