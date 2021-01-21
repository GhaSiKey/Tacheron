#!/bin/bash

#变量
#set name variable to system username
name="$USER"
retval=""
declare -a global_ret_array
declare -a global_time_array
global_command_value=""
global_line_count=0

FILE1=/etc/tacheron/tacherontab$name
FILE2=/etc/tacheron.allow
FILE3=/etc/tacheron.deny
FILE4=/var/log/tacheron.log
FILE5=/etc/tacheron

regex=(
'^[*]$'
'^([+-]?[1-9][0-9]*|0)$'      	# 1 2 3
'^[*]/[1-9][0-9]*$'		# */5
'^([1-9][0-9]*|0)-([1-9][0-9]*|0)$'      #1-5
'^([1-9][0-9]*|0)-([1-9][0-9]*|0)/[1-9][0-9]*$' #1-5/3
'^([1-9][0-9]*|0)-([1-9][0-9]*|0)(~[0-9][0-9]*)+$'    #1-5~2~3
'^(([1-9][0-9]*|0)[,])+([1-9][0-9]*|0)$'     #1,2,3,4
'^[*](~[0-9][0-9]*)+$'  #*~2~3
)

#函数
#Creates a tempFile to store data (if one does not already exist)   ok!
function checkTempFileExists {
	
	if ! [ -d "$FILE5" ]; then
		sudo mkdir $FILE5
	fi

	if ! [ -f "$FILE1" ]; then
		sudo touch $FILE1
	fi
	if ! [ -f "$FILE2" ]; then		
		sudo touch $FILE2
	fi
	if ! [ -f "$FILE3" ]; then		
		sudo  touch $FILE3
	fi
	if ! [ -f "$FILE4" ]; then		
		sudo touch $FILE4
	fi
	sudo chmod 777 $FILE1
	sudo chmod 777 $FILE2
	sudo chmod 777 $FILE3
	sudo chmod 777 $FILE4
	sudo chmod 777 $FILE5
	line_count=$(grep "" -c $FILE2)
	if [ $line_count -eq 0 ]; then
	sudo echo $name >> $FILE2
	fi
	for ((j=1; j<($line_count+1); j++)); do
			names=`sed -n "${j}p" < $FILE2` 
			if [ $name == $names ]; then
				break;
			fi
			sudo echo $name >> $FILE2
		done

}

#计算tacherontab行数    ok!
function get_line_count {
	global_line_count=$(grep "" -c $FILE1)
	#echo $global_line_count
	return $global_line_count
}

