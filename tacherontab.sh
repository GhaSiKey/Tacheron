#!/bin/bash
#变量
#set name variable to system username
name="$USER"

FILE1=/etc/tacheron/tacherontab$name
FILE2=/etc/tacheron.allow
FILE3=/etc/tacheron.deny
FILE4=/var/log/tacheron.log
FILE5=/etc/tacheron

#显示tacherontab文件 ok!
function display_crontab {
	sudo cat $FILE1	
}
function remove_crontab {
	sudo rm $FILE1	
}
function edit_crontab {
	sudo vi $FILE1
}
if [ $# -eq 0 ]; then
echo "needs argument(at least 1)"
else
	if [  $1 == "-u"   ]; then
		if [ $# -eq 3 ]; then
		
			FILE1=~/Desktop/tacheron1/tacherontab$2
			if [ $3 == "-l" ]; then
				display_crontab
			elif [ $3 == "-r" ]; then
				remove_crontab
			elif [ $3 == "-e" ]; then
				edit_crontab
			else 
				echo "cuole"
			fi
		else
			echo "wrong!! il faut dans la forme-- $ tacherontab [-u user] {-l | -r | -e} "
		fi
	elif [ $1 == "-l" ]; then
		display_crontab
	elif [ $1 == "-r" ]; then
		remove_crontab
	elif [ $1 == "-e" ]; then
		edit_crontab
	else 
		echo "wrong!! il faut dans la forme-- $ tacherontab [-u user] {-l | -r | -e} "
	fi
fi