#!/usr/bin/bash

# Sasha for GTS 12-Sep-20
# ipcalc and sipcalc must be installed on the executing host
# Script tested on CentOS 7 only
# Supports all prefixes therefore expect results such as: "Network: 172.16.64.0 172.16.72.83" in case prefix is 19

# Vars
SSHCMD="/usr/bin/ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no"
hstout="/tmp/hostname.ips"
ntwlog="/tmp/networks.log"

# List assertion
check_empty() {
  if [ -z "$1" ] ; then
    echo "List is empty, please provide a quoted list, separated with spaces, example: \"hostname1 hostname2 hostname3\""
    exit 1
  fi
}

# Iterate over all hosts from STDIN and write in $ntwlog
function get_ip() {
  for host in $1 ; do 
    $SSHCMD $host "(hostname -I | sed 's/ *$//g' | tr ' ' '|') > $hstout ; \
                    ip address | grep -E -f $hstout | awk '{print \$2}'"
  done > $ntwlog

  ntwvar=$(cat $ntwlog)
}

# Get all networks by using ipcalc, helps us calculate all kind of prefixes wihtout PITA
function get_networks() {

  gn=$(for ipaddr in $(cat $ntwlog) ; do
    ipcalc -n $ipaddr | awk -F'=' '{print $NF}'
  done)
  ntwvar=$(echo "$gn" | paste -d"," $ntwlog -)
  echo "$ntwvar" > $ntwlog

}

# Convert binary ip to decimal ip by using sipcalc, helps us with comparing ip's, otherwise a big PITA and assuming I cannot use code from stackoverflow. 
function get_decimal_ip() {

  gdi=$(for ipaddr in $(awk -F',' '{print $1}' $ntwlog) ; do
    decip=$(sipcalc $ipaddr | awk /decimal/'{print $NF}')
    echo $decip
  done)
  ntwvar=$(echo "$gdi" | paste -d"," $ntwlog -)
  echo "$ntwvar" > $ntwlog

}

# Sort by network and print lowest addresses accordingly
function sort_and_print() {

  for network in $(echo "$ntwvar" | awk -F',' '{print $2}' | sort -u ) ; do
    declowip="9999999999"
    echo -n "$network: " 
    for decip in $(echo "$ntwvar" | awk -F',' /$network/'{print $3}') ; do
      if [ $declowip -gt $decip ]; then
	declowip=$decip
	binlowip=$(awk -F'/' /$declowip/'{print $1;exit;}' $ntwlog)
      fi
    done
    echo "$binlowip"
  done

}

# Make it work
check_empty "$1"
get_ip "$1"
get_networks
get_decimal_ip
sort_and_print
