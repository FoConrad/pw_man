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
  cat << EOF
Usage: pw_man [options] command [args]

pw_man is a manager for passwords. When you call init, you set a master
password for the specified tag. Then other passwords can saved using that
single master password (also support for multiple master passwords)

Options: -i <id> - use identity <id> instead of default
         -h      - print this usage screen

Commands: init                  - initialize pw_man for id <id>
          [get] <tag>           - retrieve password for <tag>

          set [opts] <tag>      - set password for <tag>
            set opts:  -o   - allow overwriting if password for <tag> exists

          new [opts [len] [tag] - create new password for tag (or prints) of
                                  length len (or 10). See man pwgen
            new opts:  -p   - use pwgen to generate with all following flags
                       -c   - do not use capital letters
                       -s   - do not use symbols (e.g. #$@* you!)
                       -n   - do not use numbers
                       -r   - choose randomly, no category requirements

          chpass                - change protective password for <id>
EOF
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
  eval "echo '${pass}' | ${CLIPBOARD_COMMAND}"
  (
    (
      sleep "${PASSWORD_TIME}"
      eval "echo Clipboard reset | ${CLIPBOARD_COMMAND}"
    )&
  )
}

setpass() {
  init_or_die
  local over_write=0; [ "$1" = "-o" ] && { over_write=1; shift; }
  local tag="$1"; shift

  echo -n "Master password:"
  read -s password
  echo

  echo "${password}" | \
    gpg "${GPG_ARGS}" --batch --passphrase-fd 0 -d "${CONFIG_FILE}.gpg" > "${CONFIG_FILE}"


  # Confirm master pass
  if [ $? -ne 0 ]; then
    rm "${CONFIG_FILE}"
    die "Bad password"
  fi

  # Need to remove unprotected config file no matter what now that we've
  # unencrypted it

  # Check if password is already present
  if grep -E "^${tag}:" "${CONFIG_FILE}" &>/dev/null && (( over_write == 0 ))
  then # Only breaking here due to 80 char limit
      rm "${CONFIG_FILE}"
      die "Pass word already set! Use get or pass -o flag to setpass"
  fi

  echo -n "Password for ${tag}:"
  read -s tag_password
  echo

  # We need to 1) remove tag from file if present and 2) add new pass. Wish
  # there was a construct, e.g. filter file > file
  local _tmp="$(mktemp)"
  {
      grep -vE "^${tag}:" "${CONFIG_FILE}";
      echo "${tag}:${tag_password}";
  } > "${_tmp}"
  cat "${_tmp}" > ${CONFIG_FILE}
  rm ${_tmp}


  rm "${CONFIG_FILE}.gpg"
  echo "${password}" | gpg "${GPG_ARGS}" --batch --passphrase-fd 0 --symmetric "${CONFIG_FILE}"
  rm "${CONFIG_FILE}"
  tag_password="pass reset"
  password="pass reset"

}

changepass() {
  init_or_die
  # Unencrypt password store
  echo "Enter old password..."
  gpg "${GPG_ARGS}" -d "${CONFIG_FILE}.gpg" > "${CONFIG_FILE}" || die "Bad password"

  # Reencrypt password store, overwriting old one
  echo "Enter new password..."
  gpg "${GPG_ARGS}" --symmetric --yes "${CONFIG_FILE}" || \
      die "Bad password, keep old one for now..."
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

# Essentially all invocations will end here
remove_config() {
  local ret=$?
  rm -f "${CONFIG_FILE}"
  if [ "$ret" -ne 0 ]; then
    exit 1
  else
    exit 0
  fi
}


############ Main logic here ####################

# No matter what happens, remove unencrypted config file
trap remove_config EXIT

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
