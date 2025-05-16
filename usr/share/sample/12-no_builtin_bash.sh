#!/bin/sh

case ${USER} in 'user1'|'user2') ! true;; esac && return

(test -n "${BASH_VERSION}" && test -n "${ELINKS_CONFDIR-}") || return 0

enable -a 'mktemp' && enable -d 'mktemp'