#!/bin/bash

# con - Simple ssh connection manager.
# Copyright (c) 2010, Errol Byrd <errolbyrd@gmail.com>
# Copyright (c) 2013, Erl Cash <erl@codeward.org>

_VER="0.4"

# Configuration
HOST_FILE="$HOME/.con_tool_hosts"
SSH_ARGS="-X"
SSH_PORT=22

# File specification
# alias,127.0.0.1,22,username
DATA_DELIM=","
DATA_ALIAS=1
DATA_HADDR=2
DATA_HPORT=3
DATA_HUSER=4

# Check whether alias is set
function probe ()
{
	als=$1
	if [ "$als" == "" ]; then return 1; fi
	grep -e "^$als$DATA_DELIM" $HOST_FILE 2>&1 > /dev/null
	return $?
}

# Get data for alias
function get_raw ()
{
	als=$1
	grep -e "^$als$DATA_DELIM" $HOST_FILE 2> /dev/null
}

# Get address for the alias
function get_addr ()
{
	als=$1
	get_raw "$als" | awk -F "$DATA_DELIM" '{ print $'$DATA_HADDR' }'
}

# Get port for the alias
function get_port ()
{
	als=$1
	get_raw "$als" | awk -F "$DATA_DELIM" '{ print $'$DATA_HPORT'}'
}

# Get user for the alias
function get_user ()
{
	als=$1
	get_raw "$als" | awk -F "$DATA_DELIM" '{ print $'$DATA_HUSER' }'
}

function ssh_connect ()
{
	user=$1
	addr=$2
	port=$3
	
	ssh $SSH_ARGS $user@$addr -p $port
}

p=$(basename $0)

cmd=$1

if [ ! -f $HOST_FILE ]; then touch "$HOST_FILE"; fi

if [ $# -eq 0 ]; then
	echo -e "$p v$_VER\n\nUsage:\n\t$p <alias> [username]\n\t$p add <alias> <address>,[port],<username>\n\t$p del <alias>\n\nAliases:"
	
	cat  $HOST_FILE | while read fline;
	do
		echo $fline | awk -F "$DATA_DELIM" '{ print "\t"$1" => "$4"@"$2":"$3 }'
	done
	
	exit 0;
fi

case "$cmd" in

# Add new alias
	add )
		alias=$2
		data=($(echo $3 | awk -F "," '{ print $1" "$2" "$3 }'))
		
		if [ -z "$alias" ]; then
			echo "$p: alias is an empty string."
			exit 1
		fi
		
		if [ "$alias" == "add" ] || [ "$alias" == "del" ] || [ "$alias" == "cc" ]; then
			echo "$p: invalid alias name."
			exit 1
		fi
		
		if [ ${#data[@]} -lt 3 ]; then
			data=("${data[0]}" "$SSH_PORT" "${data[1]}")
		fi
		
		probe "$alias"
		
		if [ $? -eq 0 ]; then
			echo "$p: alias '$alias' is already in use."
			exit 1
		fi
		
		echo "$alias$DATA_DELIM${data[0]}$DATA_DELIM${data[1]}$DATA_DELIM${data[2]}" >> $HOST_FILE
		echo "$p: new alias '$alias' added."
		;;
# Delete alias
	del )
		alias=$2
		
		if [ -z "$alias" ]; then
			echo "$p: alias is an empty string."
			exit 1
		fi
		
		probe "$alias"
		
		if [ $? -eq 0 ]; then
			cat $HOST_FILE | sed '/^'$alias$DATA_DELIM'/d' > /tmp/.con.$$
			mv /tmp/.con.$$ $HOST_FILE
			echo "$p: alias '$alias' deleted."
		else
			echo "$p: unknown alias '$alias'."
		fi
		;;
# Connect to host
	* )
		alias=$1
		user=$2
		
		probe "$alias"
		
		if [ $? -eq 0 ]; then
			if [ "$user" == ""  ]; then
				user=$(get_user "$alias")
			fi

			addr=$(get_addr "$alias")
			port=$(get_port "$alias")
		
			# Use default port when parameter is missing
			if [ "$port" == "" ]; then
				port=$SSH_PORT
			fi

			echo "Connecting to '$alias' ($user@$addr:$port):"
			ssh_connect "$user" "$addr" "$port"
		else
			echo "$p: unknown alias '$alias'."
		fi
		;;
esac

exit 0