#分解tacherontab第i行的内容 ok!
function split_line {
	line_contents=`sed -n "$1p" < $FILE1` 
	#Breaks down the full string into individual components - seconds,minute,hour,date,month,day of week.
	#IFS=' '(空格为分隔符)
	IFS=' ' read -ra array <<< "$line_contents"
	#将命令存入global_command_value
	global_command_value="${array[6]}"
	for (( y=7; y<${#array[@]}; y++ )); do
		global_command_value+=" ${array[$y]}"
	done
	global_ret_array=(${array[*]})
	#global_ret_array[0]=$((${global_ret_array[0]}*15)) #将秒位置的数字*15
}


#将date转换成array ok!
function get_and_transform_date {
	export date1=$(date +"%-S-%-M-%-H-%-d-%-m-%-w")
	IFS='-' read -ra array <<< "$date1"
	global_time_array=(${array[*]})	
	b=$(( ${global_time_array[0]} % 15 ))
	if [ $b -eq 0 ] ; then 
		global_time_array[0]=$(( ${global_time_array[0]}/15 ));
	else 
		global_time_array[0]=-1;
	fi
	#echo "${global_time_array[0]}"
}

#查看第i行此时能否运行（输入变量i）  ok!
function is_ready_to_use {
	
	if [ $global_line_count -eq 0 ]; then
		echo 'No tacherontab for' $name
	else
		
		time_measurements=("second" "minute" "hour" "day-of-the-month" "month" "day-of-the-week")
		for ((j=1; j<($global_line_count+1); j++)); do
			split_line $j   
			time=(${global_ret_array[*]})
			command_value="$global_command_value"
			flag=1;
			#echo "**********"
			for ((x=0; x<(${#time_measurements[@]}); x++)); do			
				is_ruled "${time[$x]}" "$x"		
				a=$?					
				if [ $a == 0 ] ; then 
					flag=0
					break;
				fi
			done
			#echo $flag
			if [ $flag -eq 1 ] ; then 
				date1=$(date +"%-S-%-M-%-H-%-d-%-m-%-w")
				sudo echo $date1 "come on"	$command_value >> $FILE4
				$command_value
			fi		
		done
	fi	
 	
}

#查看当前x位是否满足crontab条件（输入变量#$1某个时间块  $2时间块的位置）
function is_ruled { 
	#$1某个时间块  $2时间块的位置
	get_time_type $1
	type_of_time=$?
	get_and_transform_date;
	if [ $type_of_time -eq 0 ]; then  #*   ok!
		return 1;
	elif [ $type_of_time -eq 1 ]; then    # 12    ok!
		if [ ${global_time_array[$2]} -eq $1 ]; then
			return 1;
		else	
			return 0;
		fi
	elif [ $type_of_time -eq 2 ]; then    # */5    ok!
		IFS='/' read -ra array <<< "$1"
		b=$(( ${global_time_array[$2]} % ${array[1]} ))
		if [ $b = 0 ] ; then 
			return 1;
		else 
			return 0;
		fi
	elif [ $type_of_time -eq 3 ]; then   #1-5  ok!
		IFS='-' read -ra array <<< "$1"
		if [ ${global_time_array[$2]} -ge ${array[0]} -a ${global_time_array[$2]} -le ${array[1]} ]; then
			return 1;
		else	
			return 0;
		fi
	elif [ $type_of_time -eq 4 ]; then   #1-5/3	ok!
		IFS='/' read -ra array1 <<< "$1"
		IFS='-' read -ra array2 <<< "${array1[0]}"
		if [ ${global_time_array[$2]} -ge ${array2[0]} -a ${global_time_array[$2]} -le ${array2[1]} ]; then
			a=$(( ${global_time_array[$2]} - ${array2[0]} ))
			b=$(( ${global_time_array[$2]} % ${array[1]} ))
			if [ $b = 0 ] ; then 
				return 1;
			else 
				return 0;
			fi
		else	
			return 0;
		fi			
	elif [ $type_of_time -eq 5 ]; then    #1-5~2~3
		IFS='~' read -ra array1 <<< "$1"
		IFS='-' read -ra array2 <<< "${array1[0]}"
		if [ ${global_time_array[$2]} -ge ${array2[0]} -a ${global_time_array[$2]} -le ${array2[1]} ]; then
			for ((x1=1; x1<(${#array1[@]}); x1++)); do	
				if [ ${global_time_array[$2]} ==  ${array1[$x1]} ] ; then   
				    return 0;
				fi	
			done
			return 1;
		else 
			return 0;
		fi	
	elif [ $type_of_time -eq 6 ]; then   #1,2,3,4	
		IFS=',' read -ra array1 <<< "$1"
			for ((x1=0; x1<(${#array1[@]}); x1++)); do	
				if [ ${global_time_array[$2]} ==  ${array1[$x1]} ] ; then   
				    return 1;
				fi	
			done
		return 0;
	elif [ $type_of_time -eq 7 ]; then    #*~2~3
		IFS='~' read -ra array1 <<< "$1"
		for ((x1=1; x1<(${#array1[@]}); x1++)); do	
				if [ ${global_time_array[$2]} ==  ${array1[$x1]} ] ; then   
				    return 0;
				fi	
			done
		return 1;
	fi
}

#获取时间的类型  ok!
function get_time_type {
	integer_regex='[0-9]*'
	value="$1"
	type_of_input=-1

	for ((i=0; i<${#regex[@]}; i++)); do
		if [[ $value =~ ${regex[$i]} ]]; then
			type_of_input=$i
		fi
	done
	return ${type_of_input};
}

function have_right {
	line_count=$(grep "" -c $FILE2)
	if [ $line_count -eq 0 ]; then
		echo 'No allowed user'
	else
		for ((j=1; j<($line_count+1); j++)); do
			names=`sed -n "${j}p" < $FILE2` 
			if [ $name == $names ]; then
				echo "You have right, welcome come back."
				return 1;
			fi
		done
	fi

	line_count=$(grep "" -c $FILE3)
	if [ $line_count -eq 0 ]; then
		echo 'No denied user'
	else
		for ((j=1; j<($line_count+1); j++)); do
			names=`sed -n "${j}p" < $FILE3` 
			if [ $name == $names ]; then
				echo "You dont have right, fuck off."
				return 0;
			fi
		done
	fi

	return 0;
}


#main函数
set -f
checkTempFileExists;
have_right
if [ $? -eq 1 ]; then
	while [ true ]; do
		sleep 1
		get_line_count;
		is_ready_to_use;
	done
fi 



