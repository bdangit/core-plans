# shellcheck shell=bash

scaffolding_load() {
  _setup_funcs
  _setup_vars

  pushd "$SRC_PATH" > /dev/null
  _detect_setup_py

  # _detect_app_type
  # _detect_missing_gems

  _detect_process_bins
  _update_vars
  _update_pkg_build_deps
  _update_pkg_deps
  _update_bin_dirs
  _update_svc_run
  popd > /dev/null
}

do_default_prepare() {
  return 0
}

do_default_build() {
  scaffolding_pip_install
  scaffolding_fix_python_shebangs
  scaffolding_setup_app_config
}

do_default_install() {
  scaffolding_install_app
  scaffolding_install_pip
  scaffolding_create_process_bins
}

# This becomes the `do_default_build_config` implementation thanks to some
# function "renaming" above. I know, right?
_new_do_default_build_config() {
  local key dir env_sh

  _stock_do_default_build_config

  if [[ ! -f "$PLAN_CONTEXT/hooks/init" ]]; then
    build_line "No user-defined init hook found, generating init hook"
    mkdir -p "$pkg_prefix/hooks"
    cat <<EOT >> "$pkg_prefix/hooks/init"
#!/bin/sh
set -e

export HOME="$pkg_svc_data_path"
. '$pkg_svc_config_path/app_env.sh'

EOT
    chmod 755 "$pkg_prefix/hooks/init"
  fi

  if [[ -f "$CACHE_PATH/default.scaffolding.toml" ]]; then
    build_line "Appending Scaffolding defaults to $pkg_prefix/default.toml"
    cat "$CACHE_PATH/default.scaffolding.toml" >> "$pkg_prefix/default.toml"
  fi

  env_sh="$pkg_prefix/config/app_env.sh"
  mkdir -p "$(dirname "$env_sh")"
  for key in "${!scaffolding_env[@]}"; do
    echo "export $key='${scaffolding_env[$key]}'" >> "$env_sh"
  done
}




scaffolding_pip_install() {
  local start_sec elapsed dot_pip

  # Attempt to preserve any original Bundler config by moving it to the side
  if [[ -f .bundle/config ]]; then
    mv .bundle/config .bundle/config.prehab
    dot_bundle=true
  elif [[ -d .bundle ]]; then
    dot_bundle=true
  fi

  build_line "Installing dependencies using $(_bundle --version)"
  start_sec="$SECONDS"
  _bundle_install \
    "$CACHE_PATH/vendor/bundle" \
    --retry 5
  elapsed=$((SECONDS - start_sec))
  elapsed=$(echo $elapsed | awk '{printf "%dm%ds", $1/60, $1%60}')
  build_line "Bundle completed ($elapsed)"

  # If we preserved the original Bundler config, move it back into place
  if [[ -f .bundle/config.prehab ]]; then
    rm -f .bundle/config
    mv .bundle/config.prehab .bundle/config
    rm -f .bundle/config.prehab
  fi
  # If not `.bundle/` directory existed before, then clear it out now
  if [[ -z "${dot_bundle:-}" ]]; then
    rm -rf .bundle
  fi
}

scaffolding_fix_python_shebangs() {
  local shebang bin_path
  shebang="#!$(pkg_path_for "$_python_pkg")/bin/python"
  bin_path="$CACHE_PATH/node_modules/.bin"

  build_line "Fixing Node shebang for node_module bins"
  if [[ -d "$bin_path" ]]; then
    find "$bin_path" -type f -o -type l | while read -r bin; do
      sed -e "s|^#!.\{0,\}\$|${shebang}|" -i "$(readlink -f "$bin")"
    done
  fi
}

scaffolding_setup_app_config() {
  local t
  t="$CACHE_PATH/default.scaffolding.toml"

  echo "" >> "$t"

  if _default_toml_has_no lang; then
    echo 'lang = "en_US.UTF-8"' >> "$t"
  fi

  if _default_toml_has_no app; then
    echo "" >> "$t"
    echo '[app]' >> "$t"
    if _default_toml_has_no app.port; then
      echo "port = $scaffolding_app_port" >> "$t"
    fi
  fi
}

