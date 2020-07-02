#!/bin/bash
# ------------------------------------------
# Quick and very dirty report parser:
# 1. generate an user report and export data (CSV-file)
# 2. read CSV and parse
# 3. print everything
# 4. rm CSV-file
#

LANG=C.UTF-8
LC_CTYPE="C.UTF-8"
NOW=$(date +%Y-%m-%d-%H-%M-%S)
FILE="$HOME/userReportNC_$NOW.csv"
OLDIFS=$IFS
IFS=','


if [ "$(id -u)" != "0" ]
then
        echo "ERROR: This script has to be run as root!"
        exit 1
fi

sudo -u www-data php /var/www/nextcloud/occ usage-report:generate --last-login --date-format=U >> "$FILE" 2>/dev/null
#--date-format=U means date and time in ISO 8601 format (UNIX)


# example CSV:
# userName, curren date/time, lastLogin, quota, disk usage, number of files, number of shares, number of files created, number of files read:
#
# CSV:
# "Admin","1593704202","1578164586",0,0,7,0,0,0
# "User1","1593704202","1593684865",42949672960,30812348620,7033,4,443,403
# "User2","1593704202","1576683208",37580963840,28402090387,95395,1,17164,0
# "User3","1593704285","0",1073741824,-2,0,0,0,0
# "test001","1593704202","0","","",,,1,
#
###
#
# Output after parsing:
#
# Name: Admin
# Last login: 04.01.2020 20:03:06
# Quota: 0 Gb
# Disk usage: 0,00 Gb
#
# Name: User1
# Last login: 02.07.2020 12:14:25
# Quota: 40.00 Gb
# Disk usage: 28,69 Gb
# Percent Usage: 71.72%
#
# Name: User2
# Last login: 18.12.2019 16:33:28
# Quota: 35.00 Gb
# Disk usage: 26.45 Gb
# Percent Usage: 75.57%
#
# Name: User3
# Last login: never/unknown
# Quota: 1.00 Gb
# Disk usage: is unknown
#
# Name: test001
# Last login: never/unknown
# Quota: is unknown/not set
# Disk usage: is unknown
#
#################################


if [ -r "$FILE" ] # Return true if file exists and is readable
then
        echo ""
        while read username datetime lastloginU quota diskUsage nof nosh noncf nofr # "no" means Number of
        do
		userName=$(echo $username | cut -d '"' -f 2) # remove quotes: "username"
                echo "Name: $userName"
		lastloginU0=$(echo $lastloginU | cut -d '"' -f 2) # remove quotes: "username"
		if [ $lastloginU0 -gt 0 ]
		then
			lastlogin=$(date -d @$lastloginU0 +"%d.%m.%Y %T") # convert Date time
			echo "Last login: $lastlogin" # print
		else
			echo "Last login: never/unknown" # if $lastlogin isn't greater than zero print: never/unknown
		fi
		if [ -z "$quota" ] || [ "$quota" == '""' ]
		then
			echo "Quota: is unknown/not set" # if $quota isn't greater than zero or empty print: unknown
			 let quotaNo=0
		else
			let quotaNo=$quota
			if [ $quotaNo -eq -3 ] # if $quota is equal -3 print: is unlimited
			then
                		echo "Quota: is unlimited"
			elif [ $quotaNo == -2 ]
			then
				echo "Quota: is unknown/not set." # if $quota is equal -2 print: is unknown/not set
			elif [ $quotaNo -ge 0 ]
			then
				quotaGB=$(bc <<<"scale=2;$quotaNo/1073741824.0") # (quick and dirty) convert Byte to Gigabyte
				echo "Quota: $quotaGB Gb"
                	fi
		fi
		if [ $diskUsage == '-2' ] || [ "$diskUsage" == '""' ]
		then
			echo "Disk usage: is unknown" # if $diskUsage is empty or equal -2 print: unknown
		else
			diskUsageGB=$(bc <<<"scale=2;$diskUsage/1073741824.0") # (quick and dirty) convert Byte to Gigabyte
			echo "Disk usage: $diskUsageGB Gb"
			if [ $quotaNo -gt 0 ] && [ $diskUsage -gt 0 ]
			then
				percentUsage=$(bc <<< "scale=2;(($diskUsageGB*100)/$quotaGB)") # usage in percent, only if qouta and disk usage greater than 0
				echo "Percent Usage: $percentUsage%"
			fi
		fi
	echo ""
        done < $FILE
        IFS=$OLDIFS

else

        echo "something went wrong!"
        exit 2

fi

rm $FILE # remove file
#####################
