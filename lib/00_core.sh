#!/bin/bash

# Purpose: Provide some basic functions
# Author : Anh K. Huynh
# License: Fair license (http://www.opensource.org/licenses/fair)
# Source : http://github.com/icy/pacapt/

# Copyright (C) 2010 - 2014 Anh K. Huynh
#
# Usage of the works is permitted provided that this instrument is
# retained with the works, so that any entity that uses the works is
# notified of this instrument.
#
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

_error() {
  echo >&2 "Error: $*"
  return 1
}

_die() {
  echo >&2 "$@"
  exit 1
}

_not_implemented() {
  echo >&2 "${_PACMAN}: '${_POPT}:${_SOPT}:${_TOPT}' operation is invalid or not implemented."
  return 1
}

_removing_is_dangerous() {
  echo >&2 "${_PACMAN}: removing with '$*' is too dangerous"
  return 1
}

# Detect package type from /etc/issue
# FIXME: Using new `issue` file (location)
_issue2pacman() {
  local _pacman

  _pacman="$1"; shift

  # The following line is added by Daniel YC Lin to support SunOS.
  #
  #   [ `uname` = "$1" ] && _PACMAN="$_pacman" && return
  #
  # This is quite tricky and fast, however I don't think it works
  # on Linux/BSD systems. To avoid extra check, I slightly modify
  # the code to make sure it's only applicable on SunOS.
  #
  [[ "$(uname)" == "SunOS" ]] && _PACMAN="$_pacman" && return

  $GREP -qis "$@" /etc/issue \
  && _PACMAN="$_pacman" && return

  $GREP -qis "$@" /etc/os-release \
  && _PACMAN="$_pacman" && return
}

# Detect package type
_PACMAN_detect() {
  _issue2pacman sun_tools "SunOS" && return
  _issue2pacman pacman "Arch Linux" && return
  _issue2pacman dpkg "Debian GNU/Linux" && return
  _issue2pacman dpkg "Ubuntu" && return
  _issue2pacman cave "Exherbo Linux" && return
  _issue2pacman yum "CentOS" && return
  _issue2pacman yum "Red Hat" && return
  _issue2pacman yum "Fedora" && return
  _issue2pacman zypper "SUSE" && return
  _issue2pacman pkg_tools "OpenBSD" && return
  _issue2pacman pkg_tools "Bitrig" && return

  [[ -z "$_PACMAN" ]] || return

  # Prevent a loop when this script is installed on non-standard system
  if [[ -x "/usr/bin/pacman" ]]; then
    $GREP -q "$FUNCNAME" '/usr/bin/pacman' >/dev/null 2>&1
    [[ $? -ge 1 ]] && _PACMAN="pacman" \
    && return
  fi

  [[ -x "/usr/bin/apt-get" ]] && _PACMAN="dpkg" && return
  [[ -x "/usr/bin/cave" ]] && _PACMAN="cave" && return
  [[ -x "/usr/bin/yum" ]] && _PACMAN="yum" && return
  [[ -x "/opt/local/bin/port" ]] && _PACMAN="macports" && return
  [[ -x "/usr/bin/emerge" ]] && _PACMAN="portage" && return
  [[ -x "/usr/bin/zypper" ]] && _PACMAN="zypper" && return
  [[ -x "/usr/sbin/pkg" ]] && _PACMAN="pkgng" && return
  # make sure pkg_add is after pkgng, FreeBSD base comes with it until converted
  [[ -x "/usr/sbin/pkg_add" ]] && _PACMAN="pkg_tools" && return
  [[ -x "/usr/sbin/pkgadd" ]] && _PACMAN="sun_tools" && return

  command -v brew >/dev/null && _PACMAN="homebrew" && return

  return 1
}

# Translate -w option. Please note this is only valid when installing
# a package from remote, aka. when '-S' operation is performed.
_translate_w() {

  echo "$_EOPT" | $GREP -q ":w:" || return 0

  local _opt=
  local _ret=0

  case "$_PACMAN" in
  "dpkg")     _opt="-d";;
  "cave")     _opt="-f";;
  "macports") _opt="fetch";;
  "portage")  _opt="--fetchonly";;
  "zypper")   _opt="--download-only";;
  "pkgng")    _opt="fetch";;
  "yum")     _opt="--downloadonly";
    if ! rpm -q 'yum-downloadonly' >/dev/null 2>&1; then
      _error "'yum-downloadonly' package is required when '-w' is used."
      _ret=1
    fi
    ;;

  *)
    _opt=""
    _ret=1

    _error "$_PACMAN: Option '-w' is not supported/implemented."
    ;;
  esac

  echo $_opt
  return "$_ret"
}

# Translate the --noconfirm option.
# FIXME: does "yes | pacapt" just help?
_translate_noconfirm() {

  echo "$_EOPT" | $GREP -q ":noconfirm:" || return 0

  local _opt=
  local _ret=0

  case "$_PACMAN" in
  # FIXME: Update environment DEBIAN_FRONTEND=noninteractive
  # FIXME: There is also --force-yes for a stronger case
  "dpkg")   _opt="--yes";;
  "yum")    _opt="--assumeyes";;
  # FIXME: pacman has 'assume-yes' and 'assume-no'
  # FIXME: zypper has better mode. Similar to dpkg (Debian).
  "zypper") _opt="--no-confirm";;
  "pkgng")  _opt="-y";;
  *)
    _opt=""
    _ret=1
    _error "$_PACMAN: Option '--noconfirm' is not supported/implemented."
    ;;
  esac

  echo $_opt
  return $_ret
}

_translate_all() {
  local _args=""

  _args="$(_translate_w)" || return 1
  _args="$_args $(_translate_noconfirm)" || return 1

  export _EOPT="$_args"
}

_print_supported_operations() {
  local _pacman="$1"
  echo -n "pacapt: available operations:"
  $GREP -E "^${_pacman}_[^ \t]+\(\)" "$0" \
  | $AWK -F '(' '{print $1}' \
  | sed -e "s/${_pacman}_//g" \
  | while read O; do
      echo -n " $O"
    done
  echo
}

_print_pacapt_version() {
  cat <<EOF
pacapt version '${1:-unknown}'

Copyright (C) 2010 - $(date +%Y) Anh K. Huynh et al.

Usage of the works is permitted provided that this
instrument is retained with the works, so that any
entity that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.
EOF
}
