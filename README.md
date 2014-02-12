check_synonas
=============

Script to help monitor Synology NAS via SNMP. (Nagios, Cacti etc)

USAGE
-----
check_synonas -H host.example.com -C public [-d DISKINDEX -w WARN -c CRIT] [-n NETINDEX]"

DISKINDEX is the index of the disk to fetch information about. You can find this information with the folowing command:

    $ snmpwalk host.example.com -c public -v2c | grep hrStorageDescr

WARN and CRIT are percentages for the respective conditions. Default is 80 for warning and 95 for critical.

NETINDEX is the index of the network interface to fetch information about. You can find this information with the folowing command:

    $ snmpwalk host.example.com -c public -v2c | grep ifDescr

DEPENDENCIES
-----
There are few dependencies for this script:

* bc
* snmpget; provided by net-snmp-utils (RHEL/Fedora/CentOS), snmp (Debian/Ubuntu) or net-snmp (Arch)

EXAMPLES
--------

Check the host synonas.example.com using community 'public' for free disk space on disk 32. Return warning state if disk usage is over 80 percent, or critical state if usage is over 95 percent:

    $ check_synonas -H synonas.example.com -C public -d 32
    OK:  Disk /volume1: 1069344.55 MB used (57%)

Same again, but don't warn unless the disk is very full:

    $ check_synonas -H synonas.example.com -C public -d 32 -w95 -c 99
    OK:  Disk /volume1: 1069344.55 MB used (57%)

Check the same host again for the network status of interface number 4 (in this example, a bonded interface):

    $ check_synonas -H synonas.example.com -C public -d 32
    OK : Interface bond0 up(1) (MAC: 0:11:32:ed:45:b2; MTU 1500)
