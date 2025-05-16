#!/bin/bash
# Copyright (C) 2020-2021 Artem Slepnev, Shellgen
# License GPLv3+: GNU GPL version 3 or later.
# http://gnu.org/licenses/gpl.html



_Random() {
   declare local_ARG
   declare -i N= $@
   while (( N++ < NUM )); do
      local_ALNUM+=${local_ALPHA_NUM[RANDOM%15]}
   done
}


_Ipv6Gen() {
   IPADDR_WAN_IPV6="2002:$IP6PREFIX"

   declare local_ARG local_ALNUM

   for local_ARG in {1..5}; {
      _Random NUM='4'
      IPADDR_WAN_IPV6+=":${local_ALNUM}"
      local_ALNUM=
   }
   unset -f $FUNCNAME _Random
}


NETDEV_WAN_IPV6='sit0'

case $@ in
   'start')
      IFS=$'\n'
      _EXEC='ip'
      local_ALPHA_NUM=({0..9} {a..f})
      IPADDR_EXT_IPV4=$(ext-ip)
      STATIC_IPV6='0'
      ENABLE_WAN_IPV6='0'
      ENABLE_6TO4='1'
      NETDEV_WAN_IPV4=$(get-netdev)
      IPADDR_WAN_IPV4=$(netdev-ip)


      [[ ${IPADDR_EXT_IPV4-} ]] && {
      ((ENABLE_6TO4)) && {

      if ((!ENABLE_WAN_IPV6)); then
         if [[ -d '/proc/sys/net/ipv6/' ]]; then
            printf '0' > /proc/sys/net/ipv6/conf/all/autoconf
            printf '0' > /proc/sys/net/ipv6/conf/all/accept_ra
            printf '1' > /proc/sys/net/ipv6/conf/$NETDEV_WAN_IPV4/disable_ipv6
         fi
      fi
      ((STATIC_IPV6)) || local_IPADDR_WAN_IPV6=$IPADDR_WAN_IPV6 IPADDR_WAN_IPV6=
      [[ ${IPADDR_EXT_IPV4-} ]] && {
      IP6PREFIX=$(printf %02x%02x:%02x%02x ${IPADDR_EXT_IPV4//./$'\n'})

      if [[ $NETDEV_WAN_IPV6 == 'sit0' ]]; then
         mapfile -tn '10' -d "$IFS" NETDEV_LIST < '/proc/net/dev'
         IFS=' '
         for NETDEV in ${NETDEV_LIST[@]%:*}; {
            case $NETDEV in
               $NETDEV_WAN_IPV6)
                  GATEWAY_WAN6='::192.88.99.1'
                  NETMASK='128'
                  break
               ;;
            esac
         }
         IFS=$'\n'
      fi
      ${_EXEC} link set dev ${NETDEV_WAN_IPV6:=$NETDEV_WAN_IPV4} up
      [[ ${IPADDR_WAN_IPV6-} ]] || _Ipv6Gen
      printf '0' > /proc/sys/net/ipv6/conf/$NETDEV_WAN_IPV6/disable_ipv6
      printf '0' > /proc/sys/net/ipv6/conf/$NETDEV_WAN_IPV6/accept_ra
      printf '0' > /proc/sys/net/ipv6/conf/$NETDEV_WAN_IPV6/autoconf
      printf '0' > /proc/sys/net/ipv6/conf/$NETDEV_WAN_IPV6/max_addresses
      ${_EXEC} -6 addr add $IPADDR_WAN_IPV6/${NETMASK:=64} dev $NETDEV_WAN_IPV6
      [[ ${IPV6_ADDRCONF-} ]] \
      || ${_EXEC} -6 route add default via ${GATEWAY_WAN6:=fe80::} dev $NETDEV_WAN_IPV6 metric 1
      ${_EXEC} -6 addr del ::$IPADDR_WAN_IPV4/96 dev $NETDEV_WAN_IPV6

      [[ ${NETDEV_LAN_IPV4-} ]] && {
      [[ ${IPADDR_LAN_IPV6-} ]] || _Ipv6Gen
      ${_EXEC} -6 addr add $IPADDR_LAN_IPV6/64 dev $NETDEV_LAN_IPV4
      ((IPFWD6)) && {
      printf $IPFWD6 > /proc/sys/net/ipv6/conf/$NETDEV_LAN/forwarding
      }
      }
      }
      }
      }
   ;;
   'stop')
      : ${NETDEV_WAN_IPV6:=sit0} ${NETDEV:=$NETDEV_WAN_IPV6}
      [[ $(ip link show dev $NETDEV) == *',UP,'* ]] && {
      ip link set dev $NETDEV down
      ip addr flush dev $NETDEV
      printf '1' > /proc/sys/net/ipv6/conf/$NETDEV/disable_ipv6
      }
   ;;
esac
printf "\e[1;32m +\e[1;36m ${BASH_SOURCE[0]##*-}\e[m: \e[1;31m${@}\e[m... \e[1;33mok\e[m\n"