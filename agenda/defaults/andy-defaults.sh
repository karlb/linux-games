#!/bin/bash

# 
# install.sh - Andy Defaults installation program
# Copyright (C) 2001  Andrej Cedilnik
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# 

VERSION=0.7.2
SETUP_DNS=
AGENDASEARCH=
AGENDADNS=
AGENDAIP=
AGENDAWSIP=
AGENDARUNNING=
GENERATE_FILES=
EXITSOON=
EXITVAL=0

##########################################################
# Displays text on standard output                       #
##########################################################
function echo1() {
	exitsoon
	echo $*
}

##########################################################
# Displays text on standard error                        #
##########################################################
function echo2() {
	exitsoon
	echo $* 1>&2
}

##########################################################
# Displays the version information                       #
##########################################################
function version() {
	echo2 "AndyDefaults Install Version $VERSION by Andy"
}

##########################################################
# Exit if EXITSOON set                                   #
##########################################################
function exitsoon() {
	if [ "$EXITSOON" = "true" ]
	then
		exit $EXITVAL
	fi
}

##########################################################
# Check the network connection                           #
##########################################################
function check_network() {
	if [ "$1" = "" ] 
	then
		echo2 "Usage: check_network <IP>"
		EXITSOON=true
		EXITVAL=-1
	fi
	while [ "$AGENDARUNNING" != "true" ]
	do
		echo1 -n "Checking for connection with Agenda Vr3: "
		if ping -c 2 -q $AGENDAIP 2>&1 | grep [^0]0% > /dev/null 2>&1
		then
			echo1 "found"
			AGENDARUNNING=true
		else
			echo1 "not found"
			echo1 "Start PPP communication with your Agenda Vr3 such as:"
			echo1 "/usr/sbin pppd /dev/ttyS0 $AGENDAWSIP:$AGENDAIP "\
				 "noauth nodetach debug 115200 local novj"
			echo1 -n "Press enter when done: "
			read line
		fi   
	done
}

##########################################################
# Setup rc.sysinit file                                  #
##########################################################
function setup_rc_sysinit() {
	if [ ! -f /etc/rc.d/rc.sysinit ]
	then
		echo2 "You have a strange system"
		echo2 "File /etc/rc.d/init.d/rc.sysinit does not exist"
		EXITSOON=true
		EXITVAL=-4
    else
		if cat /etc/rc.d/rc.sysinit 2>&1 | \
			grep "\/etc\/rc.d\/init.d\/tpcal start" 2>&1 >/dev/null
		then
			MODIFIED=true
		fi
		if cat /etc/rc.d/rc.sysinit 2>&1 | \
			grep "hostname -F " 2>&1 >/dev/null
		then
			MODIFIED=true
		fi
		if [ "$MODIFIED" != "" ]
		then
			echo2 "This file seems to be modified already"
			EXITSOON=true
			EXITVAL=-5
		fi
		exitsoon
		cat /etc/rc.d/rc.sysinit |\
		sed "s/^\(.*pointercal.*\)/#\1/" |\
		sed "s/^\(.*touch panel.*\)/#\1/" \
			> rc.sysinit.new
		echo "/etc/rc.d/init.d/tpcal start" >> rc.sysinit.new
		echo "hostname -F /etc/hostname" >> rc.sysinit.new
		echo "if [ -f /etc/contrast ]" >> rc.sysinit.new
		echo "then" >> rc.sysinit.new
		echo "   CONTRAST=\`cat /etc/contrast\`" >> rc.sysinit.new
		echo "   echo \"Setting contrast to: \$CONTRAST\"" >> rc.sysinit.new
		echo "   /usr/bin/fbctl -c \$CONTRAST" >> rc.sysinit.new
		echo "fi" >> rc.sysinit.new
		cp /etc/rc.d/rc.sysinit /etc/rc.d/rc.sysinit.old
		mv rc.sysinit.new /etc/rc.d/rc.sysinit
		chmod 755 /etc/rc.d/rc.sysinit
		if [ -f /etc/contrast ]
		then
			mv /etc/contrast /etc/contrast.old
		fi
		echo $CONTRAST_SETTING > /etc/contrast
	fi	
}

