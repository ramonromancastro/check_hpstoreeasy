#!/bin/bash

# check_hpstoreeasy.sh checks HP StoreEasy Storages status.
# Copyright (C) 2019-2022  Ramón Román Castro <ramonromancastro@gmail.com>

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

set -o pipefail

### INCLUDES

. /usr/local/nagios/libexec/utils.sh

### CONSTANTES

plugin="check_hpstoreeasy.sh"
version="0.3.2"
hpe_rest="/rest/"

health_Ok=0
health_Warning=1

state_OkUp=1
state_Warning=3
state_Disconnected=6

msg_Ok='[ Ok ]'
msg_Warning='[ Warning ]'

### VARIABLES

plugin_hostname=localhost
plugin_port=49258
plugin_action=
plugin_username=admin
plugin_password=admin
plugin_verbose=

jsonResult=""

### FUNCTIONS

function my_help(){
my_version
cat << EOF

${plugin} version v${version}, Copyright (C) 2019 Ramón Román Castro
${plugin} comes with ABSOLUTELY NO WARRANTY; for details
read LICENSE.  This is free software, and you are welcome
to redistribute it under certain conditions; read LICENSE 
for details.

This plugin checks HP StoreEasy Storages based on Windows Server by querying rest API via HTTP.

Usage:
  ${plugin} -H hostname [-p port] -u username -P password -A action [-v] [-V] [-H]

Options:
  -H, --hostname STRING
  -p, --port INTEGER
  -u, --username STRING
  -P, --password STRING
  -A, --action STRING
     Availables actions: InterfaceInfo,PhysicalDisks,SystemHardwareInfo,VirtualDisks
  -v, --verbose
     Show details for command-line debugging (Nagios may truncate output)
  -V, --version
     Print version information
  -h, --help
     Print detailed help screen

Examples:
  ${plugin} -H hpstoreasy01 -u admin -P P4Ssw0rd -A PhysicalDisks
     Checks physical disks health
  ${plugin} -H hpstoreasy01 -V
     Print version information

EOF
}

function my_verbose(){
	if [ $plugin_verbose ]; then echo $1; fi
}

function my_version(){
	echo "${plugin} v${version} (rrc2software)"
}

function read_parameters(){
	if [[ $# -eq 0 ]]; then 
		my_help
		exit $STATE_UNKNOWN
	fi
	while [[ $# -gt 0 ]]; do
		key="$1"
		case $key in
			--hostname|-H)
					shift
					plugin_hostname=$1
					;;
			--port|-p)
					shift
					plugin_port=$1
					;;
			--username|-u)
					shift
					plugin_username=$1
					;;
			--password|-P)
					shift
					plugin_password=$1
					;;
			--action|-A)
					shift
					plugin_action=$1
					;;
			--verbose|-v)
					plugin_verbose=1
					;;
			--version|-V)
					my_version
					exit $STATE_OK
					;;
			--help|-h)
					my_help
					exit $STATE_OK
					;;
			*)
					echo "UNKNOWN: Unknown parameter"
					exit $STATE_UNKNOWN
					;;
		esac
		shift
	done
}

function check_PhysicalDisks(){
	my_verbose "Parsing physical disks"
	
	alerts=0
	message=""
	details=""
	state=$STATE_UNKNOWN
	
	if total=$(echo $jsonResult | jq -r .total 2>/dev/null); then
		if [ $total -gt 0 ]; then
			state=$STATE_OK
			for (( index=0; index<${total}; index++ )); do
				index_healthString=$(echo ${jsonResult} | jq -r ".members[${index}].healthStatus.stringValue")
				index_healthNumber=$(echo ${jsonResult} | jq -r ".members[${index}].healthStatus.numberValue")
				index_name=$(echo ${jsonResult} | jq -r .members[${index}].name)
				index_physicalLocation=$(echo ${jsonResult} | jq -r .members[${index}].physicalLocation)
				index_size=$(echo ${jsonResult} | jq -r .members[${index}].size)
				if [ $index_healthNumber -ne $health_Ok ]; then
					alerts=$((alerts+1));
					details+="${msg_Warning} Name: ${index_name}, location: ${index_physicalLocation}, size: ${index_size}\n"
				else
					details+="${msg_Ok} Name: ${index_name}, location: ${index_physicalLocation}, size: ${index_size}\n"
				fi
			done
			if [ $alerts -eq 0 ]; then
				message="OK: All ${total} disks are healthy"
			else
				message="WARNING: ${alerts} of ${total} disks are in warning state"
			fi
		else
			message="OK: No disks detected"
			state=$STATE_UNKNOWN
		fi
	else
		message="UNKNOWN: Error parsing json"
		state=$STATE_UNKNOWN
	fi

	echo $message
	if [ ! -z "$details" ]; then echo -e $details; fi
	if [ $alerts -ne 0 ]; then state=$STATE_WARNING; fi
	exit $state 
}

