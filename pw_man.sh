#!/usr/bin/env bash

# Configurable options
XCLIP_SELECTION="clipboard"

# Must have options to:
#   - Exit on command error
#   - Exit on unset variable usage
#   - Essentially bash -e, print commands
#set -o errexit
#set -o nounset
#set -o xtrace


# Globals set in getopt
ID="default"
CONFIG_DIR="${HOME}/.pw_man"
CONFIG_FILE="${CONFIG_DIR}/${ID}"

CLIPBOARD_COMMAND="pbcopy"

resetcommand() {
  command -v $CLIPBOARD_COMMAND
  if [ $? -ne 0 ]; then
    command -v xclip
    if [ $? -ne 0 ]; then
      echo "Error, please install xclip or pbcopy"
      exit 3
    else
      CLIPBOARD_COMMAND="xclip -i -selection ${XCLIP_SELECTION}"
    fi
  fi
}

# Needed as id may change from default
resetconfig() {
  CONFIG_FILE="${CONFIG_DIR}/${ID}"
}

usage() {
  local exit_code=0
  if [ $# -gt 0 ]; then
    exit_code=-1
    echo "Error: $1"
    echo
  fi
  echo "Usage: pw_man [options] command [args]"
  echo
  echo "Options: -i <id> - use identity <id> instead of default"
  echo "         -h      - print this usage screen"
  echo
  echo "Commands: init        - initialize pw_man for id <id>"
  echo "          [get] <tag> - retrieve password for <tag>"
  echo "          set <tag>   - set password for <tag>"
  echo "          chpass      - change protective password for <id>"
  exit $exit_code
}

readpass() {
  init_or_die
  local tag="$1" ; shift
  local pass=$(gpg -d "${CONFIG_FILE}.gpg" | grep -E -o "^${tag}:.*" | sed "s/${tag}://")
  echo "You have 10 seconds to use password"
  echo "$pass" | pbcopy
  (
    (
      sleep 10
      echo "Clipboard reset" | pbcopy
    )&
  )
}

setpass() {
  init_or_die
  local tag="$1"; shift
  echo -n "Password for ${tag}:"
  read -s tag_password
  echo
  echo -n "Master password:"
  read -s password
  echo

  echo "${password}" | gpg --batch --passphrase-fd 0 -d "${CONFIG_FILE}.gpg" > "${CONFIG_FILE}"
  echo "${tag}:${tag_password}" >> "${CONFIG_FILE}"
  rm "${CONFIG_FILE}.gpg"
  echo "${password}" | gpg --batch --passphrase-fd 0 --symmetric $CONFIG_FILE
  rm $CONFIG_FILE
  tag_password="pass reset"
  password="pass reset"

}

changepass() {
  init_or_die
  echo "Changepass with args $@"
}

init_or_die() {
  resetconfig
  resetcommand
  if [ ! -f "${CONFIG_FILE}.gpg" ]; then
    echo "pw_man has not been initialized for ${ID}..."
    echo "Please run: pw_man -i ${ID} init"
    exit 2
  fi
}

init() {
  resetcommand
  echo "init with args $@"
  if [ ! -d "${CONFIG_DIR}" ]; then
    mkdir "${CONFIG_DIR}"
  fi
  resetconfig
  if [ -f "${CONFIG_FILE}.gpg" ]; then
    echo "File ${CONFIG_FILE} already exists!" 1>&2
    exit 1
  fi

  touch "${CONFIG_FILE}"
  gpg --symmetric $CONFIG_FILE
  rm "${CONFIG_FILE}"
}

############ Main logic here ####################

# Parse arguments, i.e. -h and -i <id>
while getopts "hi:" opt; do
  case "${opt}" in
    i)
      ID="${OPTARG}"
      ;;
    h)
      usage
      ;;
    \? )
      usage "Unknown option or missing argument"
      ;;
    : )
      usage "Unknown option or missing argument"
      ;;
  esac
done

# Get rid of flag arguments, and switch on command
shift $(expr $OPTIND - 1 )

COMMAND="$1"
case "$COMMAND" in
  init)
    init
    ;;
  set)
    shift
    setpass "$@"
    :
    ;;
  chpass)
    changepass
    ;;
  get)
    shift
    readpass "$@"
    :
    ;;
  *)
    readpass "$@"
    ;;
esac