##########################################################
# Setup touch pannel callibration                        #
##########################################################
function setup_tpcal() {
	if [ ! -d /etc/rc.d/init.d ]
	then
		echo2 "You have a strange system"
		echo2 "Directory /etc/rc.d/init.d does not exist"
		EXITSOON=true
		EXITVAL=-3
    else
		if [ -f /etc/rc.d/init.d/tpcal ]
		then
			echo1 ""
			echo2 "File /etc/rc.d/init.d/tpcal already exists"
			echo2 "Making copy of it and make new one"
			mv /etc/rc.d/init.d/tpcal /etc/rc.d/init.d/tpcal.old
		fi
		generate_tpcal > /etc/rc.d/init.d/tpcal
		chmod 755 /etc/rc.d/init.d/tpcal
	fi	
}

##########################################################
# Setup IrDA manager                                     #
##########################################################
function setup_irmanager() {
	if [ ! -d /etc/rc.d/init.d ]
	then
		echo2 "You have a strange system"
		echo2 "Directory /etc/rc.d/init.d does not exist"
		EXITSOON=true
		EXITVAL=-3
    else
		if [ -f /etc/rc.d/init.d/irmanager ]
		then
			echo1 ""
			echo2 "File /etc/rc.d/init.d/irmanager already exists" 1>&2
		else
			generate_irmanager > /etc/rc.d/init.d/irmanager
			mkdir /etc/irda
			chmod 755 /etc/rc.d/init.d/irmanager
		fi
	fi	
}

##########################################################
# Setup GBM stuff                                        #
##########################################################
function setup_gbm() {
	if [ ! -d /etc/rc.d/init.d ]
	then
		echo2 "You have a strange system"
		echo2 "Directory /etc/rc.d/init.d does not exist"
		EXITSOON=true
		EXITVAL=-3
    else
		if [ ! -f /etc/rc.d/init.d/gbm ]
		then
			echo2 "You have a strange system"
			echo2 "File /etc/rc.d/init.d/gbm does not exists" 1>&2
			EXITSOON=true
			EXITVAL=-4
		else
			if cat /etc/rc.d/init.d/gbm 2>&1 | grep "\-\-pen" 2>&1 > /dev/null
			then
				echo1 ""
				echo2 "Seems to be already modified."
				echo1 "Skipping : "
			else
				cat /etc/rc.d/init.d/gbm | \
				sed "s/\(daemon[ \t][ \t]*\/usr\/bin\/gbm\)/\1 --pen/" > \
					/etc/rc.d/init.d/gbm.new
				mv /etc/rc.d/init.d/gbm /etc/rc.d/init.d/gbm.old
				mv /etc/rc.d/init.d/gbm.new /etc/rc.d/init.d/gbm
				chmod 755 /etc/rc.d/init.d/gbm
			fi
		fi
	fi	
}

##########################################################
# Setup passwords                                        #
##########################################################
function setup_passwords() {
	if [ ! -f /etc/passwd ]
	then
		echo2 "You have a strange system"
		echo2 "Passwords file does not exists"
		EXITSOON=true
		EXITVAL=-2
    else
		if cat /etc/passwd 2>&1 | grep "\/root:\/bin\/bash" 2>&1 >/dev/null
		then
			if cat /etc/passwd 2>&1 | \
				grep "\/default:\/bin\/bash" 2>&1 >/dev/null
			then
				echo2 "Password file already modified"
				echo1 -n "Modifying anyway:"
			fi
		fi
		cat /etc/passwd | \
		sed "s/\/root:\/bin\/sh/\/root:\/bin\/bash/" | \
		sed "s/\/default:\/bin\/sh/\/default:\/bin\/bash/" > passwd.new
		mv /etc/passwd /etc/passwd.old
		mv passwd.new /etc/passwd
	fi	
}