scaffolding_install_app() {
  build_line "Installing app codebase to $scaffolding_app_prefix"
  mkdir -pv "$scaffolding_app_prefix"
  if [[ -n "${_uses_git:-}" ]]; then
    # Use git commands to skip any git-ignored files and directories including
    # the `.git/ directory. Current on-disk state of all files is used meaning
    # that dirty and unstaged files are included which should help while
    # working on package builds.
    { git ls-files; git ls-files --exclude-standard --others; } \
      | _tar_pipe_app_cp_to "$scaffolding_app_prefix"
  else
    # Use find to enumerate all files and directories for copying. This is the
    # safe-fallback strategy if no version control software is detected.
    find . | _tar_pipe_app_cp_to "$scaffolding_app_prefix"
  fi
}

scaffolding_install_pip() {
  mkdir -pv "$scaffolding_app_prefix/vendor"
  build_line "Installing vendored gems to $scaffolding_app_prefix/vendor/bundle"
  cp -a "$CACHE_PATH/vendor/bundle" "$scaffolding_app_prefix/vendor/"
}

scaffolding_create_process_bins() {
  local bin cmd

  for bin in "${!scaffolding_process_bins[@]}"; do
    cmd="${scaffolding_process_bins[$bin]}"
    _create_process_bin "$pkg_prefix/bin/${pkg_name}-${bin}" "$cmd"
  done
}




_setup_funcs() {
  # Use the stock `do_default_build_config` by renaming it so we can call the
  # stock behavior. How does this rate on the evil scale?
  _rename_function "do_default_build_config" "_stock_do_default_build_config"
  _rename_function "_new_do_default_build_config" "do_default_build_config"
}

_setup_vars() {
  # The default python package if one cannot be detected
  _default_python_pkg="core/python"
  # `$scaffolding_ruby_pkg` is empty by default
  : "${scaffolding_python_pkg:=}"
  # The install prefix path for the app
  scaffolding_app_prefix="$pkg_prefix/app"
  #
  : "${scaffolding_app_port:=8000}"
  # If `${scaffolding_env[@]` is not yet set, setup the hash
  if [[ ! "$(declare -p scaffolding_env 2> /dev/null || true)" =~ "declare -A" ]]; then
    declare -g -A scaffolding_env
  fi
  # If `${scaffolding_process_bins[@]` is not yet set, setup the hash
  if [[ ! "$(declare -p scaffolding_process_bins 2> /dev/null || true)" =~ "declare -A" ]]; then
    declare -g -A scaffolding_process_bins
  fi
  #
  if [[ ! "$(declare -p scaffolding_symlinked_dirs 2> /dev/null || true)" =~ "declare -a" ]]; then
    declare -g -a scaffolding_symlinked_dirs
  fi
  #
  if [[ ! "$(declare -p scaffolding_symlinked_files 2> /dev/null || true)" =~ "declare -a" ]]; then
    declare -g -a scaffolding_symlinked_files
  fi
  #
  : "${_app_type:=}"
}

_detect_setup_py() {
  if [[ ! -f setup.py ]]; then
    exit_with \
      "Python Scaffolding cannot find setup.py in the root directory" 5
  fi
}

