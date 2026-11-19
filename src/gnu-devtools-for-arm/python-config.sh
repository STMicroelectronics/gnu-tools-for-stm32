#!/bin/bash
# vim:sw=4:ts=4:et:

#set -e
#set -u
#set -o pipefail

#PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

usage()
{
    cat <<EOF
usage: config-python.sh [OPTIONS]

This scipt is used to configure GDB. GDB's configuration file uses
--with-python=PATH/TO/SCRIPT command line to drive Python support for MinGW
builds.

Note: You must setup PYTHON_FOR_WINDOWS_DIR environment variable to point to local
Python (MSI) unzipped content.

Example usage:
It should be passed to GDB as --with-python=config-python.sh

Options:

  --prefix
    Path to directory with decompressed windows python dev libraries.
    For example:
        $ msiextract dev.msi -C /path/to/python-win/dir

  --exec-prefix
    Same as --prefix.

  --includes
    Points to -I/path/to/python-win/dir

  --cflags
    For example:
        -I/path/to/python-win/dir $CFLAGS

  --libs
    For example:
    -L/path/to/python-win/dir -lpython38

EOF
}

if [ ! -d "$PYTHON_FOR_WINDOWS_DIR" ]; then
  echo "error: PYTHON_FOR_WINDOWS_DIR='$PYTHON_FOR_WINDOWS_DIR' directory not found! " >&2
  exit 1
fi

python_win_dir="$PYTHON_FOR_WINDOWS_DIR"
python_win_dir_libs="$PYTHON_FOR_WINDOWS_DIR/libs"
python_win_ver=`basename -s .lib ${python_win_dir_libs}/python3[0-9]*.lib`

# Parse command-line options
opt_prev=
while test $# -gt 0
do
  opt_option="$1"
  # If the previous option needs an argument, assign it.
  if test -n "$opt_prev"; then
    eval "$opt_prev=\$opt_option"
    opt_prev=
    shift 1
    continue
  fi

  case $opt_option in
  --prefix | --exec-prefix)
    echo "$python_win_dir"
    ;;

  --includes)
    echo "-I$python_win_dir/include"
    ;;

  --cflags)
    echo "-I$python_win_dir ${CFLAGS:-}"
    ;;

  --libs | --ldflags)
    echo "-L$python_win_dir/libs -l${python_win_ver}"
    ;;

  --*)
    echo "error: unrecognised option: $opt_option" >&2
    exit 1
    ;;

  *)
    ;;
  esac
  shift 1
done

exit 0
