#!/usr/bin/env bash

# Configurable options
PASSWORD_TIME=10
XCLIP_SELECTION="clipboard"
CONFIG_DIR="${HOME}/.pw_man"
GPG_ARGS="--no-use-agent"

# Must have options to:
#   - Exit on command error
#   - Exit on unset variable usage
#   - Essentially bash -e, print commands
#set -o errexit
#set -o nounset
#set -o xtrace

# Globals set in getopt
ID="default"
CONFIG_FILE="${CONFIG_DIR}/${ID}"

CLIPBOARD_COMMAND="pbcopy"


die() {
  if [ $# -gt 0 ]; then
    echo "$1"
  fi
  exit 1
}

resetcommand() {
  command -v pbcopy 1>/dev/null
  if [ $? -ne 0 ]; then
    command -v xclip 1>/dev/null
    if [ $? -ne 0 ]; then
      die "Error, please install xclip or pbcopy"
    else
        CLIPBOARD_COMMAND="$(which xclip) -i -selection ${XCLIP_SELECTION}"
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

  # local removes return code
  local pass;
  pass="$(gpg ${GPG_ARGS} -d ${CONFIG_FILE}.gpg)" || die "Bad password"
  pass=$(echo "$pass" | grep -E -o "^${tag}:.*") || die "Password not found"
  pass=$(echo "$pass" | sed "s/${tag}://")


  echo "You have ${PASSWORD_TIME} seconds to use password"
  eval "echo $pass | ${CLIPBOARD_COMMAND}"
  (
    (
      sleep "${PASSWORD_TIME}"
      eval "echo Clipboard reset | ${CLIPBOARD_COMMAND}"
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

  echo "${password}" | \
    gpg "${GPG_ARGS}" --batch --passphrase-fd 0 -d "${CONFIG_FILE}.gpg" > "${CONFIG_FILE}"
  if [ $? -ne 0 ]; then
    rm "${CONFIG_FILE}"
    die "Bad password"
  fi

  echo "${tag}:${tag_password}" >> "${CONFIG_FILE}"
  rm "${CONFIG_FILE}.gpg"
  echo "${password}" | gpg "${GPG_ARGS}" --batch --passphrase-fd 0 --symmetric "${CONFIG_FILE}"
  rm "${CONFIG_FILE}"
  tag_password="pass reset"
  password="pass reset"

}

remove_config() {
  local ret=$?
  rm "${CONFIG_FILE}"
  if [ "$ret" -ne 0 ]; then
    return 1
  else
    return 0
  fi
}

changepass() {
  init_or_die
  # Unencrypt password store
  echo "Enter old password..."
  gpg "${GPG_ARGS}" -d "${CONFIG_FILE}.gpg" > "${CONFIG_FILE}" || die "Bad password"

  # Need to remove unprotected config file no matter what
  trap remove_config INT

  # Reencrypt password store, overwriting old one
  echo "Enter new password..."
  gpg "${GPG_ARGS}" --symmetric --yes "${CONFIG_FILE}"
  remove_config || die "Bad password, keep old one for now..."
}

init_or_die() {
  resetconfig
  resetcommand
  if [ ! -f "${CONFIG_FILE}.gpg" ]; then
    echo "pw_man has not been initialized for ${ID}..."
    echo "Please run: pw_man -i ${ID} init"
    exit 1
  fi
}

init() {
  resetcommand
  if [ ! -d "${CONFIG_DIR}" ]; then
    mkdir "${CONFIG_DIR}"
  fi
  resetconfig
  if [ -f "${CONFIG_FILE}.gpg" ]; then
    echo "File ${CONFIG_FILE} already exists!" 1>&2
    exit 1
  fi

  touch "${CONFIG_FILE}"
  gpg "${GPG_ARGS}" --symmetric "${CONFIG_FILE}"
  if [ $? -ne 0 ]; then
    rm "${CONFIG_FILE}"
    die "Bad password"
  fi
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
shift "$(expr $OPTIND - 1 )"

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