function check_VirtualDisks(){
	my_verbose "Parsing virtual disks"
	
	alerts=0
	message=""
	details=""
	state=$STATE_UNKNOWN
	
	if total=$(echo $jsonResult | jq -r .total 2>/dev/null); then
		if [ $total -gt 0 ]; then
			state=$STATE_OK
			for (( index=0; index<${total}; index++ )); do
				index_healthString=$(echo ${jsonResult} | jq -r .members[${index}].healthStatus.stringValue)
				index_healthNumber=$(echo ${jsonResult} | jq -r .members[${index}].healthStatus.numberValue)
				index_name=$(echo ${jsonResult} | jq -r .members[${index}].name)
				index_raidLevel=$(echo ${jsonResult} | jq -r .members[${index}].raidLevel)
				index_size=$(echo ${jsonResult} | jq -r .members[${index}].size)
				if [ $index_healthNumber -ne $health_Ok ]; then
					alerts=$((alerts+1));
					details+="${msg_Warning} Name: ${index_name}, RAID: ${index_raidLevel}, size: ${index_size}\n"
				else
					details+="${msg_Ok} Name: ${index_name}, RAID: ${index_raidLevel}, size: ${index_size}\n"
				fi
			done
			if [ $alerts -eq 0 ]; then
				message="OK: All ${total} virtual disks are healthy"
			else
				message="WARNING: ${alerts} of ${total} virtual disks are in warning state"
			fi
		else
			message="OK: No disks detected"
			state=$STATE_UNKNOWN
		fi
	else
		message="UNKNOWN: Error parsing json"
		state=$STATE_UNKNOWN
	fi

	echo $message
	if [ ! -z "$details" ]; then echo -e $details; fi
	if [ $alerts -ne 0 ]; then state=$STATE_WARNING; fi
	exit $state 
}

function check_InterfaceInfo(){
	my_verbose "Parsing interface info"
	
	alerts=0
	message=""
	details=""
	state=$STATE_UNKNOWN
	
	if total=$(echo $jsonResult | jq '.NetworkObjectInterfaceList | length' 2>/dev/null); then
		if [ $total -gt 0 ]; then
			state=$STATE_OK
			for (( index=0; index<${total}; index++ )); do
				index_state=$(echo ${jsonResult} | jq -r .NetworkObjectInterfaceList[${index}].State)
				index_status=$(echo ${jsonResult} | jq -r .NetworkObjectInterfaceList[${index}].Status)
				index_interfaceName=$(echo ${jsonResult} | jq -r .NetworkObjectInterfaceList[${index}].InterfaceName)
				index_interfaceDesc=$(echo ${jsonResult} | jq -r .NetworkObjectInterfaceList[${index}].InterfaceDesc)
				if [ $index_state -ne $state_OkUp ]; then
					alerts=$((alerts+1));
					details+="${msg_Warning} Name: ${index_interfaceName}, Description: ${index_interfaceDesc}\n"
				else
					details+="${msg_Ok} Name: ${index_interfaceName}, Description: ${index_interfaceDesc}\n"
				fi
			done
			if [ $alerts -eq 0 ]; then
				message="OK: All ${total} network interfaces are healthy"
			else
				message="WARNING: ${alerts} of ${total} network interfaces are in warning state"
			fi
		else
			message="OK: No network interfaces detected"
			state=$STATE_UNKNOWN
		fi
	else
		message="UNKNOWN: Error parsing json"
		state=$STATE_UNKNOWN
	fi

	echo $message
	if [ ! -z "$details" ]; then echo -e $details; fi
	if [ $alerts -ne 0 ]; then state=$STATE_WARNING; fi
	exit $state 
}

function check_SystemHardwareInfo(){
	my_verbose "Parsing system hardware info"
	
	alerts=0
	message=""
	details=""
	state=$STATE_UNKNOWN
	
	my_verbose "$jsonResult"
	if total=$(echo $jsonResult | jq '.SystemHardwareList | length' 2>/dev/null); then
		if [ $total -gt 0 ]; then
			state=$STATE_OK
			for (( index=0; index<${total}; index++ )); do
				index_state=$(echo ${jsonResult} | jq -r .SystemHardwareList[${index}].State)
				index_status=$(echo ${jsonResult} | jq -r .SystemHardwareList[${index}].Status)
				index_name=$(echo ${jsonResult} | jq -r .SystemHardwareList[${index}].Name)
				index_type=$(echo ${jsonResult} | jq -r .SystemHardwareList[${index}].Type)
				index_alert=$(echo ${jsonResult} | jq -r .SystemHardwareList[${index}].Alert)
				if [ $index_state -ne $state_OkUp ]; then
					alerts=$((alerts+1));
					details+="${msg_Warning} Name: ${index_name}, Type: ${index_type}, Alert: ${index_alert}\n"
				else
					details+="${msg_Ok} Name: ${index_name}, Type: ${index_type}\n"
				fi
			done
			if [ $alerts -eq 0 ]; then
				message="OK: All ${total} system hardware interfaces are healthy"
			else
				message="WARNING: ${alerts} of ${total} network interfaces are in warning state"
			fi
		else
			message="OK: No network interfaces detected"
			state=$STATE_UNKNOWN
		fi
	else
		message="UNKNOWN: Error parsing json"
		state=$STATE_UNKNOWN
	fi

	echo $message
	if [ ! -z "$details" ]; then echo -e $details; fi
	if [ $alerts -ne 0 ]; then state=$STATE_WARNING; fi
	exit $state 
}

function read_json(){
	my_verbose "Downloading json data from http://${plugin_hostname}:${plugin_port}${hpe_rest}${plugin_action}"
	if ! jsonResult=$(curl -s --ntlm --user ${plugin_username}:${plugin_password} http://${plugin_hostname}:${plugin_port}${hpe_rest}${plugin_action}); then
		echo "UNKNOWN: Unable to connect to server"
		exit $STATE_UNKNOWN
	fi
}

### CODE

read_parameters "$@"
read_json
case $plugin_action in
	"InterfaceInfo")
		check_InterfaceInfo
		;;
	"PhysicalDisks")
		check_PhysicalDisks
		;;
	"SystemHardwareInfo")
		check_SystemHardwareInfo
		;;
	"VirtualDisks")
		check_VirtualDisks
		;;
	*)
		echo "UNKNOWN: Invalie action"
		exit $STATE_UNKNOWN
		;;
esac
