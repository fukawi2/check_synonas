#!/bin/bash

###############################################################################
# Copyright (C) 2010-2011 Phillip Smith
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
###############################################################################

###############################################################################
# originially developed for use with synology rs212. untested with other models
###############################################################################

# nagios return values
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3  

# defaults
warn_value=80
crit_value=95

usage() {
  echo "Usage: $(basename $0) -H HOSTADDRESS -C COMMUNITY [-d DISKINDEX -w WARN -c CRIT] [-n NETINDEX]"
  echo
  echo 'DISKINDEX is the index of the disk to fetch information about. You can'
  echo 'find this information with the folowing command:'
  echo '  $ snmpwalk host.example.com -c public -v2c | grep hrStorageDescr'
  echo 'WARN and CRIT are percentages for the respective conditions. Default is 80 for warning and'
  echo '95 for critical.'
  echo
  echo 'NETINDEX is the index of the network interface to fetch information about.'
  echo 'You can find this information with the folowing command:'
  echo '  $ snmpwalk host.example.com -c public -v2c | grep ifDescr'
}

# check for dependencies
for ebin in snmpget bc ; do
  [[ -z "$(which $ebin 2>/dev/null)" ]] && { echo "UNKNOWN: Could not locate '$ebin'" >&2; exit -1; }
done

check_disk=0
check_eth=0
while getopts “hH:w:c:C:d:n:” OPTION ; do
  case $OPTION in
  h)
    usage
    exit -1
    ;;
  H)
    host_address="$OPTARG"
    ;;
  C)
    snmp_community="$OPTARG"
    ;;
  d)
    check_disk=1
    disk_index="$OPTARG"
    ;;
  n)
    check_eth=1
    eth_index="$OPTARG"
    ;;
  w)
    warn_value=$OPTARG
    ;;
  c)
    crit_value=$OPTARG
    ;;
  ?)
    usage
    exit -1
    ;;
  esac
done

# valid options supplied?
[[ -z "$snmp_community" ]] && { usage; exit -1; }
[[ $[$check_disk+$check_eth] != 1 ]] && { usage; exit -1; }

if [[ $check_disk == 1 ]] ; then
  [[ -z $warn_value ]] && { usage; exit -1; }
  [[ -z $crit_value ]] && { usage; exit -1; }
fi

snmpcmd="snmpget $host_address -v2c -c $snmp_community"

if [[ $check_disk == 1 ]] ; then
  DISKNAME=$($snmpcmd HOST-RESOURCES-MIB::hrStorageDescr.$disk_index)
  DISKSIZE=$($snmpcmd HOST-RESOURCES-MIB::hrStorageSize.$disk_index)
  DISKUSED=$($snmpcmd HOST-RESOURCES-MIB::hrStorageUsed.$disk_index)
  DISKBLOCKSIZE=$($snmpcmd HOST-RESOURCES-MIB::hrStorageAllocationUnits.$disk_index)
  DISKNAME=${DISKNAME##*STRING: }
  DISKSIZE=${DISKSIZE##*INTEGER: }
  DISKUSED=${DISKUSED##*INTEGER: }
  DISKBLOCKSIZE=${DISKBLOCKSIZE##*INTEGER: }
  DISKBLOCKSIZE=${DISKBLOCKSIZE% Bytes*}

  [[ -z $DISKSIZE ]] && { echo 'UNKNOWN: disk size not returned by server.'; exit $STATE_UNKNOWN; }
  [[ -z $DISKUSED ]] && { echo 'UNKNOWN: disk usage not returned by server.'; exit $STATE_UNKNOWN; }

  disk_pcent_used=$(echo "scale=2; ($DISKUSED / $DISKSIZE) * 100" | bc | sed s/\\.[0-9]\\+//)
  exit_code=$STATE_OK
  exit_msg='OK: ' 
  [[ $disk_pcent_used -ge $warn_value ]] && { exit_msg='WARNING: ';  exit_code=$STATE_WARNING; }
  [[ $disk_pcent_used -ge $crit_value ]] && { exit_msg='CRITICAL: '; exit_code=$STATE_CRITICAL; }

  # note that the synology appears to return "StorageSize" and "StorageUsed" in
  # blocks rather than bytes; hence we retrieve the block size ("AllocationUnits")
  # above so we can convert to (kilo|mega|giga)bytes
  disk_free_mb=$(echo "scale=2; ($DISKUSED*$DISKBLOCKSIZE)/1024/1024" | bc)

  echo "$exit_msg Disk $DISKNAME: $disk_free_mb MB used ($disk_pcent_used%)"
  exit $exit_code
fi

if [[ $check_eth == 1 ]] ; then
  ETHNAME=$($snmpcmd IF-MIB::ifDescr.$eth_index)
  ETHMTU=$($snmpcmd IF-MIB::ifMtu.$eth_index)
  ETHMAC=$($snmpcmd IF-MIB::ifPhysAddress.$eth_index)
  ETHSTATUS=$($snmpcmd IF-MIB::ifOperStatus.$eth_index)
  ETHNAME=${ETHNAME##*STRING: }
  ETHMTU=${ETHMTU##*INTEGER: }
  ETHMAC=${ETHMAC##*STRING: }
  ETHSTATUS=${ETHSTATUS##*INTEGER: }

  if [[ $ETHSTATUS == 'up(1)' ]] ; then
    exit_code=$STATE_OK
    exit_msg='OK :'
  else
    exit_code=$STATE_CRITICAL
    exit_msg='CRITICAL :'
  fi

  echo "$exit_msg Interface $ETHNAME $ETHSTATUS (MAC: $ETHMAC; MTU $ETHMTU)"
  exit $exit_code
fi

# in theory we shouldn't need this, but just in case
usage
exit -1
