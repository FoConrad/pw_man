#!/usr/bin/env bash

# Configurable options
RSA_BITS=4096

# Must have options to:
#   - Exit on command error
#   - Exit on unset variable usage
#   - Essentially bash -e, print commands
set -o errexit
set -o nounset
#set -o xtrace


# Globals set in getopt
ID="default"
CONFIG_DIR="${HOME}/.pw_man"
CONFIG_FILE="${CONFIG_DIR}/${ID}"


# Needed as id may change from default
resetconfig() {
  CONFIG_FILE="${CONFIG_DIR}/${ID}"
}

getconfig() {
  echo -e "Key-Type: RSA"
  echo -e "Key-Length: ${RSA_BITS}"
  echo -e "Subkey-Type: RSA"
  echo -e "Subkey-Length: 2048"
  echo -e "Name-Real: pw_man_user_${ID}"
  echo -e "Name-Comment: pw_man_user_${ID}"
  echo -e "Name-Email: pw_man_user_${ID}@localhost.here"
  echo -e "Expire-Date: 0"
  #echo -e "Passphrase: kljfhslfjkhsaljkhsdflgjkhsd"
  echo -e "%pubring foo.pub"
  echo -e "%secring foo.sec"
  echo -e "# Do a commit here, so that we can later print "done" :-)"
  echo -e "%commit"
  echo -e "%echo done"
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

newid() {
  echo "Newid with args $@"
}

changepass() {
  echo "Changepass with args $@"
}

isinit() {
  echo "isinit with args $@"
}

init() {
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
