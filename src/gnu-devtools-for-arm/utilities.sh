# Create the installation directories for binaries
# If sysroot path is passed as second argument the dir build_sysroot is also created
# mk_bin_dirs "prefix" <"/sysroot/path">
mk_bin_dirs()
{
    local prefix=$1

    mkdir -p ${installdir}${prefix}/bin
    mkdir -p ${qemu_installdir}/${prefix}/bin

    if [[ $# > 1 ]]; then
        mkdir -p ${2}
    fi
}

write_build_status()
{
cat <<EOF
# Invoked as:
#    $(basename $0) $all_args
target="$target"
builddir="$builddir"
prefix="$prefix"
srcdir="$srcdir"
dejagnu_src="$dejagnu_src"
dejagnu_site="$dejagnu_site"
EOF
}

number_of_cores()
{
  if [ -r /proc/cpuinfo ]; then
    grep -c "^processor" /proc/cpuinfo
  elif [ "$(uname -s)" == "Darwin" ]; then
    sysctl -n hw.ncpu
  else
    echo "1"
  fi
}

extend ()
{
  if [ -z "$1" ]; then
    echo "$2"
  else
    echo "$1:$2"
  fi
}

# Get the triple of the machine we're running on, i.e. the build machine.
find_build_triple ()
{
  machine=$(uname -m)
  plat=$(uname -s)
  if [[ "$plat" == "Darwin" ]]; then
    echo "$machine-apple-darwin"    # e.g. x86_64-apple-darwin or arm64-apple-darwin
  elif [[ "$plat" == "Linux" ]]; then
    echo "$machine-none-linux-gnu"  # e.g. x86_64-none-linux-gnu
  else
    echo "$this_script: unsupported platform: $plat" >&2
    exit 1
  fi
  return 0
}

empty_stages_p ()
{
  [ -z "${stages[*]:-}" ]
}

push_stages ()
{
  stages=("$@" "${stages[@]:-}")
}

pop_stages ()
{
  item=${stages[0]}
  unset stages[0]
  stages=("${stages[@]:-}")
}

break_hardlink()
{
  if [ $# -ne 1 ]; then
    echo "error: break_hardlink requires a file" >&2
    return 1
  fi

  local filename="$1"
  if [ ! -f "$filename" ]; then
    echo "error: file does not exist: $filename" >&2
    return 1
  fi

  local dir=$(dirname "$filename")
  local tmp=$(mktemp "$dir/.break-hardlink.XXXXXX") || return 1
  if ! cp -p "$filename" "$tmp" || ! mv -f "$tmp" "$filename"; then
    rm -f "$tmp"
    return 1
  fi
}

strip_lib()
{
  # Further improvement is needed to control the strip using a build flag through bld-gnu.sh

  if [ $target == "arm-none-eabi" ]; then
    local dir="$1"
    local strip_command=$(find $installdir/../ -name strip | head -n 1)
    local TARGET_OBJECTS=$(find $dir -name \*.o | grep -v .dll)
    local UNSTRIPPED_LIBRARIES=$(find "$dir" \( -name libg.a -o -name libg_nano.a \))
    local TARGET_LIBRARIES=$(find "$dir" -name \*.a ! -name libg.a ! -name libg_nano.a | grep -v .dll)

    # We are omitting the sections that were previously removed in the embedded releases of GNU-RM.
    # Manually use objcopy to remove a number of debug sections to trim down the binary size. 
    # This is similar to the use of `strip -g`, but does not remove the `.debug_frame` section, which is needed for minimal stack unwinding through the library.
    
    for target_lib in $UNSTRIPPED_LIBRARIES ; do
      break_hardlink "$target_lib"
    done

    for target_lib in $TARGET_LIBRARIES ; do
      $strip_command --remove-section=.comment --remove-section=.note --strip-debug --enable-deterministic-archives --keep-section=.debug_frame $target_lib || true
    done

    for target_obj in $TARGET_OBJECTS ; do
      $strip_command --remove-section=.comment --remove-section=.note --strip-debug --enable-deterministic-archives --keep-section=.debug_frame $target_obj || true
    done
  fi
}

strip_host_tools()
{
  local trace_enabled=0

  case "$-" in
    *x*)
      trace_enabled=1
      set +x
      ;;
  esac

  local dir="$1"
  local target="$2"
  local strip="$3"
  local exe="${4:-}"
  local -a tools=()
  local status
  local tool

  if ! command -v "$strip" >/dev/null 2>&1; then
    echo "error: strip tool is not available: $strip" >&2
    [ $trace_enabled -eq 1 ] && set -x
    return 1
  fi

  for tool in "$dir/bin/$target-"*"$exe"; do
    [ -f "$tool" ] && tools+=("$tool")
  done

  for tool in "$dir/$target/bin/"*"$exe"; do
    [ -f "$tool" ] && tools+=("$tool")
  done

  for tool in "$dir/lib/gcc/$target/"*/*"$exe"; do
    if [ -f "$tool" ] && [ -x "$tool" ]; then
      case "$tool" in
        *.a | *.o) ;;
        *) tools+=("$tool") ;;
      esac
    fi
  done

  for tool in "${tools[@]}"; do
    case "$(file -b "$tool")" in
      *Mach-O*)
        printf '+ %q -x %q\n' "$strip" "$tool" >&2
        "$strip" -x "$tool" || {
          status=$?
          [ $trace_enabled -eq 1 ] && set -x
          return $status
        }
        if command -v codesign >/dev/null 2>&1; then
          printf '+ codesign --force --sign - %q\n' "$tool" >&2
          codesign --force --sign - "$tool" || {
            status=$?
            [ $trace_enabled -eq 1 ] && set -x
            return $status
          }
        fi
        ;;
      *ELF* | *PE*)
        printf '+ %q %q\n' "$strip" "$tool" >&2
        "$strip" "$tool" || {
          status=$?
          [ $trace_enabled -eq 1 ] && set -x
          return $status
        }
        ;;
    esac
  done

  if [ $trace_enabled -eq 1 ]; then
    set -x
  fi
}

update_stage ()
{
  local action="$1"
  shift
  echo "($action) $*"
}

cleanup ()
{
  rm -rf "$tmpdir"
}

ternary()
{
  # $(ternary Condition True False) is equivalent to C == 1 ? T : F
  local c="$1"
  local t="$2"
  local f="$3"
  if [ $c -eq 1 ]; then echo "$t"; else echo "$f"; fi
}

find_source_tree ()
{
  local srcdir="$1"
  local d
  shift 1
  for d in "$@"
  do
    if [[ "$d" == "gcc" ]]
    then
      for x in `find "$srcdir" -maxdepth 1 -type d -printf '%f\n' | grep "^arm-gnu-toolchain-src-snapshot[0-9.-]*" | sort`
      do
        echo "$srcdir/$x"
        return 0
      done
    fi
    for x in `ls "$srcdir" | grep "^$d[0-9.-]*" | sort`
    do
       echo "$srcdir/$x"
       return 0
    done
    test -d "$srcdir/$d" && echo "$srcdir/$d" && return 0
    test -d "$srcdir/git/$d" && echo "$srcdir/git/$d" && return 0
  done
  return 1
}

find_component ()
{
  local srcdir="$1"
  local component="$2"
  local component_src
  eval component_src="\${${component}_src:-""}"
  if test -z "$component_src"
  then
    if ! component_srcdir=`find_source_tree "$srcdir" ${component}`
    then
      return 1
    fi
    eval ${component}_src="$component_srcdir"
  fi
}

find_component_or_error ()
{
  local srcdir="$1"
  local component="$2"
  if ! find_component "$srcdir" "$component"
  then
    echo "error: cannot find $component source in $srcdir" >&2
    exit 1
  fi
}

determine_version ()
{
  local srcdir="$1"
  local tag_flag="${tag:-unknown}"

  # If a command line tag was specified use it,
  # otherwise figure out a git tag to use.
  if [[ "$tag_flag" == "unknown" ]]
  then
    if [ -d $srcdir/.git ]
    then
      tag_flag=$(cd $srcdir; git rev-parse HEAD)
    else
      local version
      version=$(basename "$srcdir" | sed "s/[a-zA-Z0-9-]*-//")
      if [ -n "$version" ]
        then tag_flag="$version"
      else tag_flag="unknown"
      fi
    fi
  fi
  echo "$tag_flag"
}

do_install ()
{
  local component="$1"
  eval local objdir="\$${component}_objdir"
  eval local destdir="\${${component}_destdir:-""}"
  eval local install_targets="\${${component}_install_targets:-""}"
  eval local extra_install_envflags="\${${component}_extra_install_envflags:-""}"

  test -n "$install_targets" || install_targets=install

  update_stage "install ${component}"
  make ${extra_install_envflags} DESTDIR=$destdir INSTALL="$(command -v install) -C" \
     -C $objdir $install_targets
  echo "${component}_install_targets=$install_targets" >> "$build_flags_path"
}

do_config ()
{
  local component="$1"
  eval local srcdir="\${${component}_srcdir:-""}"
  eval local objdir="\${${component}_objdir:-""}"
  eval local config="\${${component}_config:-""}"
  eval local preconf="\${${component}_preconf:-""}"
  eval local cflags="\${${component}_cflags:-""}"
  eval local cxxflags="\${${component}_cxxflags:-""}"
  eval local cflags_for_target="\${${component}_cflags_for_target:-""}"
  eval local cxxflags_for_target="\${${component}_cxxflags_for_target:-""}"
  eval local ldflags_for_target="\${${component}_ldflags_for_target:-""}"
  eval local copy_src_to_obj="\${${component}_copy_src_to_obj:-0}"
  eval local update_gnuconfig="\${${component}_update_gnuconfig:-0}"
  eval local extra_config_envflags="\${${component}_extra_config_envflags:-""}"

  mkdir -p "$objdir"
  if [ $copy_src_to_obj -eq 1 ]
  then
    rsync -a --exclude=.git "$srcdir/" "$objdir/"
    srcdir="$objdir"
    cfgsrcdir=.
  else
    cfgsrcdir="$srcdir"
  fi

  if [ ! -e "$srcdir/configure" ]
  then
    (cd "$srcdir" && autoreconf -v -f -i) || false
  fi

  if [ $update_gnuconfig -eq 1 ]; then
    for f in config.guess config.sub
    do
      rsync -a "$execdir/gnu-config-aux/$f" "$srcdir/$f"
    done
  fi

  if [ -n "$cflags_for_target" ]; then
    extra_config_envflags="${extra_config_envflags} CFLAGS_FOR_TARGET=\"$cflags_for_target\""
  fi
  if [ -n "$cxxflags_for_target" ]; then
    extra_config_envflags="${extra_config_envflags} CXXFLAGS_FOR_TARGET=\"$cxxflags_for_target\""
  fi
  if [ -n "$ldflags_for_target" ]; then
    extra_config_envflags="${extra_config_envflags} LDFLAGS_FOR_TARGET=\"$ldflags_for_target\""
  fi

  if test ! -e "$objdir/Makefile"
  then
    update_stage "config ${component}"
    if test -n "$preconf"
    then
      (cd "$objdir" && "$preconf") || false
    fi
    local tag_flag
    tag_flag=$(set -e; determine_version "$srcdir")
    ( cd "$objdir" &&
      eval "CFLAGS=\"$cflags\" CXXFLAGS=\"$cxxflags\" $extra_config_envflags $cfgsrcdir/configure $config --with-pkgversion=\"$tag_flag\"") || false
  fi
  echo "${component}_configure=$config" >> "$build_flags_path"
}

do_make ()
{
  local component="$1"
  eval local srcdir="\$${component}_srcdir"
  eval local objdir="\$${component}_objdir"
  eval local allow_parallel="\${${component}_parallel:-1}"
  eval local copy_src_to_obj="\${${component}_copy_src_to_obj:-0}"
  eval local extra_make_envflags="\${${component}_extra_make_envflags:-""}"
  eval local build_targets="\${${component}_build_targets:-""}"

  if [ $copy_src_to_obj -eq 1 ]
  then
    srcdir="$objdir"
  fi
  update_stage "build ${component}"

  make_opts=${parallel:-}

  if [ -n "${extra_make_envflags:-}" ]; then
    eval make ${extra_make_envflags} ${make_opts:-} -C "$objdir" $build_targets
  else
    make ${make_opts:-} -C "$objdir" $build_targets
  fi
  echo "${component}_build_targets=$build_targets" >> "$build_flags_path"
}

do_config_build_install ()
{
  local component="$1"
  do_config "$@"
  do_make "$@"
  do_install "$@"
}

check_in_gcc()
{
  local name="$1"
  local dir="$2"
  local target="$3"
  local resultdir="$4"

  ( ulimit -v $memlimit &&
    make -C "$dir" $parallel -k $target RUNTESTFLAGS="$RUNTESTFLAGS") || true

  # Capture the results
  mkdir -p "$resultdir"
  for f in `find "$dir" -name "$name.log" -o -name "$name.sum" -o -name "$name.xml"`
  do
    cp "$f" "$resultdir"
  done
}

check_in_newlib()
{
  local dir="$1"
  local gcc_prefix="$2"
  local check_target="$3"
  local resultdir="$4"

  timelimit=120
  ( ulimit -v $memlimit &&
    RUNTESTFLAGS="$RUNTESTFLAGS" \
    DEJAGNU_TIMEOUT=$timelimit toolchain_prefix="$gcc_prefix" \
    make -C "$dir" $parallel -k "$check_target" \
    CC_FOR_TARGET="${gcc_prefix}/bin/$target-gcc") || true
  # Capture the results
  mkdir -p "$resultdir"
  for f in $(find "$dir/$target" -name "newlib.sum" -o -name "newlib.log")
  do
    np=$(echo "$f" | sed "s@$dir/$target/@@;s@newlib/testsuite/@@")
    mkdir -p $(dirname "$resultdir/multilib/$np")
    cp "$f" "$resultdir/multilib/$np"
  done
  if false; then
    # If we enabled multilib result splicing here in
    # build-elf.sh it would look like this.  Currently this is
    # disabled an splicing is handled by the caller.

    djsplice --directory "$resultdir/multilib" --scan newlib.sum -o "$resultdir/newlib.sum"
    djsplice --directory "$resultdir/multilib" --scan newlib.log -o "$resultdir/newlib.log"
  fi
}

set_env_var()
{
  local var_name="$1"
  local var_content="$2"

  if test -z ${!var_name:-""}
  then
    export ${var_name}="${var_content}"
  fi
}

check_if_readable()
{
  local var_name="$1"
  if [ ! -r $var_name ]; then
    printf "error: missing $var_name\n" >&2
    exit 1
  fi
}

get_brew_pkg_version()
{
  local libpath="$1"
  version=$(ls -d ${libpath} | awk -F'[@/]' '{print $6}')
  echo $version
}

add_to_path()
{
  local path_to_add="$1"
  export PATH="${path_to_add}:$PATH"
}

set_darwin_envvars()
{
  BREW_DEFAULT_PATH="/usr/local"  # Default for x86_64 MacOSX
  READLINK_CMD=readlink
  PR_CMD=pr
  if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_DEFAULT_PATH="/opt/homebrew" # Default for applesilicon
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    READLINK_CMD=greadlink  # Requires brew install coreutils
    PR_CMD=gpr
    add_to_path "${BREW_DEFAULT_PATH}/opt/gnu-sed/libexec/gnubin"
    add_to_path "${BREW_DEFAULT_PATH}/bin"
    add_to_path "${BREW_DEFAULT_PATH}/opt/bison/bin"
    add_to_path "${BREW_DEFAULT_PATH}/opt/findutils/libexec/gnubin"
    add_to_path "${BREW_DEFAULT_PATH}/opt/gnu-getopt/bin"
    TEXINFO_VERSION=$(get_brew_pkg_version "${BREW_DEFAULT_PATH}/opt/texinfo*") # To find version of texinfo installed
    add_to_path "${BREW_DEFAULT_PATH}/opt/texinfo@${TEXINFO_VERSION}/bin"
  fi
}