# shellcheck disable=SC2016
_detect_process_bins() {
  if [[ -f Procfile ]]; then
    local line bin cmd

    build_line "Procfile detected, reading processes"
    # Procfile parsing was heavily inspired by the implementation in
    # gliderlabs/herokuish. Thanks to:
    # https://github.com/gliderlabs/herokuish/blob/master/include/procfile.bash
    while read -r line; do
      if [[ "$line" =~ ^#.* ]]; then
        continue
      else
        bin="${line%%:*}"
        cmd="${line#*:}"
        _set_if_unset scaffolding_process_bins "$(trim "$bin")" "$(trim "$cmd")"
      fi
    done < Procfile
  fi

  _set_if_unset scaffolding_process_bins "sh" 'sh'
}

_update_vars() {
  _set_if_unset scaffolding_env LANG "{{cfg.lang}}"
  _set_if_unset scaffolding_env PORT "{{cfg.app.port}}"
  # Export the app's listen port
  _set_if_unset pkg_exports port "app.port"
}

_update_pkg_build_deps() {
  # Order here is important--entries which should be first in
  # `${pkg_build_deps[@]}` should be called last.

  _detect_git
}

_update_pkg_deps() {
  # Order here is important--entries which should be first in `${pkg_deps[@]}`
  # should be called last.

  _add_busybox
  _detect_python
}

_update_bin_dirs() {
  # Add the `bin/` directory and the app's `binstubs/` directory to the bin
  # dirs so they will be on `PATH.  We do this after the existing values so
  # that the Plan author's `${pkg_bin_dir[@]}` will always win.
  pkg_bin_dirs=(
    ${pkg_bin_dir[@]}
    bin
    $(basename "$scaffolding_app_prefix")/binstubs
  )
}

_update_svc_run() {
  if [[ -z "$pkg_svc_run" ]]; then
    pkg_svc_run="$pkg_prefix/bin/${pkg_name}-web"
    build_line "Setting pkg_svc_run='$pkg_svc_run'"
  fi
}




_add_busybox() {
  build_line "Adding Busybox package to run dependencies"
  pkg_deps=(core/busybox-static ${pkg_deps[@]})
  debug "Updating pkg_deps=(${pkg_deps[*]}) from Scaffolding detection"
}

_detect_git() {
  if [[ -d ".git" ]]; then
    build_line "Detected '.git' directory, adding git packages as build deps"
    pkg_build_deps=(core/git ${pkg_build_deps[@]})
    debug "Updating pkg_build_deps=(${pkg_build_deps[*]}) from Scaffolding detection"
    _uses_git=true
  fi
}

_detect_python() {
  local lockfile_version

  if [[ -n "$scaffolding_python_pkg" ]]; then
    _python_pkg="$scaffolding_python_pkg"
    build_line "Detected Python version in Plan, using '$_python_pkg'"
  else
    _python_pkg="$_default_python_pkg"
    build_line "No Python version detected in Plan, using default '$_python_pkg'"
  fi
  pkg_deps=($_python_pkg ${pkg_deps[@]})
  debug "Updating pkg_deps=(${pkg_deps[*]}) from Scaffolding detection"
}




_create_process_bin() {
  local bin cmd env_sh
  bin="$1"
  cmd="$2"
  env_sh="$pkg_svc_config_path/app_env.sh"

  build_line "Creating ${bin} process bin"
  cat <<EOF > "$bin"
#!$(pkg_path_for busybox-static)/bin/sh
set -e
if test -n "\$DEBUG"; then set -x; fi

export HOME="$pkg_svc_data_path"

if [ -f "$env_sh" ]; then
  . "$env_sh"
else
  >&2 echo "No app env file found: '$env_sh'"
  >&2 echo "Have you not started this service ($pkg_origin/$pkg_name) before?"
  >&2 echo ""
  >&2 echo "Aborting..."
  exit 1
fi

cd $scaffolding_app_prefix

exec $cmd \$@
EOF
  chmod -v 755 "$bin"
}

_default_toml_has_no() {
  local key toml
  key="$1"
  toml="$PLAN_CONTEXT/default.toml"

  if [[ ! -f "$toml" ]]; then
    return 0
  fi

  if [[ "$(rq -t < "$toml" "at \"${key}\"")" == "null" ]]; then
    return 0
  else
    return 1
  fi
}

# Heavily inspired from:
# https://gist.github.com/Integralist/1e2616dc0b165f0edead9bf819d23c1e
_rename_function() {
  local orig_name new_name
  orig_name="$1"
  new_name="$2"

  declare -F "$orig_name" > /dev/null \
    || exit_with "No function named $orig_name, aborting" 97
  eval "$(echo "${new_name}()"; declare -f "$orig_name" | tail -n +2)"
}

_set_if_unset() {
  local hash key val
  hash="$1"
  key="$2"
  val="$3"

  if [[ ! -v "$hash[$key]" ]]; then
    eval "$hash[$key]='$val'"
  fi
}

# **Internal** Use a "tar pipe" to copy the app source into a destination
# directory. This function reads from `stdin` for its file/directory manifest
# where each entry is on its own line ending in a newline. Several filters and
# changes are made via this copy strategy:
#
# * All user and group ids are mapped to root/0
# * No extended attributes are copied
# * Some file editor backup files are skipped
# * Some version control-related directories are skipped
# * Any `./habitat/` directory is skipped
# * Any `./vendor/bundle` directory is skipped as it may have native gems
_tar_pipe_app_cp_to() {
  local dst_path tar
  dst_path="$1"
  tar="$(pkg_path_for tar)/bin/tar"

  "$tar" -cp \
      --owner=root:0 \
      --group=root:0 \
      --no-xattrs \
      --exclude-backups \
      --exclude-vcs \
      --exclude='habitat' \
      --exclude='vendor/bundle' \
      --files-from=- \
      -f - \
  | "$tar" -x \
      -C "$dst_path" \
      -f -
}
