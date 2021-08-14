# shellcheck disable=SC1090
################################################################################
# modules
################################################################################
BEE_MODULES_PATH="${BEE_MODULES_PATH:-"${BEE_HOME}/src/modules"}"

BEE_LOAD_MODULE_NAME=""
declare -Ag BEE_LOAD_MODULE_LOADED=()
bee::load_module() {
  local module="$1"
  if [[ ! -v BEE_LOAD_MODULE_LOADED["${module}"] ]]; then
    local module_path="${BEE_MODULES_PATH}/${module}.bash"
    if [[ -f "${module_path}" ]]; then
      source "${module_path}"
      BEE_LOAD_MODULE_NAME="${module}"
    else
      BEE_LOAD_MODULE_NAME=""
    fi
    BEE_LOAD_MODULE_LOADED["${module}"]="${BEE_LOAD_MODULE_NAME}"
  else
    BEE_LOAD_MODULE_NAME="${BEE_LOAD_MODULE_LOADED["${module}"]}"
  fi
}

bee::run_module() {
  local module="$1"
  shift
  "bee::${module}" "$@"
}

################################################################################
# plugins
################################################################################
BEE_RESOLVE_PLUGIN_NAME=""
BEE_RESOLVE_PLUGIN_VERSION=""
BEE_RESOLVE_PLUGIN_PATH=""
declare -Ag BEE_RESOLVE_PLUGIN_PATH_CACHE=()
bee::resolve_plugin() {
  local plugin="$1"
  local -i found=0
  BEE_RESOLVE_PLUGIN_NAME="${plugin%:*}"
  BEE_RESOLVE_PLUGIN_VERSION="${plugin##*:}"
  if [[ ! -v BEE_RESOLVE_PLUGIN_PATH_CACHE["${plugin}"] ]]; then
    for plugin_path in "${BEE_PLUGINS_PATHS[@]}"; do
      if [[ "${BEE_RESOLVE_PLUGIN_NAME}" == "${BEE_RESOLVE_PLUGIN_VERSION}" && -d "${plugin_path}/${BEE_RESOLVE_PLUGIN_NAME}" ]]; then
        BEE_RESOLVE_PLUGIN_VERSION="$(basename "$(find "${plugin_path}/${BEE_RESOLVE_PLUGIN_NAME}" -type d -mindepth 1 -maxdepth 1 | sort -rV | head -n 1)")"
      fi
      BEE_RESOLVE_PLUGIN_PATH="${plugin_path}/${BEE_RESOLVE_PLUGIN_NAME}/${BEE_RESOLVE_PLUGIN_VERSION}/${BEE_RESOLVE_PLUGIN_NAME}.bash"
      if [[ -f "${BEE_RESOLVE_PLUGIN_PATH}" ]]; then
        BEE_RESOLVE_PLUGIN_PATH_CACHE["${BEE_RESOLVE_PLUGIN_NAME}:${BEE_RESOLVE_PLUGIN_VERSION}"]="${BEE_RESOLVE_PLUGIN_PATH}"
        found=1
        break
      fi
    done
    if ((!found)); then
      BEE_RESOLVE_PLUGIN_NAME=""
      BEE_RESOLVE_PLUGIN_VERSION=""
      BEE_RESOLVE_PLUGIN_PATH=""
    fi
    BEE_RESOLVE_PLUGIN_PATH_CACHE["${plugin}"]="${BEE_RESOLVE_PLUGIN_PATH}"
  else
    BEE_RESOLVE_PLUGIN_PATH="${BEE_RESOLVE_PLUGIN_PATH_CACHE["${plugin}"]}"
  fi
}