##########################################################
# Displays help                                          #
##########################################################
function gethelp() {
	version
	echo2 "Usage: $0 [-v|-h]"
	echo2 "	-V version"
	echo2 "	-v verbose mode"
	echo2 "	-h this help"
	echo2 " -d do DNS stuff"
	echo2 " -f only generate files"
	echo2 " -l use on old Agenda"
	exit 0
}

##########################################################
# Generates all the files                                #
##########################################################
function generate_files() {
	echo1 "--------------------------------------------"
	for a in bash_profile Xdefaults inputrc tpcal irmanager
	do
		echo1 "Generating: new.$a"
		eval generate_$a > new.$a
	done
	echo1 "--------------------------------------------"
}

##########################################################
# Generates the /etc/resolv.conf and /etc/hosts          #
##########################################################
function setupDNS() {
	if [ -f /etc/resolv.conf ] 
	then
		cp /etc/resolv.conf /etc/resolv.conf.old
	fi
	echo "search $AGENDASEARCH" > /etc/resolv.conf
	echo "nameserver $AGENDADNS" >> /etc/resolv.conf

	echo "$AGENDAIP agenda" >> /etc/hosts
	echo "$AGENDAWSIP workstation" >> /etc/hosts
}

##########################################################
# Generates the bash_profile                             #
##########################################################
function generate_bash_profile() {
	cat <<EOF
# BASH configuration file for Agenda Vr3d

# Written by Georg Lukas georg@boerde.de and modified by
# Andrej Cedilnik acedil1@csee.umbc.edu

# Set the path
PATH=/flash/local/bin:/bin:/usr/bin:/usr/X11R6/bin

USER=\`whoami\`

# if we are user, add some more path
if [ "\$USER" = "root" ]
then
	PATH=\$PATH:/sbin:/usr/sbin
fi
export PATH

# Is it non-interactive mode
# formatting of the bash tab completion
if [ "\$REMOTEHOST" = "" ] 
then
	# Fix the columns size for Agenda display
        export COLUMNS=31
        alias ls="/bin/ls -w 31 -F"
        export TERM=xterm
else
        alias ls="/bin/ls -F"
fi

# show cool bash prompt (like "vr3:~\$ ")
if [ "\$USER" = "root" ]
then
	export PS1='vr3:\${PWD##*/} # '
else
	export PS1='vr3:\${PWD##*/} $ '
fi

# nice looking ls-aliases
alias la="ls -as1"
alias ll="ls -al"
alias  l="ls -as1"

EOF
}

##########################################################
# Generates the X default                                #
##########################################################
function generate_Xdefaults() {
	cat <<EOF
Rxvt*font: 5x7
Rxvt*scrollBar: off
Rxvt*geometry: 31x17
EOF
}

##########################################################
# Generates the inputrc                                  #
##########################################################
function generate_inputrc() {
	cat <<EOF
"\e[5~" previous-history
"\e[6~" next-history
EOF
}

##########################################################
# Generates the tpcal                                    #
##########################################################
function generate_tpcal() {
	cat <<EOF
#!/bin/sh
#
# Touch Panel Callibration
#               Based on inet starter in RedHat Distrib if you can believe
#               that.
# Author:       Miquel van Smoorenburg, <miquels@drinkel.nl.mugnet.org>
#               Various folks at Red Hat.
#               Modified for usage as Touch Panel Calibration init.d script 
#               by Andrej Cedilnik <acedil1@csee.umbc.edu>
#
# description:  Touch Panel Calibration
# processname:  none
# pidfile:      none
# config:       /etc/pointercal

[ -f /usr/bin/tpcal ] || exit 0

CONFIG_FILE=/etc/pointercal
RETVAL=0

case "\$1" in
  start)
  	# echo -n "Starting Touch Panel Calibration: "
	if [ ! -e \$CONFIG_FILE ]
	then
		/usr/bin/tpcal > \$CONFIG_FILE
		RETVAL=\$?
	fi
	;;
  delete)
  	if [ -e \$CONFIG_FILE ]
	then
		rm -f \$CONFIG_FILE
		RETVAL=\$?
	fi
	;;
  *)
  	echo "Usage: tpcal {start|delete}"
	exit 1
esac

exit \$RETVAL
EOF
}

##########################################################
# Generates the irmanager                                #
##########################################################

function generate_irmanager() {
	cat <<EOF
#!/bin/sh
#
# Start irattach
#               Based on irmanager in Debian GNU/Linux Distribution
# Author:       Various folks from the world
#               Modified for usage on Agenda Vr3
#               by Andrej Cedilnik <acedil1@csee.umbc.edu>
#
# description:  IrDA Manager
# processname:  irattach
# pidfile:      /var/run/irattach.pid
# config:       /etc/irda/irmanager.conf

IRATTACH=/usr/sbin/irattach
CONFIG_FILE=/etc/irda/irmanager.conf
DEVICE="/dev/ttyS1"
DISCOVERY="-s" # if you want to become discovery mode, set "-s"
AGENDAHOSTNAME=\`hostname\`

. /etc/rc.d/init.d/functions

[ -f \$IRATTACH ] || exit 0

RETVAL=0

case "\$1" in
  start)
  	# echo -n "Starting IRManager: "
	daemon \$IRATTACH \$DEVICE \$DISCOVERY > /dev/null 2>&1
	RETVAL=\$?
	echo "\$AGENDAHOSTNAME" > /proc/sys/net/irda/devname
	echo
	[ \$RETVAL -eq 0 ] && touch /var/lock/subsys/irmanager
	;;
  stop)
  	# echo -n "Stopping IRManager: "
	killproc irattach
	RETVAL=\$?
	echo 
	[ \$RETVAL -eq 0 ] && rm -f /var/lock/subsys/irmanager
	;;
  status)
  	status irattach
	RETVAL=\$?
	;;
  restart|reload)
  	\$0 stop; \$0 start
	RETVAL=\$?
	;;
  *)
  	echo "Usage: irmanager {start|stop|status|restart|reload}"
	exit 1
esac

exit \$RETVAL
EOF
}

##########################################################
# Parse the command line arguments                       #
##########################################################
while getopts hvVdfl opt
do
	case "$opt" in
		v) verbose=true ;;
		h) gethelp;;
		d) SETUP_DNS=true;;
		V) version
		   exit 0;;
		f) GENERATE_FILES=true;;
		l) oldagenda=true;;
	esac
done

shift $(($OPTIND - 1))

version
##########################################################
# Check if the host is Agenda                            #
##########################################################
if uname -a 2>&1 | grep "Linux.*mips unknown" > /dev/null 2>&1
then
	WORKINGON=agenda
else
	WORKINGON=workstation
fi

if [ "$GENERATE_FILES" != "" ]
then
	echo1 "I will only generate the files now:"
	generate_files
	EXITSOON=true
fi

echo2 "This script can potentially make your system useless."
echo2 "If the script exits before saying \"All done.\" something went wrong."
echo2 "That is usually the result of using an old or incompatible system"
echo2 "on your Agenda Vr3."
echo1 -n "Are you sure you want to continue? (yes|No) : "

read line lala
if [ "$line" != "yes" -a "$line" != "Yes" -a "$line" != "YES" ]
then
	echo1 "Exiting..."
	exit
fi

echo1 "Please answer some questions."
if [ "$AGENDAIP" = "" ]
then
	echo1 -n "Agenda side IP (10.1.1.3): "
	read AGENDAIP
	if [ "$AGENDAIP" = "" ]
	then
		AGENDAIP="10.1.1.3"
	fi
fi

if [ "$AGENDAWSIP" = "" ] 
then
	echo1 -n "Workstation side IP (10.1.1.2): "
	read AGENDAWSIP
	if [ "$AGENDAWSIP" = "" ] 
	then
		AGENDAWSIP="10.1.1.2"
	fi
fi

if [ "$WORKINGON" != "agenda" ]
then
	check_network $AGENDAIP
	echo1 -n "Copying the Andy Defaults to your Agenda Vr3 : "
	if [ "$oldagenda" = "true" ]
	then
		TAG=vr3
	else
		TAG=root
	fi
	rsync install.sh $AGENDAIP::$TAG/root/install_andy_defaults.sh \
		> /dev/null 2>&1
		
	if [ "$?" != "0" ]
	then
		echo1 " not done: $?"
		echo2 "There was an error copying the install file to your Agenda Vr3"
		EXITSOON=true
		EXITVAL=-1
    	fi
	echo1 "done"
	echo1 -n "Copying the Linus voice to your Agenda Vr3 : "
	rsync linux.au $AGENDAIP::root/root/linux.au \
		>/dev/null 2>&1
	if [ "$?" != "0" ]
	then
		echo1 " not done"
		echo2 "There was an error copying the Linus voice file to your Agenda Vr3"
		EXITSOON=true
		EXITVAL=-1
    	fi
	echo1 "done"
	echo1 "You should now telnet to your Agenda Vr3 and run the instalation"
	echo1 "script there. You do that like this:"
	echo1 "ws% telnet $AGENDAIP"
	echo1 "Trying 10.1.1.3..."
	echo1 "Connected to 10.1.1.3."
	echo1 "Escape character is '^]'."
	echo1 "Password: <press enter>"
	echo1 "Login incorrect"
	echo1 ""
	echo1 "(none) login: <type root>"
	echo1 "Password: <type agenda>"
	echo1 "vr3% bash install_andy_defaults.sh"
	echo1 ""
	echo1 "Then follow instructions on Agenda Vr3"
	echo1 ""
	echo1 "All done on the workstation"
	EXITSOON=true
	EXITVAL=0
else
	USER=`whoami`
	if [ "$USER" != "root" ] 
	then
		echo2 "You should be root when running this script"
		echo2 "Type: su - "
		echo2 "enter your root password, and start the script again"
		EXITSOON=true
		EXITVAL=1
	fi
fi

if [ -f /etc/hostname ]
then
	AGENDAHOSTNAME=`cat /etc/hostname`
fi

while [ "$AGENDAHOSTNAME" = "" ]
do
	echo1 -n "Your hostname (Agenda): " 
	read AGENDAHOSTNAME
	if [ "$AGENDAHOSTNAME" = "" ] 
	then
		AGENDAHOSTNAME="Agenda"
	fi
done

if [ "$SETUP_DNS" = "true" ]
then
	while [ "$AGENDADNS" = "" ]
	do 
		echo1 -n "Your primary name server: "
		read AGENDADNS
	done

	while [ "$AGENDASEARCH" = "" ] 
	do 
		echo1 -n "Your domain name: "
		read AGENDASEARCH
	done
fi


echo1 -n "Do you want to change root password? (yes|No): "
read line lala
if [ "$line" = "yes" -o "$line" = "Yes" -o "$line" = "YES" ]
then
	if [ -f /usr/bin/passwd ]
	then
		passwd root
	else
		echo2 "You have a strange system"
		echo2 "File /usr/bin/passwd does not exist"
		EXITSOON=true
		EXITVAL=-4
	fi		
fi

echo1 -n "Do you want to kill syslog? (yes|No): "
read line lala
if [ "$line" = "yes" -o "$line" = "Yes" -o "$line" = "YES" ]
then
	if [ -f /etc/rc.d/rc3.d/S30syslog ] 
	then
		mv /etc/rc.d/rc3.d/S30syslog /etc/rc.d/rc3.d/s30syslog
	fi
	if [ -f /etc/rc.d/rc5.d/S30syslog ] 
	then
		mv /etc/rc.d/rc5.d/S30syslog /etc/rc.d/rc5.d/s30syslog
	fi
fi

CONTRAST_SETTING=109
echo1 -n "What is your favorite contrast setting? (109): "
read line lala
if [ "$line" != "" ]
then
	CONTRAST_SETTING=$line
fi

DATESET=
date 1234567
while [ "$DATESET" = "" ]
do
	echo1 -n "Please enter the current date and time (MMDDhhmm):"
	read line
	if date $line > /dev/null 2>&1
	then
		DATESET=true
	fi
done

DATESET=
while [ "$DATESET" = "" ]
do
	echo1 -n "Please enter the current year (CCYY):"
	read line
	NEWDATE=$(date "+%m%d%H%M")$line
	#echo $NEWDATE
	if date $NEWDATE > /dev/null 2>&1 
	then
		echo1 "Date set to $(date)"
		echo1 "If this is not correct, run date applet"
		/sbin/hwclock --utc --systohc
		DATESET=true
	fi
done

echo1 -n "Create the /etc/hostname file : "
if [ -f /etc/hostname ]
then
	echo1 ""
	echo2 "File /etc/hostname already exists"
else
	echo $AGENDAHOSTNAME > /etc/hostname
fi
echo1 "done"

for a in root home/default
do
	USERNAME=`echo $a | sed "s/.*\///"`
	echo1 -n "Setting up for $USERNAME : "	
	if [ ! -d /flash/$a ]
	then
		echo2 "You have a strange system"
		echo2 "Directory $a does not exists"
		EXITSOON=true
		EXITVAL=-3
	fi
	for file in bash_profile inputrc
	do
		if [ -f /flash/$a/.$file ] 
		then
			echo1 ""
			echo2 "File /flash/$a/.$file already exists"
		else
			eval generate_$file > /flash/$a/.$file
		fi
	done
	if [ -f /flash/$a/.bashrc ]
	then
		echo1 ""
		echo2 "File /flash/$a/.bashrc already exists"
	else
		ln -s /flash/$a/.bash_profile /flash/$a/.bashrc
	fi
	if [ "$USERNAME" != "root" ]
	then
		chown $USERNAME.users /flash/$a/.bash_profile /flash/$a/.bashrc
		chown $USERNAME.users /flash/$a/.inputrc
    fi
	if [ "$USERNAME" = "default" ]
	then
	    if [ -f /flash/$a/.Xdefaults ]
		then
			echo1 ""
			echo2 "File /flash/$a/.Xdefaults already exists"
			echo2 "Make copy to /flash/$a/.Xdefaults.old and make new one"
			mv /flash/$a/.Xdefaults /flash/$a/.Xdefaults.old \
				> /dev/null 2>&1 
		fi
		generate_Xdefaults > /flash/$a/.Xdefaults
		chown $USERNAME.users /flash/$a/.Xdefaults
	fi
	echo "done"
done

echo1 -n "Modifying passwords file : "
setup_passwords
echo1 "done"

echo1 -n "Setting up fast Touch Panel Calibration : "
setup_tpcal
echo1 "done"

## This is not used any more
#echo1 -n "Setting up fast GBM stuff : "
#setup_gbm
#echo1 "done"

## This appeared on the romdisk, so I will throw it out
#echo1 -n "Setting up IrDA Manager : "
#setup_irmanager
#echo1 "done"

if [ "$SETUP_DNS" != "" ]
then
	echo1 -n "Setting up DNS stuff : "
	setupDNS
	echo1 "done"
fi

echo1 -n "Modify the /etc/rc.d/rc.sysinit file : "
setup_rc_sysinit
echo1 "done"

echo1 -n "Fix /dev/dsp: "
chmod 666 /dev/dsp > /dev/null 2>&1 
if [ "$?" = "0" ]
then
	echo1 "done"
else
	echo1 "fail"
	echo2 "You should check your setup"
fi

echo1 -n "Setting up Linux.au : "
if [ ! -d /usr/local/sounds ]
then
	mkdir /usr/local/sounds > /dev/null 2>&1 
	mv /root/linux.au /usr/local/sounds> /dev/null 2>&1 
fi
if [ "$?" = "0" ]
then
	echo1 "done"
else
	echo1 "fail"
	echo2 "Could not move the \"linux.au\" file"
fi

if [ -f /etc/release ]
then
	LINE=`cat /etc/release`
	echo "$LINE - Andy Defaults $VERSION <me@andy.cx>" > /etc/release
fi

echo1 "All done. The system is updated"
echo1 "Press any key to restart"
read line
/sbin/reboot