BEE_LOAD_PLUGIN_NAME=""
declare -Ag BEE_LOAD_PLUGIN_LOADED=()
BEE_LOAD_PLUGIN_MISSING=()
bee::load_plugin() {
  BEE_LOAD_PLUGIN_MISSING=()
  bee::resolve_plugin "$1"
  if [[ -n "${BEE_RESOLVE_PLUGIN_PATH}" ]]; then
    BEE_LOAD_PLUGIN_NAME="${BEE_RESOLVE_PLUGIN_NAME}"
    bee::load_plugin_deps
    if [[ ${#BEE_LOAD_PLUGIN_MISSING[@]} -gt 0 ]]; then
      for missing in "${BEE_LOAD_PLUGIN_MISSING[@]}"; do
        bee::log_error "Missing plugin: '${missing}'"
      done
      exit 1
    fi
  else
    BEE_LOAD_PLUGIN_NAME=""
  fi
}

bee::load_plugin_deps() {
  if [[ ! -v BEE_LOAD_PLUGIN_LOADED["${BEE_RESOLVE_PLUGIN_PATH}"] ]]; then
    source "${BEE_RESOLVE_PLUGIN_PATH}"
    # shellcheck disable=SC2034
    BEE_LOAD_PLUGIN_LOADED["${BEE_RESOLVE_PLUGIN_PATH}"]=1
    local deps="${BEE_RESOLVE_PLUGIN_NAME}::deps"
    if [[ $(command -v "${deps}") == "${deps}" ]]; then
      for dep in $("${deps}"); do
        bee::resolve_plugin "${dep}"
        if [[ -n "${BEE_RESOLVE_PLUGIN_PATH}" ]]; then
          bee::load_plugin_deps
        else
          BEE_LOAD_PLUGIN_MISSING+=("${dep}")
        fi
      done
    fi
  fi
}

bee::run_plugin() {
  local plugin="$1"
  shift
  if (($#)); then
    local cmd="$1"
    shift
    "${plugin}::${cmd}" "$@"
  else
    "${plugin}::help"
  fi
}

################################################################################
# completion
################################################################################
bee::comp_modules() {
  find "${BEE_MODULES_PATH}" -type f -mindepth 1 -maxdepth 1 -name "*.bash" ! -name "help.bash" -exec basename {} ".bash" \;
}

bee::comp_plugins() {
  for plugin_path in "${BEE_PLUGINS_PATHS[@]}"; do
    [[ -d "${plugin_path}" ]] && find "${plugin_path}" -type d -mindepth 1 -maxdepth 1 -exec basename {} \;
  done
}

bee::comp_module_or_plugin() {
  bee::load_module "$1"
  if [[ -n "${BEE_LOAD_MODULE_NAME}" ]]; then
    local comp="bee::${BEE_LOAD_MODULE_NAME}::comp"
    [[ $(command -v "${comp}") == "${comp}" ]] && "${comp}"
    return
  fi

  bee::load_plugin "$1"
  if [[ -n "${BEE_LOAD_PLUGIN_NAME}" ]]; then
    local comp="${BEE_LOAD_PLUGIN_NAME}::comp"
    [[ $(command -v "${comp}") == "${comp}" ]] && "${comp}"
    return
  fi
}

################################################################################
# traps
################################################################################
BEE_CANCELED=0
BEE_MODE_INTERNAL=0
BEE_MODE_PLUGIN=1
BEE_MODE=${BEE_MODE_INTERNAL}
T=${SECONDS}

declare -Ag BEE_TRAPS_INT=()
declare -Ag BEE_TRAPS_TERM=()
declare -Ag BEE_TRAPS_EXIT=()
bee::add_int_trap() { BEE_TRAPS_INT["$1"]="$1"; }
bee::add_term_trap() { BEE_TRAPS_TERM["$1"]="$1"; }
bee::add_exit_trap() { BEE_TRAPS_EXIT["$1"]="$1"; }
bee::remove_int_trap() { unset BEE_TRAPS_INT["$1"]; }
bee::remove_term_trap() { unset BEE_TRAPS_TERM["$1"]; }
bee::remove_exit_trap() { unset BEE_TRAPS_EXIT["$1"]; }

bee::INT() { BEE_CANCELED=1; for t in "${BEE_TRAPS_INT[@]}"; do "$t"; done; }
bee::TERM() { BEE_CANCELED=1; for t in "${BEE_TRAPS_TERM[@]}"; do "$t"; done; }
bee::EXIT() {
  local -i status=$?
  for t in "${BEE_TRAPS_EXIT[@]}"; do "$t" ${status}; done
  if ((!BEE_QUIET && BEE_MODE == BEE_MODE_PLUGIN)); then
    local duration="$((SECONDS - T)) seconds"
    if ((BEE_CANCELED)); then
      bee::log_warn "bzzzz (${duration})"
    else
      if ((status)); then
        bee::log_error "bzzzz ${status} (${duration})"
      else
        bee::log "bzzzz (${duration})"
      fi
    fi
  fi
}

################################################################################
# run
################################################################################
bee::batch() {
  for batch in "$@"; do
    local cmd="${batch%% *}"
    local args="${batch#* }"
    if [[ "${args}" != "${cmd}" ]]; then
      # shellcheck disable=SC2046
      bee::run "${cmd}" $(bee::split_args "${args}")
    else
      bee::run "${cmd}"
    fi
  done
}

bee::split_args() {
  local IFS=" "
  # shellcheck disable=SC2068
  for arg in $@; do echo "${arg}"; done
}

bee::usage() {
  bee::load_module "help"
  bee::run_module "${BEE_LOAD_MODULE_NAME}"
}

bee::run() {
  trap bee::INT INT
  trap bee::TERM TERM
  trap bee::EXIT EXIT

  while (($#)); do case "$1" in
    -b | --batch) shift; bee::batch "$@"; return ;;
    -h | --help) bee::usage; return ;;
    -q | --quiet) BEE_QUIET=1 ;;
    -v | --verbose) set -x ;;
    --version) cat "${BEE_HOME}/version.txt"; return ;;
    --) shift; break ;;
    *) break ;;
  esac; shift; done

  if (($#)); then
    # run bee module, e.g. bee plugins ls
    bee::load_module "$1"
    if [[ -n "${BEE_LOAD_MODULE_NAME}" ]]; then
      shift
      bee::run_module "${BEE_LOAD_MODULE_NAME}" "$@"
      return
    fi
    # run bee plugin, e.g. bee github me
    bee::load_plugin "$1"
    if [[ -n "${BEE_LOAD_PLUGIN_NAME}" ]]; then
      BEE_MODE=${BEE_MODE_PLUGIN}
      shift
      bee::run_plugin "${BEE_LOAD_PLUGIN_NAME}" "$@"
      return
    fi
    # run args, e.g. bee echo "message"
    "$@"
  else
    bee::usage
  fi
}
