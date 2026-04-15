#!/usr/bin/ksh

set +e

set -o nounset

readonly SCRIPT_NAME="artix-fluxbox-setup.ksh"
readonly SCRIPT_VERSION="1.0.14.2"
readonly SCRIPT_PID=$$

readonly STATE_DIR="/var/lib/artix-fluxbox-setup"
readonly BACKUP_DIR="/var/backups/artix-fluxbox-setup"
readonly LOG_DIR="/var/log"
readonly LOGFILE="${LOG_DIR}/artix-fluxbox-setup.log"
readonly TMP_DIR="/tmp/artix-fluxbox-setup-${SCRIPT_PID}"
readonly PACKAGE_STATUS_FILE="${STATE_DIR}/package-status.tsv"
readonly PACKAGE_HISTORY_FILE="${STATE_DIR}/package-history.tsv"

readonly STAGE_PREFIX="${STATE_DIR}/stage_"
readonly STAGE_SUFFIX=".done"

TARGET_USER=""
TARGET_HOME=""
TARGET_UID=""
TARGET_GID=""
KBD_LAYOUT=""
KBD_VARIANT=""
KBD_MODEL="pc105"
KBD_OPTIONS=""
FORCE_RERUN=0
FORCE_REINSTALL_PACKAGES=0
AUTO_RETRY_ON_ERROR=0
GNOME1_THEME=0
MAX_AUTO_RETRIES=5
CURRENT_ATTEMPT=1
LAST_FAILED_STAGE=""

HW_ARCH=""
HW_CPU_VENDOR=""
HW_CPU_MODEL=""
HW_IS_INTEL_CPU=0
HW_GPU_LINE=""
HW_IS_INTEL_GPU=0
HW_GPU_DRIVER_RECOMMENDED="modesetting"
HW_IS_LAPTOP=0
HW_HAS_BATTERY=0
HW_HAS_BACKLIGHT=0
HW_AUDIO_CONTROLLERS=""
HW_HAS_AUDIO=0
HW_NET_ADAPTERS=""
HW_HAS_WIRELESS=0
HW_LOADED_GFX_MODULES=""

PKG_INTEL_GPU_AVAILABLE=0
PKG_AUDIO_AVAILABLE=0

if [ -t 1 ]; then
    C_RST="\033[0m"
    C_BOLD="\033[1m"
    C_DIM="\033[2m"
    C_RED="\033[31m"
    C_GREEN="\033[32m"
    C_YELLOW="\033[33m"
    C_BLUE="\033[34m"
    C_MAGENTA="\033[35m"
    C_CYAN="\033[36m"
    C_WHITE="\033[37m"
    C_BWHITE="\033[97m"
else
    C_RST="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW=""
    C_BLUE="" C_MAGENTA="" C_CYAN="" C_WHITE="" C_BWHITE=""
fi

readonly C_RST C_BOLD C_DIM C_RED C_GREEN C_YELLOW
readonly C_BLUE C_MAGENTA C_CYAN C_WHITE C_BWHITE

ui_rule() {
    print -- "${C_DIM}────────────────────────────────────────────────────────────────${C_RST}"
}

ui_banner() {
    print ""
    print -- "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════════════════════════╗${C_RST}"
    print -- "${C_BOLD}${C_CYAN}║  Artix Linux OpenRC — Fluxbox Desktop Post-Install  v${SCRIPT_VERSION}   ║${C_RST}"
    print -- "${C_BOLD}${C_CYAN}╚══════════════════════════════════════════════════════════════╝${C_RST}"
    print ""
}

ui_stage() {
    typeset num="$1" name="$2"
    print ""
    print -- "${C_BOLD}${C_BLUE}┌─ Stage ${num}: ${name}${C_RST}"
    ui_rule
}

ui_step() {
    print -- "  ${C_CYAN}→${C_RST}  $*"
}

ui_ok()   { print -- "  ${C_GREEN}[OK]${C_RST}   $*"; }
ui_warn() { print -- "  ${C_YELLOW}[WARN]${C_RST} $*"; }
ui_fail() { print -- "  ${C_RED}[FAIL]${C_RST} $*"; }
ui_skip() { print -- "  ${C_DIM}[SKIP]${C_RST} $*"; }
ui_info() { print -- "  ${C_BLUE}[INFO]${C_RST} $*"; }

ui_kv() {
    typeset key="$1" val="$2"
    print -- "  ${C_BOLD}${key}:${C_RST} ${val}"
}

ui_sep() {
    print ""
    ui_rule
    print ""
}

ui_fatal() {
    print ""
    print -- "${C_BOLD}${C_RED}╔══════════════════════════════════════╗${C_RST}"
    print -- "${C_BOLD}${C_RED}║  FATAL ERROR — setup cannot continue ║${C_RST}"
    print -- "${C_BOLD}${C_RED}╚══════════════════════════════════════╝${C_RST}"
    print -- "  ${C_RED}$*${C_RST}"
    print ""
    log_error "FATAL: $*"
}

ui_final_ok() {
    print ""
    print -- "${C_BOLD}${C_GREEN}╔══════════════════════════════════════════════════════════════╗${C_RST}"
    print -- "${C_BOLD}${C_GREEN}║  SETUP COMPLETE — Fluxbox desktop ready. Reboot to start.   ║${C_RST}"
    print -- "${C_BOLD}${C_GREEN}╚══════════════════════════════════════════════════════════════╝${C_RST}"
    print ""
}

ui_final_fail() {
    print ""
    print -- "${C_BOLD}${C_RED}╔══════════════════════════════════════════════════════════════╗${C_RST}"
    print -- "${C_BOLD}${C_RED}║  SETUP INCOMPLETE — review log and re-run to resume.         ║${C_RST}"
    print -- "${C_BOLD}${C_RED}╚══════════════════════════════════════════════════════════════╝${C_RST}"
    print ""
}

log_init() {
    typeset ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    print -- "# ============================================================" >> "${LOGFILE}"
    print -- "# ${SCRIPT_NAME} ${SCRIPT_VERSION} — started ${ts}" >> "${LOGFILE}"
    print -- "# PID: ${SCRIPT_PID}" >> "${LOGFILE}"
    print -- "# ============================================================" >> "${LOGFILE}"
}

_log() {
    typeset level="$1"; shift
    typeset ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    print -- "[${ts}] [${level}] $*" >> "${LOGFILE}" 2>/dev/null || true
}

log_info()    { _log INFO    "$*"; }
log_warn()    { _log WARN    "$*"; }
log_error()   { _log ERROR   "$*"; }
log_debug()   { _log DEBUG   "$*"; }
log_stage()   { _log STAGE   "=== $* ==="; }
log_cmd()     { _log CMD     "$*"; }
log_result()  { _log RESULT  "exit=$1 for: $2"; }
log_hw()      { _log HW      "$*"; }
log_pkg()     { _log PKG     "$*"; }
log_svc()     { _log SVC     "$*"; }
log_file()    { _log FILE    "$*"; }
log_backup()  { _log BACKUP  "$*"; }
log_chk()     { _log CHKPT   "$*"; }

pkg_status_init() {
    [ -d "${STATE_DIR}" ] || mkdir -p "${STATE_DIR}"
    [ -f "${PACKAGE_HISTORY_FILE}" ] || print -- "package	status	attempt	timestamp	note" > "${PACKAGE_HISTORY_FILE}"
    print -- "package	status	attempt	timestamp	note" > "${PACKAGE_STATUS_FILE}"
}

pkg_status_record() {
    typeset pkg="$1" status="$2" note="${3:-}" ts tmp
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    note=$(print -- "${note}" | tr '\t\n' '  ')
    tmp="${PACKAGE_STATUS_FILE}.tmp.$$"
    {
        grep -v "^${pkg}\t" "${PACKAGE_STATUS_FILE}" 2>/dev/null || true
        print -- "${pkg}	${status}	${CURRENT_ATTEMPT}	${ts}	${note}"
    } > "${tmp}"
    mv -f "${tmp}" "${PACKAGE_STATUS_FILE}"
    print -- "${pkg}	${status}	${CURRENT_ATTEMPT}	${ts}	${note}" >> "${PACKAGE_HISTORY_FILE}"
    log_pkg "${pkg}: ${status} (attempt=${CURRENT_ATTEMPT} note=${note})"
}

clear_stage_checkpoints() {
    rm -f "${STATE_DIR}"/stage_*.done 2>/dev/null || true
    log_chk "Cleared all stage checkpoints"
}

chk_file() {
    print -- "${STAGE_PREFIX}${1}${STAGE_SUFFIX}"
}

chk_done() {
    typeset tag="$1"
    if [ "${FORCE_RERUN}" -eq 1 ]; then
        return 1
    fi
    [ -f "$(chk_file "${tag}")" ]
}

chk_mark() {
    typeset tag="$1"
    typeset ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    print -- "${ts}" > "$(chk_file "${tag}")"
    log_chk "Marked complete: ${tag}"
}

chk_clear() {
    typeset tag="$1"
    rm -f "$(chk_file "${tag}")" 2>/dev/null || true
    log_chk "Cleared: ${tag}"
}

chk_show_resume_status() {
    typeset f count
    count=0
    for f in "${STATE_DIR}"/stage_*.done; do
        [ -e "${f}" ] || break
        [ -f "${f}" ] || continue
        count=$(( count + 1 ))
    done
    if [ "${count}" -gt 0 ]; then
        ui_info "Resuming: ${count} stage(s) already completed."
        log_info "Resume mode: ${count} checkpoints found."
    fi
}

RC=0
run_cmd() {
    typeset desc="$1"; shift
    typeset stderr_tmp="${TMP_DIR}/stderr_$$"
    log_cmd "${desc}: $*"
    "$@" 2>"${stderr_tmp}"
    RC=$?
    if [ -s "${stderr_tmp}" ]; then
        log_debug "stderr: $(cat "${stderr_tmp}")"
    fi
    rm -f "${stderr_tmp}" 2>/dev/null || true
    log_result "${RC}" "${desc}"
    return "${RC}"
}

run_cmd_quiet() {
    typeset desc="$1"; shift
    typeset out_tmp="${TMP_DIR}/out_$$"
    log_cmd "QUIET ${desc}: $*"
    "$@" >"${out_tmp}" 2>&1
    RC=$?
    if [ -s "${out_tmp}" ]; then
        log_debug "output: $(cat "${out_tmp}")"
    fi
    rm -f "${out_tmp}" 2>/dev/null || true
    log_result "${RC}" "QUIET ${desc}"
    return "${RC}"
}

write_file() {
    typeset path="$1" owner="$2" mode="$3"
    typeset tmp="${path}.tmp.$$"
    typeset parent
    parent=$(dirname "${path}")
    [ -d "${parent}" ] || mkdir -p "${parent}" || return 1
    cat > "${tmp}" || return 1
    chown "${owner}" "${tmp}" || { rm -f "${tmp}" 2>/dev/null || true; return 1; }
    chmod "${mode}" "${tmp}" || { rm -f "${tmp}" 2>/dev/null || true; return 1; }
    mv -f "${tmp}" "${path}" || { rm -f "${tmp}" 2>/dev/null || true; return 1; }
    log_file "Written: ${path} owner=${owner} mode=${mode}"
}

backup_file() {
    typeset path="$1"
    typeset bak="${BACKUP_DIR}$(print -- "${path}" | tr '/' '_').bak"
    if [ -f "${path}" ] && [ ! -f "${bak}" ]; then
        cp -a "${path}" "${bak}"
        log_backup "Backed up: ${path} → ${bak}"
    fi
}

append_if_missing() {
    typeset file="$1" line="$2"
    if ! grep -qF "${line}" "${file}" 2>/dev/null; then
        print -- "${line}" >> "${file}"
        log_file "Appended to ${file}: ${line}"
    fi
}

ensure_dir() {
    typeset path="$1" owner="$2" mode="$3"
    if [ ! -d "${path}" ]; then
        mkdir -p "${path}"
        chown "${owner}" "${path}"
        chmod "${mode}" "${path}"
        log_file "Created dir: ${path} owner=${owner} mode=${mode}"
    fi
}

pkg_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

pkg_available() {
    pacman -Si "$1" >/dev/null 2>&1
}

pkg_provider_for_path() {
    typeset target="$1" provider=""
    provider=$(pacman -Fq "${target}" 2>/dev/null | head -1 | tr -d '[:space:]')
    if [ -z "${provider}" ]; then
        run_cmd_quiet "pacman -Fy" pacman -Fy --noconfirm
        provider=$(pacman -Fq "${target}" 2>/dev/null | head -1 | tr -d '[:space:]')
    fi
    [ -n "${provider}" ] || return 1
    print -- "${provider}"
}

svc_exists() {
    [ -f "/etc/init.d/$1" ]
}

svc_enabled() {
    typeset svc="$1" runlevel="${2:-default}"
    [ -L "/etc/runlevels/${runlevel}/${svc}" ]
}

svc_enable() {
    typeset svc="$1" runlevel="${2:-default}"
    if ! svc_enabled "${svc}" "${runlevel}"; then
        run_cmd_quiet "Enable ${svc}@${runlevel}" rc-update add "${svc}" "${runlevel}"
        if [ "${RC}" -eq 0 ] && svc_enabled "${svc}" "${runlevel}"; then
            log_svc "Enabled: ${svc} in runlevel ${runlevel}"
            ui_ok "Service enabled: ${svc} (${runlevel})"
            return 0
        fi

        if svc_exists "${svc}"; then
            mkdir -p "/etc/runlevels/${runlevel}" 2>/dev/null || true
            ln -sf "/etc/init.d/${svc}" "/etc/runlevels/${runlevel}/${svc}" 2>/dev/null || true
        fi

        if svc_enabled "${svc}" "${runlevel}"; then
            log_svc "Enabled via symlink fallback: ${svc} in runlevel ${runlevel}"
            ui_ok "Service enabled via fallback: ${svc} (${runlevel})"
        else
            log_warn "Failed to enable service: ${svc}"
            ui_warn "Could not enable service: ${svc}"
        fi
    else
        log_svc "Already enabled: ${svc}@${runlevel}"
        ui_skip "Service already enabled: ${svc}"
    fi
}

svc_disable() {
    typeset svc="$1" runlevel="${2:-default}"
    if svc_enabled "${svc}" "${runlevel}"; then
        run_cmd_quiet "Disable ${svc}@${runlevel}" rc-update del "${svc}" "${runlevel}"
        log_svc "Disabled: ${svc} in runlevel ${runlevel}"
        ui_ok "Service disabled: ${svc} (${runlevel})"
    fi
}

svc_require_enabled() {
    typeset svc="$1" runlevel="${2:-default}"
    svc_enable "${svc}" "${runlevel}"
    if svc_enabled "${svc}" "${runlevel}"; then
        log_svc "Verified enabled: ${svc}@${runlevel}"
        return 0
    fi
    log_error "Required service is not enabled: ${svc}@${runlevel}"
    ui_fail "Required service is not enabled: ${svc} (${runlevel})"
    return 1
}

svc_wait_active() {
    typeset svc="$1" max_wait="${2:-5}" i=1
    while [ "${i}" -le "${max_wait}" ]; do
        if rc-service "${svc}" status >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        i=$(( i + 1 ))
    done
    return 1
}

svc_start_or_restart() {
    typeset svc="$1"
    if rc-service "${svc}" status >/dev/null 2>&1; then
        run_cmd_quiet "Restart ${svc}" rc-service "${svc}" restart
    else
        run_cmd_quiet "Start ${svc}" rc-service "${svc}" start
    fi
    [ "${RC}" -eq 0 ] || return 1
    svc_wait_active "${svc}" 5 || return 1
    return 0
}

resolve_xdm_service_name() {
    if svc_exists xdm; then
        print -- "xdm"
        return 0
    fi
    return 1
}

xdm_server_path() {
    typeset candidate
    for candidate in /usr/bin/X /usr/bin/Xorg /usr/lib/Xorg /usr/libexec/Xorg; do
        if [ -x "${candidate}" ]; then
            print -- "${candidate}"
            return 0
        fi
    done
    if command -v X >/dev/null 2>&1; then
        command -v X
        return 0
    fi
    if command -v Xorg >/dev/null 2>&1; then
        command -v Xorg
        return 0
    fi
    return 1
}

xdm_activate_required() {
    if ! svc_exists xdm; then
        log_error "Required /etc/init.d/xdm is missing during activation"
        ui_fail "Required /etc/init.d/xdm is missing during activation"
        return 1
    fi

    svc_require_enabled xdm default || return 1

    if [ ! -f /etc/conf.d/xdm ] || ! grep -q '^DISPLAYMANAGER="xdm"$' /etc/conf.d/xdm 2>/dev/null; then
        log_error "/etc/conf.d/xdm missing or does not select xdm"
        ui_fail "/etc/conf.d/xdm is missing or does not select xdm"
        return 1
    fi

    if svc_start_or_restart xdm; then
        ui_ok "XDM service active: xdm"
        log_svc "XDM active: xdm"
        return 0
    fi

    run_cmd_quiet "Stop xdm" rc-service xdm stop
    sleep 1
    if svc_start_or_restart xdm; then
        ui_ok "XDM service active after stop/start fallback: xdm"
        log_svc "XDM active after stop/start fallback: xdm"
        return 0
    fi

    log_error "XDM service could not be started successfully"
    ui_fail "XDM service could not be started successfully"
    return 1
}

show_help() {
    print ""
    print -- "${C_BOLD}${SCRIPT_NAME}${C_RST} ${SCRIPT_VERSION}"
    print ""
    print "  Artix Linux OpenRC x86_64 — Fluxbox desktop post-installation."
    print ""
    print -- "${C_BOLD}USAGE${C_RST}"
    print "  ${SCRIPT_NAME} -u <user> -k <layout> [options]"
    print ""
    print -- "${C_BOLD}REQUIRED${C_RST}"
    print "  -u <user>     Target system username"
    print "  -k <layout>   X11 keyboard layout code (e.g. us  br  de  fr  pt)"
    print ""
    print -- "${C_BOLD}OPTIONAL${C_RST}"
    print "  -V <variant>  X11 keyboard variant  (e.g. intl  abnt2  dvorak)"
    print "  -m <model>    X11 keyboard model     (default: pc105)"
    print "  -o <options>  X11 keyboard options   (e.g. grp:alt_shift_toggle)"
    print "  -f            Force re-run all stages (ignore resume checkpoints)"
    print "  -R            Force reinstall packages during package stage"
    print "  -a            On any stage error, restart from stage 1 (max 5 attempts)"
    print "  -1            Use a GNOME 1-inspired Fluxbox style profile"
    print "  -h            Show this help and exit"
    print ""
    print -- "${C_BOLD}EXAMPLES${C_RST}"
    print "  ${SCRIPT_NAME} -u alice -k us"
    print "  ${SCRIPT_NAME} -u bob   -k br -V abnt2 -R"
    print "  ${SCRIPT_NAME} -u carol -k de -V nodeadkeys -m pc105 -a"
    print "  ${SCRIPT_NAME} -u dave  -k us -1"
    print ""
    print "  Log file:   ${LOGFILE}"
    print "  State dir:  ${STATE_DIR}"
    print "  Backup dir: ${BACKUP_DIR}"
    print ""
}

parse_args() {
    typeset opt
    while getopts "u:k:V:m:o:fRa1h" opt; do
        case "${opt}" in
            u) TARGET_USER="${OPTARG}" ;;
            k) KBD_LAYOUT="${OPTARG}" ;;
            V) KBD_VARIANT="${OPTARG}" ;;
            m) KBD_MODEL="${OPTARG}" ;;
            o) KBD_OPTIONS="${OPTARG}" ;;
            f) FORCE_RERUN=1 ;;
            R) FORCE_REINSTALL_PACKAGES=1 ;;
            a) AUTO_RETRY_ON_ERROR=1 ;;
            1) GNOME1_THEME=1 ;;
            h) show_help; exit 0 ;;
            ?) show_help; exit 2 ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    if [ -z "${TARGET_USER}" ] || [ -z "${KBD_LAYOUT}" ]; then
        print -- "${C_RED}ERROR: -u <user> and -k <layout> are both required.${C_RST}" >&2
        print ""
        show_help
        exit 2
    fi
}

validate_target_user() {
    ui_step "Validating target user: ${TARGET_USER}"

    case "${TARGET_USER}" in
        *[!a-z0-9_-]*) ui_fatal "Target user '${TARGET_USER}' contains invalid characters."; return 1 ;;
        -*)            ui_fatal "Target user name must not start with '-'."; return 1 ;;
        root)          ui_fatal "Target user must not be root."; return 1 ;;
    esac
    if [ "${#TARGET_USER}" -gt 32 ]; then
        ui_fatal "Target user name is too long (max 32 chars)."
        return 1
    fi

    if ! id "${TARGET_USER}" >/dev/null 2>&1; then
        ui_fatal "User '${TARGET_USER}' does not exist. Create the user first."
        return 1
    fi

    TARGET_HOME=$(getent passwd "${TARGET_USER}" | cut -d: -f6)
    TARGET_UID=$(id -u "${TARGET_USER}")
    TARGET_GID=$(id -g "${TARGET_USER}")

    if [ -z "${TARGET_HOME}" ] || [ ! -d "${TARGET_HOME}" ]; then
        ui_fatal "Home directory '${TARGET_HOME}' for user '${TARGET_USER}' does not exist."
        return 1
    fi

    log_info "Target user validated: ${TARGET_USER} uid=${TARGET_UID} gid=${TARGET_GID} home=${TARGET_HOME}"
    ui_ok "User: ${TARGET_USER} (uid=${TARGET_UID}, home=${TARGET_HOME})"
    return 0
}

validate_keyboard() {
    ui_step "Validating keyboard layout: ${KBD_LAYOUT}"

    case "${KBD_LAYOUT}" in
        *[!a-z0-9_-]*) ui_fatal "Keyboard layout '${KBD_LAYOUT}' contains invalid characters."; return 1 ;;
    esac

    typeset xkb_sym_dir="/usr/share/X11/xkb/symbols"

    if [ -d "${xkb_sym_dir}" ]; then
        if [ ! -f "${xkb_sym_dir}/${KBD_LAYOUT}" ]; then
            ui_fatal "XKB layout '${KBD_LAYOUT}' not found in ${xkb_sym_dir}."
            return 1
        fi
        ui_ok "XKB layout file found: ${xkb_sym_dir}/${KBD_LAYOUT}"
    else
        ui_info "XKB symbols dir not yet present; layout will be validated post-install."
        log_info "Deferred keyboard layout validation (xorg not yet installed)."
    fi

    if [ -n "${KBD_VARIANT}" ]; then
        case "${KBD_VARIANT}" in
            *[!a-z0-9_-]*) ui_fatal "Keyboard variant '${KBD_VARIANT}' contains invalid characters."; return 1 ;;
        esac
    fi

    if [ -n "${KBD_MODEL}" ]; then
        case "${KBD_MODEL}" in
            *[!a-z0-9_-]*) ui_fatal "Keyboard model '${KBD_MODEL}' contains invalid characters."; return 1 ;;
        esac
    fi

    log_info "Keyboard validated: layout=${KBD_LAYOUT} variant=${KBD_VARIANT} model=${KBD_MODEL} options=${KBD_OPTIONS}"
    ui_ok "Keyboard: layout=${KBD_LAYOUT} variant=${KBD_VARIANT:-none} model=${KBD_MODEL}"
    return 0
}

validate_artix_identity() {
    ui_step "Validating Artix Linux identity"

    if [ ! -f /etc/artix-release ] && [ ! -f /etc/os-release ]; then
        ui_fatal "Cannot identify OS. /etc/artix-release and /etc/os-release both missing."
        return 1
    fi

    typeset os_id=""
    if [ -f /etc/os-release ]; then
        os_id=$(. /etc/os-release 2>/dev/null && print -- "${ID:-}")
    fi
    if [ -f /etc/artix-release ]; then
        log_info "Found /etc/artix-release: $(cat /etc/artix-release | head -1)"
        ui_ok "Artix Linux identity confirmed via /etc/artix-release"
        return 0
    fi
    if [ "${os_id}" = "artix" ]; then
        log_info "Artix confirmed via /etc/os-release ID=artix"
        ui_ok "Artix Linux identity confirmed via /etc/os-release"
        return 0
    fi

    ui_fatal "This does not appear to be Artix Linux (ID='${os_id}'). Refusing to continue."
    return 1
}

validate_openrc() {
    ui_step "Validating OpenRC init system"

    typeset init1=""
    if [ -f /proc/1/comm ]; then
        init1=$(cat /proc/1/comm 2>/dev/null || true)
    fi

    if [ -d /run/openrc ] || rc-status >/dev/null 2>&1; then
        log_info "OpenRC confirmed: /run/openrc present or rc-status responds"
        ui_ok "OpenRC init system confirmed"
        return 0
    fi

    if [ "${init1}" = "systemd" ]; then
        ui_fatal "PID 1 is systemd. This script requires OpenRC. Wrong distribution?"
        return 1
    fi

    if command -v rc-update >/dev/null 2>&1 && command -v rc-service >/dev/null 2>&1; then
        log_info "OpenRC tools found (rc-update, rc-service)"
        ui_ok "OpenRC tools confirmed"
        return 0
    fi

    ui_fatal "OpenRC cannot be confirmed. rc-update/rc-service not found."
    return 1
}

validate_arch() {
    ui_step "Validating architecture"
    typeset arch
    arch=$(uname -m)
    HW_ARCH="${arch}"
    if [ "${arch}" != "x86_64" ]; then
        ui_fatal "Architecture '${arch}' is not x86_64. Refusing to continue."
        return 1
    fi
    log_hw "Architecture: ${arch}"
    ui_ok "Architecture: x86_64"
    return 0
}

stage_preflight() {
    ui_stage "01" "Preflight Validation"
    log_stage "PREFLIGHT"

    ui_step "Checking effective user (requires root)"
    if [ "$(id -u)" -ne 0 ]; then
        ui_fatal "This script must run as root. Use: sudo ${SCRIPT_NAME} ..."
        return 1
    fi
    ui_ok "Running as root"
    log_info "Effective UID: 0"

    validate_artix_identity || return 1

    validate_openrc || return 1

    validate_arch || return 1

    validate_target_user || return 1

    validate_keyboard || return 1

    ui_step "Checking package manager (pacman)"
    if ! command -v pacman >/dev/null 2>&1; then
        ui_fatal "pacman not found. Cannot manage packages."
        return 1
    fi
    ui_ok "pacman found"

    ui_step "Checking service manager (rc-update)"
    if ! command -v rc-update >/dev/null 2>&1; then
        ui_fatal "rc-update not found."
        return 1
    fi
    ui_ok "rc-update found"

    ui_step "Checking filesystem write access"
    for d in /etc /usr /var; do
        if ! touch "${d}/.artix_setup_write_test" 2>/dev/null; then
            ui_fatal "Cannot write to ${d}. Check filesystem state."
            return 1
        fi
        rm -f "${d}/.artix_setup_write_test"
    done
    ui_ok "Filesystem writable"

    ui_step "Initialising state and backup directories"
    mkdir -p "${STATE_DIR}" "${BACKUP_DIR}" "${TMP_DIR}"
    if [ $? -ne 0 ]; then
        ui_fatal "Cannot create state/backup/tmp directories."
        return 1
    fi
    chmod 700 "${STATE_DIR}" "${BACKUP_DIR}" "${TMP_DIR}"
    ui_ok "State dir: ${STATE_DIR}"
    ui_ok "Backup dir: ${BACKUP_DIR}"

    log_init
    log_info "Preflight validated."

    ui_sep
    print -- "  ${C_BOLD}Configuration Summary${C_RST}"
    ui_rule
    ui_kv "Target user"     "${TARGET_USER} (uid=${TARGET_UID})"
    ui_kv "Home directory"  "${TARGET_HOME}"
    ui_kv "Keyboard layout" "${KBD_LAYOUT}"
    ui_kv "Kbd variant"     "${KBD_VARIANT:-none}"
    ui_kv "Kbd model"       "${KBD_MODEL}"
    ui_kv "Kbd options"     "${KBD_OPTIONS:-none}"
    ui_kv "Force rerun"     "$([ "${FORCE_RERUN}" -eq 1 ] && print yes || print no)"
    ui_kv "Force reinstall" "$([ "${FORCE_REINSTALL_PACKAGES}" -eq 1 ] && print yes || print no)"
    ui_kv "Auto retry"      "$([ "${AUTO_RETRY_ON_ERROR}" -eq 1 ] && print yes || print no)"
    ui_kv "GNOME 1 style"   "$([ "${GNOME1_THEME}" -eq 1 ] && print yes || print no)"
    ui_kv "Log file"        "${LOGFILE}"
    ui_sep

    chk_mark "01_preflight"
    ui_ok "Preflight complete."
    return 0
}

stage_hardware() {
    ui_stage "02" "Hardware Discovery and Validation"
    log_stage "HARDWARE"

    ui_step "Detecting CPU"
    if [ -f /proc/cpuinfo ]; then
        HW_CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')
        HW_CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')
    fi
    if [ -z "${HW_CPU_MODEL}" ]; then
        HW_CPU_MODEL=$(uname -p)
        HW_CPU_VENDOR="unknown"
    fi
    log_hw "CPU vendor: ${HW_CPU_VENDOR}"
    log_hw "CPU model: ${HW_CPU_MODEL}"
    ui_ok "CPU: ${HW_CPU_MODEL}"

    case "${HW_CPU_VENDOR}" in
        GenuineIntel) HW_IS_INTEL_CPU=1; ui_ok "Intel CPU confirmed" ;;
        AuthenticAMD) ui_info "AMD CPU detected (Intel targeted; continuing)" ;;
        *)            ui_info "CPU vendor '${HW_CPU_VENDOR}' (Intel targeted; continuing)" ;;
    esac

    if [ "${HW_IS_INTEL_CPU}" -eq 1 ]; then
        if ! pkg_installed intel-ucode; then
            ui_info "Advisory: intel-ucode not installed. Recommend installing for stability."
            log_hw "Advisory: intel-ucode absent"
        else
            ui_ok "intel-ucode is installed"
        fi
    fi

    ui_step "Detecting GPU"
    if command -v lspci >/dev/null 2>&1; then
        HW_GPU_LINE=$(lspci 2>/dev/null | grep -iE 'VGA compatible|Display controller|3D controller' | head -3 || true)
    fi
    log_hw "GPU line(s): ${HW_GPU_LINE}"

    if print -- "${HW_GPU_LINE}" | grep -qi intel; then
        HW_IS_INTEL_GPU=1
        ui_ok "Intel GPU detected"

        HW_LOADED_GFX_MODULES=$(lsmod 2>/dev/null | awk 'NR>1 {print $1}' | grep -E '^(i915|xe|nouveau|amdgpu|radeon)$' | tr '\n' ' ' || true)
        log_hw "Loaded gfx modules: ${HW_LOADED_GFX_MODULES}"

        if print -- "${HW_LOADED_GFX_MODULES}" | grep -qE 'i915|xe'; then
            HW_GPU_DRIVER_RECOMMENDED="modesetting"
            ui_ok "Intel KMS module active (i915/xe) — using modesetting DDX"
            log_hw "Recommended X driver: modesetting"
        else
            HW_GPU_DRIVER_RECOMMENDED="intel"
            ui_info "No i915/xe detected yet — recommending xf86-video-intel DDX"
            log_hw "Recommended X driver: intel (xf86-video-intel)"
        fi
    else
        HW_IS_INTEL_GPU=0
        if [ -n "${HW_GPU_LINE}" ]; then
            ui_warn "Non-Intel GPU detected: ${HW_GPU_LINE}"
            ui_warn "This script targets Intel graphics. Continuing in degraded mode."
            ui_warn "Intel-specific Mesa/Vulkan will not be installed."
            log_hw "Degraded mode: non-Intel GPU"
        else
            ui_warn "No GPU detected via lspci. X may fail to start."
            log_hw "No GPU found — X startup unreliable"
        fi
    fi

    ui_step "Checking DRM/KMS status"
    if ls /sys/class/drm/ >/dev/null 2>&1; then
        typeset drm_cards
        drm_cards=$(ls /sys/class/drm/ 2>/dev/null | grep -E '^card[0-9]+$' | tr '\n' ' ')
        log_hw "DRM cards: ${drm_cards}"
        ui_ok "DRM/KMS: ${drm_cards:-none visible yet}"
    else
        ui_info "DRM class not visible (may normalise post-boot with modesetting)"
    fi

    ui_step "Detecting audio hardware"
    if command -v lspci >/dev/null 2>&1; then
        HW_AUDIO_CONTROLLERS=$(lspci 2>/dev/null | grep -i 'audio\|sound\|multimedia' || true)
    fi
    if [ -n "${HW_AUDIO_CONTROLLERS}" ]; then
        HW_HAS_AUDIO=1
        log_hw "Audio controllers: ${HW_AUDIO_CONTROLLERS}"
        ui_ok "Audio hardware found"
    else
        if ls /proc/asound/ >/dev/null 2>&1; then
            HW_HAS_AUDIO=1
            ui_ok "Audio visible via /proc/asound"
        else
            ui_warn "No audio hardware detected. Audio may not function."
            log_hw "No audio detected"
        fi
    fi

    ui_step "Checking laptop/battery indicators"
    if ls /sys/class/power_supply/ 2>/dev/null | grep -q '^BAT'; then
        HW_IS_LAPTOP=1
        HW_HAS_BATTERY=1
        ui_ok "Battery found — laptop profile"
        log_hw "Laptop: yes (battery present)"
    else
        ui_info "No battery detected — desktop profile"
        log_hw "Laptop: no"
    fi
    if ls /sys/class/backlight/ 2>/dev/null | grep -q '.'; then
        HW_HAS_BACKLIGHT=1
        ui_ok "Backlight device found"
        log_hw "Backlight: yes"
    fi

    ui_step "Detecting network interfaces"
    HW_NET_ADAPTERS=$(ip link show 2>/dev/null | grep -E '^[0-9]+:' | awk -F': ' '{print $2}' | grep -v '^lo$' | tr '\n' ' ')
    log_hw "Network adapters: ${HW_NET_ADAPTERS}"
    ui_ok "Network interfaces: ${HW_NET_ADAPTERS:-none visible}"

    if command -v iw >/dev/null 2>&1; then
        if iw dev 2>/dev/null | grep -q 'Interface'; then
            HW_HAS_WIRELESS=1
            ui_ok "Wireless interface detected"
            log_hw "Wireless: yes"
        fi
    elif ls /sys/class/net/ 2>/dev/null | grep -qE '^(wl|wlan)'; then
        HW_HAS_WIRELESS=1
        ui_ok "Wireless interface found via sysfs"
        log_hw "Wireless: yes (sysfs)"
    fi

    ui_step "Checking display outputs"
    if ls /sys/class/drm/ 2>/dev/null | grep -qE 'card[0-9]+-'; then
        typeset outputs
        outputs=$(ls /sys/class/drm/ 2>/dev/null | grep -E 'card[0-9]+-' | tr '\n' ' ')
        log_hw "Display outputs: ${outputs}"
        ui_ok "Display outputs: ${outputs}"
    else
        ui_info "Display outputs not yet visible in sysfs (normal pre-X)"
    fi

    ui_step "Noting storage controllers (informational)"
    if command -v lspci >/dev/null 2>&1; then
        typeset storage
        storage=$(lspci 2>/dev/null | grep -i 'SATA\|NVMe\|AHCI\|RAID\|storage' | head -3 || true)
        log_hw "Storage: ${storage}"
        ui_info "Storage: ${storage:-not enumerated}"
    fi

    log_info "Hardware discovery complete. Intel GPU=${HW_IS_INTEL_GPU} Laptop=${HW_IS_LAPTOP} Audio=${HW_HAS_AUDIO}"
    chk_mark "02_hardware"
    ui_ok "Hardware discovery complete."
    return 0
}

build_package_list() {
    typeset -a PKGS

    PKGS=(
        xorg-server
        xorg-xinit
        xorg-xdm
        xorg-xrandr
        xorg-xset
        xorg-xsetroot
        xorg-xauth
        xorg-xinput
        xorg-xprop
        xorg-xdpyinfo
        xf86-input-libinput
    )

    if [ "${HW_IS_LAPTOP}" -eq 1 ]; then
        PKGS=( "${PKGS[@]}" xorg-xbacklight )
    fi

    if [ "${HW_IS_INTEL_GPU}" -eq 1 ]; then
        PKGS=( "${PKGS[@]}"
            mesa
            intel-media-driver
            vulkan-intel
            libva-utils
        )
        if [ "${HW_GPU_DRIVER_RECOMMENDED}" = "intel" ]; then
            PKGS=( "${PKGS[@]}" xf86-video-intel )
        fi
        PKG_INTEL_GPU_AVAILABLE=1
    else
        PKGS=( "${PKGS[@]}" mesa )
        ui_warn "Intel GPU packages skipped — non-Intel hardware."
    fi

    PKGS=( "${PKGS[@]}"
        ttf-dejavu
        ttf-liberation
        noto-fonts
        noto-fonts-emoji
        xorg-fonts-misc
    )

    PKGS=( "${PKGS[@]}"
        fluxbox
        feh
        dunst
        picom
    )

    PKGS=( "${PKGS[@]}"
        xterm
    )
    if pkg_available xorg-xrdb; then
        PKGS=( "${PKGS[@]}" xorg-xrdb )
    fi

    PKGS=( "${PKGS[@]}"
        alsa-utils
        pipewire
        pipewire-alsa
        pipewire-pulse
        wireplumber
        pavucontrol
    )

    PKGS=( "${PKGS[@]}"
        mpv
        ffmpeg
        sxiv
        zathura
        zathura-pdf-mupdf
        scrot
    )

    PKGS=( "${PKGS[@]}"
        base-devel
        git
        openssh
        vim
        nano
        curl
        wget
        unzip
        zip
        rsync
        lsof
        strace
        net-tools
        inetutils
        bind
    )

    PKGS=( "${PKGS[@]}"
        htop
        lm_sensors
        iotop
        lshw
        pciutils
        usbutils
        dmidecode
    )

    PKGS=( "${PKGS[@]}"
        libreoffice-fresh
    )

    PKGS=( "${PKGS[@]}"
        firefox
    )

    PKGS=( "${PKGS[@]}"
        pcmanfm
        xclip
        galculator
        network-manager-applet
    )

    PKGS=( "${PKGS[@]}"
        networkmanager
    )
    if pkg_available networkmanager-openrc; then
        PKGS=( "${PKGS[@]}" networkmanager-openrc )
    fi

    if pkg_available elogind; then
        PKGS=( "${PKGS[@]}" elogind )
        if pkg_available elogind-openrc; then
            PKGS=( "${PKGS[@]}" elogind-openrc )
        fi
    fi
    if pkg_available acpid; then
        PKGS=( "${PKGS[@]}" acpid )
        if pkg_available acpid-openrc; then
            PKGS=( "${PKGS[@]}" acpid-openrc )
        fi
    fi

    print -- "${PKGS[@]}"
}

stage_packages() {
    ui_stage "03" "Package Installation"
    log_stage "PACKAGES"

    ui_step "Building package list"
    typeset pkg_list
    pkg_list=$(build_package_list)
    log_pkg "Package list: ${pkg_list}"
    ui_info "Packages queued: $(print -- "${pkg_list}" | wc -w | tr -d ' ')"

    pkg_status_init

    ui_step "Synchronising package databases"
    run_cmd_quiet "pacman -Sy" pacman -Sy --noconfirm
    if [ "${RC}" -ne 0 ]; then
        ui_warn "Database sync returned non-zero. Continuing (may be already fresh)."
    else
        ui_ok "Package databases synchronised"
    fi

    ui_step "Installing packages (this may take several minutes)"
    typeset pkg failed_pkgs="" installed_count=0 skip_count=0 fail_count=0 reinstalled_count=0

    for pkg in ${pkg_list}; do
        if [ "${FORCE_REINSTALL_PACKAGES}" -eq 1 ]; then
            run_cmd_quiet "Reinstall ${pkg}" pacman -S --noconfirm "${pkg}"
            if [ "${RC}" -eq 0 ]; then
                pkg_status_record "${pkg}" "reinstalled" "pacman -S"
                ui_ok "Reinstalled: ${pkg}"
                reinstalled_count=$(( reinstalled_count + 1 ))
            else
                pkg_status_record "${pkg}" "reinstall_failed" "pacman returned ${RC}"
                log_warn "Failed to reinstall: ${pkg}"
                ui_warn "Package reinstall failed: ${pkg}"
                failed_pkgs="${failed_pkgs} ${pkg}"
                fail_count=$(( fail_count + 1 ))
            fi
            continue
        fi

        if pkg_installed "${pkg}"; then
            pkg_status_record "${pkg}" "present" "already installed"
            ui_skip "Already present: ${pkg}"
            skip_count=$(( skip_count + 1 ))
            continue
        fi

        run_cmd_quiet "Install ${pkg}" pacman -S --noconfirm --needed "${pkg}"
        if [ "${RC}" -eq 0 ]; then
            pkg_status_record "${pkg}" "installed" "fresh install"
            ui_ok "Installed: ${pkg}"
            installed_count=$(( installed_count + 1 ))
        else
            pkg_status_record "${pkg}" "install_failed" "pacman returned ${RC}"
            log_warn "Failed to install: ${pkg}"
            ui_warn "Package unavailable or failed: ${pkg}"
            failed_pkgs="${failed_pkgs} ${pkg}"
            fail_count=$(( fail_count + 1 ))
        fi
    done

    if [ "${FORCE_REINSTALL_PACKAGES}" -eq 1 ]; then
        ui_ok "Reinstalled: ${reinstalled_count} packages"
    else
        ui_ok "Installed: ${installed_count} packages"
        ui_skip "Already present: ${skip_count} packages"
    fi
    ui_info "Package status file: ${PACKAGE_STATUS_FILE}"
    ui_info "Package history file: ${PACKAGE_HISTORY_FILE}"

    if [ "${fail_count}" -gt 0 ]; then
        ui_warn "Failed packages (${fail_count}): ${failed_pkgs}"
        log_warn "Failed packages: ${failed_pkgs}"
    fi

    ui_step "Validating critical packages"
    typeset critical_ok=1
    for pkg in xorg-server xorg-xdm fluxbox alsa-utils pipewire networkmanager; do
        if ! pkg_installed "${pkg}"; then
            pkg_status_record "${pkg}" "critical_missing" "validation failed"
            ui_fail "Critical package missing: ${pkg}"
            log_error "Critical package missing after install: ${pkg}"
            critical_ok=0
        fi
    done
    if ! command -v xdm >/dev/null 2>&1; then
        ui_fail "Critical binary missing: xdm"
        log_error "xdm binary missing after package installation"
        critical_ok=0
    fi
    if ! command -v xrdb >/dev/null 2>&1; then
        ui_warn "xrdb binary not yet present after base package installation"
        log_warn "xrdb binary missing after base package installation"
    fi
    if [ "${critical_ok}" -eq 0 ]; then
        ui_fatal "One or more critical packages failed to install. Check log, package status file, and network."
        return 1
    fi
    ui_ok "Critical packages verified"

    ui_step "Ensuring /etc/init.d/xdm exists"
    typeset xdm_provider=""
    if ! svc_exists xdm; then
        xdm_provider=$(pkg_provider_for_path /etc/init.d/xdm) || {
            ui_fatal "Cannot find a package provider for /etc/init.d/xdm. Refresh mirrors or inspect pacman -F /etc/init.d/xdm."
            log_error "No package provider found for /etc/init.d/xdm"
            return 1
        }
        ui_info "Package providing /etc/init.d/xdm: ${xdm_provider}"

        if [ "${FORCE_REINSTALL_PACKAGES}" -eq 1 ]; then
            run_cmd_quiet "Reinstall ${xdm_provider}" pacman -S --noconfirm "${xdm_provider}"
            if [ "${RC}" -eq 0 ]; then
                pkg_status_record "${xdm_provider}" "reinstalled" "provider for /etc/init.d/xdm"
                ui_ok "Reinstalled XDM init provider: ${xdm_provider}"
            else
                pkg_status_record "${xdm_provider}" "reinstall_failed" "provider for /etc/init.d/xdm"
                ui_fatal "Failed to reinstall the package provider for /etc/init.d/xdm: ${xdm_provider}"
                return 1
            fi
        elif pkg_installed "${xdm_provider}"; then
            pkg_status_record "${xdm_provider}" "present" "/etc/init.d/xdm provider already installed"
            ui_skip "XDM init provider already installed: ${xdm_provider}"
        else
            run_cmd_quiet "Install ${xdm_provider}" pacman -S --noconfirm --needed "${xdm_provider}"
            if [ "${RC}" -eq 0 ]; then
                pkg_status_record "${xdm_provider}" "installed" "provider for /etc/init.d/xdm"
                ui_ok "Installed XDM init provider: ${xdm_provider}"
            else
                pkg_status_record "${xdm_provider}" "install_failed" "provider for /etc/init.d/xdm"
                ui_fatal "Failed to install the package provider for /etc/init.d/xdm: ${xdm_provider}"
                return 1
            fi
        fi
    fi

    if ! svc_exists xdm; then
        ui_fatal "Required /etc/init.d/xdm is still missing after package installation."
        log_error "/etc/init.d/xdm still missing after provider handling"
        return 1
    fi
    ui_ok "XDM init script present: /etc/init.d/xdm"

    ui_step "Ensuring xrdb is present for persistent XTerm theme activation"
    typeset xrdb_provider=""
    if ! command -v xrdb >/dev/null 2>&1; then
        xrdb_provider=$(pkg_provider_for_path /usr/bin/xrdb) || {
            ui_fatal "Cannot find a package provider for /usr/bin/xrdb. Refresh mirrors or inspect pacman -F /usr/bin/xrdb."
            log_error "No package provider found for /usr/bin/xrdb"
            return 1
        }
        ui_info "Package providing /usr/bin/xrdb: ${xrdb_provider}"

        if [ "${FORCE_REINSTALL_PACKAGES}" -eq 1 ]; then
            run_cmd_quiet "Reinstall ${xrdb_provider}" pacman -S --noconfirm "${xrdb_provider}"
            if [ "${RC}" -eq 0 ]; then
                pkg_status_record "${xrdb_provider}" "reinstalled" "provider for /usr/bin/xrdb"
                ui_ok "Reinstalled xrdb provider: ${xrdb_provider}"
            else
                pkg_status_record "${xrdb_provider}" "reinstall_failed" "provider for /usr/bin/xrdb"
                ui_fatal "Failed to reinstall the package provider for /usr/bin/xrdb: ${xrdb_provider}"
                return 1
            fi
        elif pkg_installed "${xrdb_provider}"; then
            pkg_status_record "${xrdb_provider}" "present" "/usr/bin/xrdb provider already installed"
            ui_skip "xrdb provider already installed: ${xrdb_provider}"
        else
            run_cmd_quiet "Install ${xrdb_provider}" pacman -S --noconfirm --needed "${xrdb_provider}"
            if [ "${RC}" -eq 0 ]; then
                pkg_status_record "${xrdb_provider}" "installed" "provider for /usr/bin/xrdb"
                ui_ok "Installed xrdb provider: ${xrdb_provider}"
            else
                pkg_status_record "${xrdb_provider}" "install_failed" "provider for /usr/bin/xrdb"
                ui_fatal "Failed to install the package provider for /usr/bin/xrdb: ${xrdb_provider}"
                return 1
            fi
        fi
    fi

    if ! command -v xrdb >/dev/null 2>&1; then
        ui_fatal "Required binary xrdb is still missing after package installation. XTerm theme persistence cannot work safely."
        log_error "xrdb still missing after provider handling"
        return 1
    fi
    ui_ok "xrdb present: $(command -v xrdb)"

    typeset xkb_sym_dir="/usr/share/X11/xkb/symbols"
    if [ -d "${xkb_sym_dir}" ] && [ ! -f "${xkb_sym_dir}/${KBD_LAYOUT}" ]; then
        ui_fatal "XKB layout '${KBD_LAYOUT}' not found in ${xkb_sym_dir} after xorg install."
        return 1
    fi
    ui_ok "XKB layout confirmed post-install"

    chk_mark "03_packages"
    ui_ok "Package installation complete."
    return 0
}

stage_services() {
    ui_stage "04" "OpenRC Service Configuration"
    log_stage "SERVICES"

    ui_step "Checking for conflicting display managers"
    typeset dm
    for dm in lightdm sddm gdm lxdm slim; do
        if svc_exists "${dm}"; then
            svc_disable "${dm}" default
            ui_warn "Disabled conflicting DM: ${dm}"
            log_svc "Disabled conflicting DM: ${dm}"
        fi
    done

    ui_step "Resolving required XDM service"
    if ! svc_exists xdm; then
        ui_fatal "Required /etc/init.d/xdm is missing. Package stage should have installed its provider."
        log_error "/etc/init.d/xdm missing before service enablement"
        return 1
    fi
    ui_ok "XDM init script: xdm"

    ui_step "Enabling required XDM service"
    svc_require_enabled xdm default || return 1

    ui_step "Configuring NetworkManager service"
    if svc_exists NetworkManager; then
        svc_enable NetworkManager default
    elif svc_exists networkmanager; then
        svc_enable networkmanager default
    else
        ui_warn "NetworkManager service not found. Network may require manual setup."
    fi

    ui_step "Configuring elogind service"
    if svc_exists elogind; then
        svc_enable elogind boot
    else
        ui_info "elogind service not found (optional for basic Fluxbox)"
    fi

    ui_step "Configuring acpid service"
    if svc_exists acpid; then
        svc_enable acpid default
        ui_ok "acpid enabled"
    else
        ui_info "acpid service not found (optional)"
    fi

    ui_step "Configuring ALSA sound service"
    if svc_exists alsasound; then
        svc_enable alsasound boot
    else
        ui_info "alsasound service not found (ALSA state save optional)"
    fi

    ui_step "Configuring D-Bus service"
    if svc_exists dbus; then
        svc_enable dbus default
    else
        ui_warn "dbus service not found. Desktop apps may misbehave."
    fi

    ui_info "PipeWire will be started as a user session process from Fluxbox startup"
    log_svc "PipeWire: user-session, started via ~/.fluxbox/startup"

    chk_mark "04_services"
    ui_ok "Service configuration complete."
    return 0
}

stage_graphics() {
    ui_stage "05" "Graphics and X11 Configuration"
    log_stage "GRAPHICS"

    typeset xorg_conf_d="/etc/X11/xorg.conf.d"
    ensure_dir "${xorg_conf_d}" "root:root" "755"

    ui_step "Writing X11 keyboard configuration"
    typeset kbd_conf="${xorg_conf_d}/00-keyboard.conf"
    backup_file "${kbd_conf}"

    typeset variant_line="" options_line=""
    if [ -n "${KBD_VARIANT}" ]; then
        variant_line="    Option \"XkbVariant\" \"${KBD_VARIANT}\""
    fi
    if [ -n "${KBD_OPTIONS}" ]; then
        options_line="    Option \"XkbOptions\" \"${KBD_OPTIONS}\""
    fi

    write_file "${kbd_conf}" "root:root" "644" <<KBDCONF
# X11 keyboard configuration — managed by ${SCRIPT_NAME}
Section "InputClass"
    Identifier    "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout"  "${KBD_LAYOUT}"
    Option "XkbModel"   "${KBD_MODEL}"
${variant_line}
${options_line}
EndSection
KBDCONF
    ui_ok "Keyboard xorg config: ${kbd_conf}"
    log_file "Wrote ${kbd_conf}"

    if [ "${HW_IS_INTEL_GPU}" -eq 1 ]; then
        ui_step "Writing Intel GPU X11 configuration"
        typeset gpu_conf="${xorg_conf_d}/20-intel.conf"
        backup_file "${gpu_conf}"

        if [ "${HW_GPU_DRIVER_RECOMMENDED}" = "modesetting" ]; then
            write_file "${gpu_conf}" "root:root" "644" <<GPUCONF
# Intel GPU — modesetting DDX
# Managed by ${SCRIPT_NAME}
Section "Device"
    Identifier  "Intel"
    Driver      "modesetting"
    Option      "AccelMethod" "glamor"
    Option      "DRI"         "3"
EndSection
GPUCONF
            ui_ok "Intel GPU: modesetting driver configured"
        else
            write_file "${gpu_conf}" "root:root" "644" <<GPUCONF
# Intel GPU — xf86-video-intel DDX
# Managed by ${SCRIPT_NAME}
Section "Device"
    Identifier  "Intel"
    Driver      "intel"
    Option      "AccelMethod" "sna"
    Option      "DRI"         "3"
    Option      "TearFree"    "true"
EndSection
GPUCONF
            ui_ok "Intel GPU: intel DDX (SNA+TearFree) configured"
        fi
        log_file "Wrote ${gpu_conf}"
    else
        ui_info "Skipping Intel GPU xorg config (non-Intel hardware)"
    fi

    if [ "${HW_IS_LAPTOP}" -eq 1 ]; then
        ui_step "Writing libinput touchpad configuration"
        typeset tp_conf="${xorg_conf_d}/30-touchpad.conf"
        backup_file "${tp_conf}"
        write_file "${tp_conf}" "root:root" "644" <<TPCONF
# Touchpad configuration — managed by ${SCRIPT_NAME}
Section "InputClass"
    Identifier  "touchpad"
    Driver      "libinput"
    MatchIsTouchpad "on"
    Option      "Tapping"          "on"
    Option      "TappingButtonMap" "lrm"
    Option      "NaturalScrolling" "false"
    Option      "DisableWhileTyping" "on"
EndSection
TPCONF
        ui_ok "Touchpad configuration written"
        log_file "Wrote ${tp_conf}"
    fi

    ui_step "Configuring console keyboard layout"
    typeset keymaps_conf="/etc/conf.d/keymaps"
    if [ -f "${keymaps_conf}" ]; then
        backup_file "${keymaps_conf}"
    fi
    write_file "${keymaps_conf}" "root:root" "644" <<KEYMAPS
# Console keymap — managed by ${SCRIPT_NAME}
keymap="${KBD_LAYOUT}"
KEYMAPS
    ui_ok "Console keymap set to: ${KBD_LAYOUT}"
    log_file "Wrote ${keymaps_conf}"

    chk_mark "05_graphics"
    ui_ok "Graphics and X11 configuration complete."
    return 0
}

stage_xdm() {
    ui_stage "06" "XDM Display Manager Configuration"
    log_stage "XDM"

    typeset xdm_dir="/etc/X11/xdm"
    typeset xdm_vardir="/var/lib/xdm"
    typeset xdm_confdir="/etc/conf.d"
    typeset xdm_service_conf="${xdm_confdir}/xdm"
    typeset x_server_bin

    if ! svc_exists xdm; then
        ui_fatal "Cannot locate /etc/init.d/xdm. XDM is a hard requirement."
        return 1
    fi

    if ! command -v xdm >/dev/null 2>&1; then
        ui_fatal "The xdm binary is missing even though XDM is required. Ensure xorg-xdm installed correctly."
        return 1
    fi

    x_server_bin=$(xdm_server_path) || {
        ui_fatal "Cannot locate the X server binary (X/Xorg)."
        return 1
    }

    ensure_dir "${xdm_dir}" "root:root" "755"
    ensure_dir "${xdm_vardir}" "root:root" "755"
    ensure_dir "${xdm_confdir}" "root:root" "755"

    ui_step "Writing OpenRC display manager selector"
    backup_file "${xdm_service_conf}"
    write_file "${xdm_service_conf}" "root:root" "644" <<'XDMCONF'
DISPLAYMANAGER="xdm"
XDMCONF
    ui_ok "/etc/conf.d/xdm configured for xdm"

    ui_step "Writing XDM configuration"
    typeset xdm_config="${xdm_dir}/xdm-config"
    backup_file "${xdm_config}"

    write_file "${xdm_config}" "root:root" "644" <<XDMCFG
! XDM configuration — managed by ${SCRIPT_NAME}
DisplayManager.authDir:                 /var/lib/xdm
DisplayManager.errorLogFile:            /var/log/xdm-error.log
DisplayManager.pidFile:                 /var/run/xdm.pid
DisplayManager.keyFile:                 /var/lib/xdm/xdm-keys
DisplayManager.servers:                 /etc/X11/xdm/Xservers
DisplayManager.accessFile:              /etc/X11/xdm/Xaccess
DisplayManager*resources:               /etc/X11/xdm/Xresources
DisplayManager*session:                 /etc/X11/xdm/Xsession
DisplayManager*login.Login.width:       250
DisplayManager*login.Login.height:      200
DisplayManager*login.Login.x:           524
DisplayManager*login.Login.y:           384
DisplayManager._0.authorize:            true
DisplayManager*authorize:               false
XDMCFG
    ui_ok "xdm-config written"

    ui_step "Writing Xservers file"
    write_file "${xdm_dir}/Xservers" "root:root" "644" <<XSERVERS
# Xservers — managed by ${SCRIPT_NAME}
:0 local ${x_server_bin} :0 vt7 -nolisten tcp
XSERVERS
    ui_ok "Xservers configured"

    ui_step "Writing Xaccess file"
    write_file "${xdm_dir}/Xaccess" "root:root" "644" <<XACCESS
# Xaccess — managed by ${SCRIPT_NAME}
# Only local displays (no XDMCP)
XACCESS
    ui_ok "Xaccess configured (local only)"

    ui_step "Writing minimal XDM Xresources override"
    write_file "${xdm_dir}/Xresources" "root:root" "644" <<XRES
! Minimal XDM resource override — managed by ${SCRIPT_NAME}
xlogin*greeting:          Artix
XRES
    ui_ok "Minimal XDM Xresources written"

    ui_step "Writing XDM Xsession script"
    write_file "${xdm_dir}/Xsession" "root:root" "755" <<'XSESS'
#!/bin/sh
# XDM Xsession — managed by artix-fluxbox-setup.ksh
# Dispatches to user's ~/.xsession if present and executable.

# Safety: ensure PATH is sane
PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin
export PATH

# Source system profile
if [ -f /etc/profile ]; then
    . /etc/profile
fi

# Source user profile if it exists
if [ -f "${HOME}/.profile" ]; then
    . "${HOME}/.profile"
fi

# Run user's xsession if executable
if [ -x "${HOME}/.xsession" ]; then
    exec "${HOME}/.xsession"
fi

# Fallback: run .xinitrc if executable
if [ -x "${HOME}/.xinitrc" ]; then
    exec "${HOME}/.xinitrc"
fi

# Hard fallback: launch Fluxbox directly
exec /usr/bin/fluxbox
XSESS
    ui_ok "XDM Xsession script written"

    ui_step "Removing custom Xsetup_0 override"
    backup_file "${xdm_dir}/Xsetup_0"
    rm -f "${xdm_dir}/Xsetup_0"
    ui_ok "Custom Xsetup_0 removed"

    log_info "XDM configuration complete in ${xdm_dir}"
    chk_mark "06_xdm"
    ui_ok "XDM configuration complete."
    return 0
}

write_user_file() {
    typeset path="$1" mode="$2"
    typeset tmp="${path}.tmp.$$"
    typeset parent
    parent=$(dirname "${path}")
    [ -d "${parent}" ] || mkdir -p "${parent}" || return 1
    cat > "${tmp}" || return 1
    chown "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "${tmp}" || { rm -f "${tmp}" 2>/dev/null || true; return 1; }
    chmod "${mode}" "${tmp}" || { rm -f "${tmp}" 2>/dev/null || true; return 1; }
    mv -f "${tmp}" "${path}" || { rm -f "${tmp}" 2>/dev/null || true; return 1; }
    log_file "User file written: ${path} mode=${mode}"
}

stage_fluxbox() {
    ui_stage "07" "Fluxbox Desktop Configuration"
    log_stage "FLUXBOX"

    typeset fb_dir="${TARGET_HOME}/.fluxbox"
    typeset fb_style_dir="${fb_dir}/styles"
    typeset xsession_path="${TARGET_HOME}/.xsession"
    typeset user_group
    typeset fb_style_name="bloe"
    typeset fb_style_path="/usr/share/fluxbox/styles/bloe"
    typeset fb_style_cfg=""
    typeset fb_root_bg="#1a1a2e"

    user_group=$(id -gn "${TARGET_USER}")

    ensure_dir "${fb_dir}" "${TARGET_USER}:${user_group}" "700"
    ensure_dir "${fb_style_dir}" "${TARGET_USER}:${user_group}" "755"

    if [ "${GNOME1_THEME}" -eq 1 ]; then
        fb_style_name="gnome1-strong"
        fb_style_path="${fb_style_dir}/${fb_style_name}"
        fb_style_cfg="${fb_style_path}/theme.cfg"
        fb_root_bg="#2f6b68"
        ensure_dir "${fb_style_path}" "${TARGET_USER}:${user_group}" "755"
        ui_step "Writing GNOME 1-inspired Fluxbox style"
        write_user_file "${fb_style_cfg}" "644" <<'FBSTYLE'
window.font: Sans-10
window.justify: Center
window.title.height: 22
window.label.focus.textColor: #ffffff
window.label.unfocus.textColor: #000000
window.button.focus.picColor: #ffffff
window.button.unfocus.picColor: #3a3a3a
window.borderWidth: 1
window.borderColor: #6f777d
window.bevelWidth: 1
window.handleWidth: 4
window.title.focus: Flat Solid
window.title.focus.color: #345d92
window.title.focus.colorTo: #345d92
window.title.unfocus: Flat Solid
window.title.unfocus.color: #c9c9c2
window.title.unfocus.colorTo: #c9c9c2
window.label.focus: ParentRelative
window.label.unfocus: ParentRelative
window.handle.focus: Flat Solid
window.handle.focus.color: #c9c9c2
window.handle.unfocus: Flat Solid
window.handle.unfocus.color: #c9c9c2
window.grip.focus: Flat Solid
window.grip.focus.color: #6f777d
window.grip.unfocus: Flat Solid
window.grip.unfocus.color: #8a8f95

menu.title.font: Sans:bold:size=10
menu.title.justify: Center
menu.title: Raised Bevel1 Gradient Vertical
menu.title.color: #345d92
menu.title.colorTo: #274971
menu.title.textColor: #ffffff
menu.frame.font: Sans-10
menu.frame: Flat Solid
menu.frame.color: #d7d7d1
menu.frame.textColor: #000000
menu.hilite: Flat Solid
menu.hilite.color: #345d92
menu.hilite.textColor: #ffffff
menu.borderWidth: 1
menu.borderColor: #6f777d

toolbar.font: Sans:bold:size=10
toolbar.justify: Center
toolbar.height: 24
toolbar: Flat Solid
toolbar.color: #c9c9c2
toolbar.colorTo: #c9c9c2
toolbar.borderWidth: 1
toolbar.borderColor: #6f777d
toolbar.button: Raised Bevel1 Gradient Vertical
toolbar.button.color: #dfdfd8
toolbar.button.colorTo: #bdbdb5
toolbar.button.picColor: #2e3440
toolbar.clock: ParentRelative
toolbar.clock.textColor: #000000
toolbar.workspace: Raised Bevel1 Gradient Vertical
toolbar.workspace.color: #dfdfd8
toolbar.workspace.colorTo: #bdbdb5
toolbar.workspace.textColor: #000000
toolbar.iconbar.focused: Raised Bevel1 Gradient Vertical
toolbar.iconbar.focused.color: #345d92
toolbar.iconbar.focused.colorTo: #274971
toolbar.iconbar.focused.textColor: #ffffff
toolbar.iconbar.unfocused: Raised Bevel1 Gradient Vertical
toolbar.iconbar.unfocused.color: #dfdfd8
toolbar.iconbar.unfocused.colorTo: #bdbdb5
toolbar.iconbar.unfocused.textColor: #000000

slit: Flat Solid
slit.color: #c9c9c2
slit.colorTo: #c9c9c2
FBSTYLE
        if [ $? -ne 0 ]; then
            ui_fatal "Could not write GNOME 1-inspired Fluxbox style."
            return 1
        fi
        ui_ok "GNOME 1-inspired Fluxbox style written"
        log_info "Fluxbox style profile: gnome1-strong (${fb_style_cfg})"
    else
        log_info "Fluxbox style profile: default (${fb_style_path})"
    fi

    ui_step "Writing user ~/.xsession"
    backup_file "${xsession_path}"

    typeset variant_arg=""
    if [ -n "${KBD_VARIANT}" ]; then
        variant_arg="-variant ${KBD_VARIANT}"
    fi
    typeset options_arg=""
    if [ -n "${KBD_OPTIONS}" ]; then
        options_arg="-option '${KBD_OPTIONS}'"
    fi

    write_user_file "${xsession_path}" "755" <<XSESS
#!/bin/sh
# ${TARGET_USER} XDM session — managed by ${SCRIPT_NAME}

# Load persistent X resources for this login session
if command -v xrdb >/dev/null 2>&1 && [ -f "\${HOME}/.Xresources" ]; then
    xrdb -merge "\${HOME}/.Xresources" 2>/dev/null || true
fi

# Set keyboard layout
setxkbmap -layout "${KBD_LAYOUT}" -model "${KBD_MODEL}" ${variant_arg} ${options_arg} 2>/dev/null || true

# Disable screen blanking and DPMS during session
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true

# Set DPI for font rendering
xrandr --dpi 96 2>/dev/null || true

# Start D-Bus session if not already running
if [ -z "\${DBUS_SESSION_BUS_ADDRESS}" ]; then
    eval \$(dbus-launch --sh-syntax --exit-with-session) 2>/dev/null || true
fi

# Start PipeWire audio (user session)
pipewire &
sleep 0.5
wireplumber &
pipewire-pulse &

# Start dunst notification daemon
dunst -config "\${HOME}/.config/dunst/dunstrc" &

# Start NetworkManager applet if NM is running
nm-applet 2>/dev/null &

# Set background colour (feh will override if wallpaper exists)
xsetroot -solid '${fb_root_bg}'

# Start Fluxbox
exec fluxbox
XSESS
    ui_ok "~/.xsession written and executable"

    ui_step "Writing ~/.fluxbox/startup"
    write_user_file "${fb_dir}/startup" "755" <<'FBSTART'
#!/bin/sh
if [ -f "${HOME}/.fluxbox/background.png" ]; then
    feh --bg-scale "${HOME}/.fluxbox/background.png" &
elif [ -f "${HOME}/.fluxbox/background.jpg" ]; then
    feh --bg-scale "${HOME}/.fluxbox/background.jpg" &
fi
FBSTART
    ui_ok "~/.fluxbox/startup written"

    ui_step "Writing ~/.fluxbox/init (main settings)"
    write_user_file "${fb_dir}/init" "644" <<FBINIT
session.screen0.workspaces: 8
session.screen0.workspaceNames: Space 1,Space 2,Space 3,Space 4,Space 5,Space 6,Space 7,Space 8
session.screen0.toolbar.visible: true
session.screen0.toolbar.placement: BottomCenter
session.screen0.toolbar.widthPercent: 100
session.screen0.toolbar.alpha: 255
session.screen0.toolbar.autoHide: false
session.screen0.toolbar.maxOver: false
session.screen0.toolbar.onhead: 0
session.screen0.toolbar.layer: Dock
session.screen0.toolbar.tools: prevworkspace, workspacename, nextworkspace, iconbar, systemtray, clock
session.screen0.iconbar.mode: {static groups} (workspace=[current])
session.screen0.iconbar.usePixmap: true
session.screen0.focusModel: ClickFocus
session.screen0.windowPlacement: RowSmartPlacement
session.screen0.colPlacementDirection: TopToBottom
session.screen0.rowPlacementDirection: LeftToRight
session.screen0.edgeSnapThreshold: 10
session.screen0.clickRaises: true
session.screen0.tabs.maxWidth: 200
session.screen0.tabs.usePixmap: true
session.screen0.antialias: true
session.screen0.imageControl: cache
session.styleFile: ${fb_style_path}
session.styleOverlay: ${TARGET_HOME}/.fluxbox/overlay
session.menuFile: ${TARGET_HOME}/.fluxbox/menu
session.keyFile: ${TARGET_HOME}/.fluxbox/keys
session.appsFile: ${TARGET_HOME}/.fluxbox/apps
session.slitlistFile: ${TARGET_HOME}/.fluxbox/slitlist
session.groupFile: ${TARGET_HOME}/.fluxbox/groups
session.cacheLife: 5
session.cacheMax: 200
session.colorsPerChannel: 4
session.doubleClickInterval: 250
session.tabPadding: 0
session.forcePseudoTransparency: false
session.ignoreBorder: false
session.autoRaiseDelay: 250
FBINIT
    ui_ok "~/.fluxbox/init written"

    ui_step "Writing ~/.fluxbox/keys (keybindings)"
    write_user_file "${fb_dir}/keys" "644" <<'FBKEYS'
# Fluxbox key bindings — managed by artix-fluxbox-setup.ksh

# Mouse bindings
OnDesktop Mouse1 :HideMenus
OnDesktop Mouse2 :WorkspaceMenu
OnDesktop Mouse3 :RootMenu
OnDesktop Mouse4 :NextWorkspace
OnDesktop Mouse5 :PrevWorkspace

OnToolbar Mouse4 :NextWorkspace
OnToolbar Mouse5 :PrevWorkspace

OnWindow Mod1 Mouse1 :StartMoving
OnWindow Mod1 Mouse3 :StartResizing NearestCorner
OnWindow Mouse2 :StartMoving

# Workspace switching (keyboard)
Control Mod1 Left   :PrevWorkspace
Control Mod1 Right  :NextWorkspace

Mod4 Left           :PrevWorkspace
Mod4 Right          :NextWorkspace

Mod4 1              :Workspace 1
Mod4 2              :Workspace 2
Mod4 3              :Workspace 3
Mod4 4              :Workspace 4
Mod4 5              :Workspace 5
Mod4 6              :Workspace 6
Mod4 7              :Workspace 7
Mod4 8              :Workspace 8

# Move window to workspace
Mod4 Shift 1        :SendToWorkspace 1
Mod4 Shift 2        :SendToWorkspace 2
Mod4 Shift 3        :SendToWorkspace 3
Mod4 Shift 4        :SendToWorkspace 4
Mod4 Shift 5        :SendToWorkspace 5
Mod4 Shift 6        :SendToWorkspace 6
Mod4 Shift 7        :SendToWorkspace 7
Mod4 Shift 8        :SendToWorkspace 8

# Window management
Mod4 F4         :Close
Mod4 F5         :Kill
Mod4 m          :Minimize
Mod4 Shift m    :MinimizeWindow
Mod4 x          :Maximize
Mod4 f          :Fullscreen
Mod4 Up         :MaximizeVertical
Mod4 Down       :Restore
Mod4 Tab        :NextWindow
Mod4 Shift Tab  :PrevWindow
Mod4 d          :ShowDesktop
Mod4 r          :RaiseFocus

# Application launchers
Mod4 t          :Exec xterm
Mod4 e          :Exec pcmanfm
Mod4 b          :Exec firefox
Mod4 Return     :Exec xterm

# Screenshot
Print           :Exec scrot '%Y-%m-%d_%H%M%S.png' -e 'mv $f ~/Pictures/'
Mod1 Print      :Exec scrot -s '%Y-%m-%d_%H%M%S_select.png' -e 'mv $f ~/Pictures/'

# Volume control (ALSA/PipeWire via amixer)
XF86AudioRaiseVolume    :Exec amixer set Master 5%+
XF86AudioLowerVolume    :Exec amixer set Master 5%-
XF86AudioMute           :Exec amixer set Master toggle

# Laptop backlight
XF86MonBrightnessUp     :Exec xbacklight -inc 10
XF86MonBrightnessDown   :Exec xbacklight -dec 10

# Lock screen (basic xlock if available, else blank)
Mod4 l          :Exec xset s activate

# Reload Fluxbox config
Mod4 Shift r    :Reconfigure

# Open Fluxbox menu
Mod4 space      :RootMenu
FBKEYS
    ui_ok "~/.fluxbox/keys written"

    ui_step "Writing ~/.fluxbox/menu"
    write_user_file "${fb_dir}/menu" "644" <<FBMENU
[begin] (Artix Fluxbox)
    [submenu] (Terminal)
        [exec] (XTerm)     {xterm}
    [end]
    [submenu] (Internet)
        [exec] (Firefox)           {firefox}
        [exec] (Network Manager)   {nm-connection-editor}
    [end]
    [submenu] (Files)
        [exec] (PCManFM)           {pcmanfm}
    [end]
    [submenu] (Multimedia)
        [exec] (MPV Player)        {mpv}
        [exec] (Image Viewer)      {sxiv}
        [exec] (PDF Reader)        {zathura}
        [exec] (Volume Control)    {pavucontrol}
        [exec] (Screenshot)        {scrot '%Y%m%d_%H%M%S.png' -e 'mv \$f ~/Pictures/'}
    [end]
    [submenu] (Office)
        [exec] (LibreOffice Writer)      {libreoffice --writer}
        [exec] (LibreOffice Calc)        {libreoffice --calc}
        [exec] (LibreOffice Impress)     {libreoffice --impress}
        [exec] (LibreOffice Draw)        {libreoffice --draw}
    [end]
    [submenu] (Development)
        [exec] (Vim)               {xterm -e vim}
        [exec] (Nano)              {xterm -e nano}
        [exec] (Git Log)           {xterm -e "git log --oneline -20; read _"}
    [end]
    [submenu] (System)
        [exec] (HTop)              {xterm -e htop}
        [exec] (LM Sensors)        {xterm -e "sensors; read _"}
        [exec] (Disk Usage)        {xterm -e "df -h; read _"}
        [exec] (Calculator)        {galculator}
        [exec] (Fluxbox Settings)  {fluxbox-remote reconfigure}
    [end]
    [submenu] (Workspaces) {}
        [workspaces] (Workspaces)
    [end]
    [config] (Configure Fluxbox)
    [reconfig] (Reload Config)
    [restart] (Restart Fluxbox)
    [separator]
    [exec] (Lock Screen) {xset s activate}
    [exit] (Log Out)
[end]
FBMENU
    ui_ok "~/.fluxbox/menu written"

    ui_step "Writing ~/.fluxbox/apps"
    write_user_file "${fb_dir}/apps" "644" <<'FBAPPS'
# Fluxbox application placement rules — managed by artix-fluxbox-setup.ksh

[app] (xterm)
  [Dimensions]    {100 30}
  [Position]      (WINCENTER) {0 0}
  [Layer]         {6}
[end]

[app] (firefox)
  [Workspace]     {1}
  [Dimensions]    {1200 800}
  [Position]      (WINCENTER) {0 0}
[end]

[app] (libreoffice)
  [Workspace]     {2}
  [Dimensions]    {1200 850}
  [Position]      (WINCENTER) {0 0}
[end]

[app] (pcmanfm)
  [Dimensions]    {900 600}
  [Position]      (WINCENTER) {0 0}
[end]

[app] (pavucontrol)
  [Dimensions]    {700 450}
  [Position]      (WINCENTER) {0 0}
  [Layer]         {4}
[end]
FBAPPS
    ui_ok "~/.fluxbox/apps written"

    ui_step "Writing ~/.fluxbox/overlay (style overrides)"
    write_user_file "${fb_dir}/overlay" "644" <<'FBOVER'
! Fluxbox style overlay — managed by artix-fluxbox-setup.ksh
! Override selected style properties for readability.

toolbar.height: 22
toolbar.alpha: 230

menu.titleHeight: 20
menu.itemHeight: 18
menu.alpha: 240

window.title.height: 20
FBOVER
    ui_ok "~/.fluxbox/overlay written"

    ensure_dir "${TARGET_HOME}/Pictures" "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "755"

    ui_step "Setting correct ownership on ~/.fluxbox"
    chown -R "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "${fb_dir}"
    ui_ok "Ownership corrected"

    chk_mark "07_fluxbox"
    ui_ok "Fluxbox configuration complete."
    return 0
}

stage_audio() {
    ui_stage "08" "Audio Configuration"
    log_stage "AUDIO"

    if [ "${HW_HAS_AUDIO}" -eq 0 ]; then
        ui_warn "No audio hardware detected. Skipping audio configuration."
        log_warn "Audio setup skipped: no hardware"
        chk_mark "08_audio"
        return 0
    fi

    ui_step "Setting ALSA mixer defaults"
    if command -v amixer >/dev/null 2>&1; then
        run_cmd_quiet "ALSA unmute Master" amixer sset Master unmute 2>/dev/null || true
        run_cmd_quiet "ALSA set Master 80%" amixer sset Master 80% 2>/dev/null || true
        run_cmd_quiet "ALSA unmute PCM" amixer sset PCM unmute 2>/dev/null || true
        run_cmd_quiet "ALSA set PCM 80%" amixer sset PCM 80% 2>/dev/null || true
        ui_ok "ALSA mixer: Master and PCM set to 80%, unmuted"
        log_info "ALSA mixer defaults applied"

        if command -v alsactl >/dev/null 2>&1; then
            run_cmd_quiet "alsactl store" alsactl store 2>/dev/null || true
            ui_ok "ALSA state saved"
        fi
    else
        ui_warn "amixer not found; ALSA mixer not configured"
    fi

    ui_step "Preparing PipeWire user configuration"
    typeset pw_conf_dir="${TARGET_HOME}/.config/pipewire"
    ensure_dir "${pw_conf_dir}" "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "755"

    write_user_file "${pw_conf_dir}/pipewire.conf.d/10-artix.conf" "644" <<'PWCONF'
# PipeWire default configuration — managed by artix-fluxbox-setup.ksh
context.properties = {
    default.clock.rate          = 48000
    default.clock.quantum       = 1024
    default.clock.min-quantum   = 32
    default.clock.max-quantum   = 8192
}
PWCONF
    chown -R "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "${TARGET_HOME}/.config/pipewire"
    ui_ok "PipeWire user config prepared"

    typeset wp_conf_dir="${TARGET_HOME}/.config/wireplumber"
    ensure_dir "${wp_conf_dir}" "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "755"
    chown -R "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "${wp_conf_dir}"
    ui_ok "WirePlumber user config directory ready"

    ui_step "Validating audio readiness"
    if [ -d /proc/asound ] && ls /proc/asound/card* >/dev/null 2>&1; then
        typeset card_list
        card_list=$(ls /proc/asound/ | grep '^card' | tr '\n' ' ')
        ui_ok "ALSA cards visible: ${card_list}"
        log_info "ALSA cards: ${card_list}"
        PKG_AUDIO_AVAILABLE=1
    else
        ui_warn "No ALSA cards visible in /proc/asound. Audio may require reboot."
        log_warn "No ALSA cards visible"
    fi

    chk_mark "08_audio"
    ui_ok "Audio configuration complete."
    return 0
}

stage_keyboard() {
    ui_stage "09" "Keyboard Layout Persistence"
    log_stage "KEYBOARD"

    ui_step "Verifying /etc/conf.d/keymaps"
    if grep -q "keymap=\"${KBD_LAYOUT}\"" /etc/conf.d/keymaps 2>/dev/null; then
        ui_ok "Console keymap '${KBD_LAYOUT}' confirmed in /etc/conf.d/keymaps"
    else
        ui_warn "Console keymap not found in /etc/conf.d/keymaps — rewriting"
        write_file "/etc/conf.d/keymaps" "root:root" "644" <<KEYMAPS
# Console keymap — managed by ${SCRIPT_NAME}
keymap="${KBD_LAYOUT}"
KEYMAPS
        ui_ok "Console keymap corrected"
    fi

    ui_step "Verifying /etc/X11/xorg.conf.d/00-keyboard.conf"
    if [ -f /etc/X11/xorg.conf.d/00-keyboard.conf ]; then
        if grep -q "\"${KBD_LAYOUT}\"" /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null; then
            ui_ok "X11 keyboard config confirmed"
        else
            ui_warn "X11 keyboard config mismatch — re-running graphics stage"
            stage_graphics
        fi
    else
        ui_warn "X11 keyboard config missing — re-running graphics stage"
        stage_graphics
    fi

    ui_step "Applying keyboard to current TTY"
    if command -v loadkeys >/dev/null 2>&1; then
        run_cmd_quiet "loadkeys ${KBD_LAYOUT}" loadkeys "${KBD_LAYOUT}" 2>/dev/null || true
        ui_ok "loadkeys applied: ${KBD_LAYOUT} (current TTY)"
    else
        ui_info "loadkeys not available; layout effective after next boot/login"
    fi

    log_info "Keyboard persistence: layout=${KBD_LAYOUT} variant=${KBD_VARIANT:-none}"
    chk_mark "09_keyboard"
    ui_ok "Keyboard persistence configured."
    return 0
}

stage_desktop_config() {
    ui_stage "10" "Desktop Software Configuration"
    log_stage "DESKTOP_CONFIG"

    typeset user_conf_dir="${TARGET_HOME}/.config"
    ensure_dir "${user_conf_dir}" "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "755"

    ui_step "Configuring dunst notifications"
    typeset dunst_dir="${user_conf_dir}/dunst"
    ensure_dir "${dunst_dir}" "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "755"

    write_user_file "${dunst_dir}/dunstrc" "644" <<'DUNSTRC'
# dunst configuration — managed by artix-fluxbox-setup.ksh
[global]
    monitor              = 0
    follow               = none
    width                = 300
    height               = 80
    origin               = top-right
    offset               = 12x48
    scale                = 0
    notification_limit   = 5
    progress_bar         = true
    indicate_hidden      = yes
    transparency         = 10
    separator_height     = 2
    padding              = 8
    horizontal_padding   = 10
    frame_width          = 1
    frame_color          = "#4a4e69"
    gap_size             = 3
    idle_threshold       = 120
    font                 = DejaVu Sans 10
    line_height          = 0
    markup               = full
    format               = "<b>%s</b>\n%b"
    alignment            = left
    show_age_threshold   = 60
    word_wrap            = yes
    ignore_newline       = no
    stack_duplicates     = true
    hide_duplicate_count = false
    show_indicators      = yes
    icon_theme           = hicolor
    enable_recursive_icon_lookup = true
    icon_position        = left
    min_icon_size        = 0
    max_icon_size        = 32
    sticky_history       = yes
    history_length       = 20
    browser              = /usr/bin/firefox
    always_run_script    = true
    title                = Dunst
    class                = Dunst
    corner_radius        = 4
    timeout              = 5
    sort                 = yes
    mouse_left_click     = close_current
    mouse_middle_click   = do_action, close_current
    mouse_right_click    = close_all

[urgency_low]
    background = "#1a1a2e"
    foreground = "#adb5bd"
    timeout    = 5

[urgency_normal]
    background = "#1a1a2e"
    foreground = "#c8ccd4"
    timeout    = 7

[urgency_critical]
    background = "#7e1f1f"
    foreground = "#ffffff"
    frame_color = "#ff4040"
    timeout    = 0
DUNSTRC
    ui_ok "dunst configuration written"

    ui_step "Configuring XTerm (Xresources)"
    typeset xres_file="${TARGET_HOME}/.Xresources"
    backup_file "${xres_file}"

    write_user_file "${xres_file}" "644" <<'XRESOURCES'
! ~/.Xresources — managed by artix-fluxbox-setup.ksh

! XTerm general settings
XTerm*termName:           xterm-256color
XTerm*utf8:               1
XTerm*locale:             true
XTerm*cursorBlink:        true
XTerm*cursorColor:        #7eb6ff
XTerm*scrollBar:          false
XTerm*rightScrollBar:     false
XTerm*saveLines:          4096
XTerm*multiScroll:        true
XTerm*jumpScroll:         true
XTerm*fastScroll:         true
XTerm*bellIsUrgent:       true
XTerm*visualBell:         false

! XTerm font
XTerm*faceName:           DejaVu Sans Mono
XTerm*faceSize:           11
XTerm*renderFont:         true
XTerm*antialias:          true

! XTerm colours (dark theme)
XTerm*background:         #1a1a2e
XTerm*foreground:         #c8ccd4
XTerm*cursorColor:        #7eb6ff
XTerm*color0:             #1a1a2e
XTerm*color1:             #e06c75
XTerm*color2:             #98c379
XTerm*color3:             #e5c07b
XTerm*color4:             #61afef
XTerm*color5:             #c678dd
XTerm*color6:             #56b6c2
XTerm*color7:             #abb2bf
XTerm*color8:             #3e4452
XTerm*color9:             #e06c75
XTerm*color10:            #98c379
XTerm*color11:            #e5c07b
XTerm*color12:            #61afef
XTerm*color13:            #c678dd
XTerm*color14:            #56b6c2
XTerm*color15:            #ffffff

! XTerm window geometry
XTerm*geometry:           100x30

! Key bindings in XTerm
XTerm.VT100.Translations: #override \
    Ctrl Shift <Key>C: copy-selection(CLIPBOARD) \n\
    Ctrl Shift <Key>V: insert-selection(CLIPBOARD)

! Scrollback via Shift+PageUp/Down
XTerm*VT100.Translations: #override \
    Shift<Key>Prior: scroll-back(1, pages) \n\
    Shift<Key>Next: scroll-forw(1, pages)
XRESOURCES
    ui_ok "~/.Xresources written"

    ui_step "Configuring ~/.profile (session environment)"
    typeset profile_file="${TARGET_HOME}/.profile"
    backup_file "${profile_file}"

    typeset profile_marker="# artix-fluxbox-setup managed block"
    if ! grep -qF "${profile_marker}" "${profile_file}" 2>/dev/null; then
        cat >> "${profile_file}" <<PROFILE

${profile_marker}
export PATH="\${HOME}/.local/bin:\${PATH}"
export EDITOR=vim
export VISUAL=vim
export PAGER=less
export LESS="-R -M -i"
export MOZ_ENABLE_WAYLAND=0
export LANG="${LANG:-en_US.UTF-8}"
export GTK_THEME=Adwaita:dark
PROFILE
        chown "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "${profile_file}"
        ui_ok "~/.profile updated with session environment"
    else
        ui_skip "~/.profile already contains managed block"
    fi

    ui_step "Configuring MPV"
    typeset mpv_dir="${user_conf_dir}/mpv"
    ensure_dir "${mpv_dir}" "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "755"
    write_user_file "${mpv_dir}/mpv.conf" "644" <<'MPVCONF'
# MPV configuration — managed by artix-fluxbox-setup.ksh
hwdec=auto-safe
vo=gpu
gpu-api=auto
ao=pipewire
audio-channels=stereo
volume-max=150
osc=yes
osd-bar=yes
save-position-on-quit=yes
cache=yes
MPVCONF
    ui_ok "MPV configuration written"

    ui_step "Ensuring XDG user directories"
    typeset xdg_conf="${user_conf_dir}/user-dirs.dirs"
    if [ ! -f "${xdg_conf}" ]; then
        if command -v xdg-user-dirs-update >/dev/null 2>&1; then
            run_cmd_quiet "xdg-user-dirs-update as ${TARGET_USER}" \
                su -c "xdg-user-dirs-update" "${TARGET_USER}" 2>/dev/null || true
        else
            write_user_file "${xdg_conf}" "644" <<XDGDIRS
XDG_DESKTOP_DIR="\$HOME/Desktop"
XDG_DOWNLOAD_DIR="\$HOME/Downloads"
XDG_TEMPLATES_DIR="\$HOME/Templates"
XDG_PUBLICSHARE_DIR="\$HOME/Public"
XDG_DOCUMENTS_DIR="\$HOME/Documents"
XDG_MUSIC_DIR="\$HOME/Music"
XDG_PICTURES_DIR="\$HOME/Pictures"
XDG_VIDEOS_DIR="\$HOME/Videos"
XDGDIRS
        fi
    fi

    for xdg_sub in Desktop Downloads Documents Music Pictures Videos; do
        ensure_dir "${TARGET_HOME}/${xdg_sub}" \
            "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "755"
    done
    ui_ok "XDG user directories present"

    chown -R "${TARGET_USER}:$(id -gn "${TARGET_USER}")" \
        "${user_conf_dir}" 2>/dev/null || true

    chk_mark "10_desktop_config"
    ui_ok "Desktop software configuration complete."
    return 0
}

stage_user_env() {
    ui_stage "11" "User Environment Finalisation"
    log_stage "USER_ENV"

    ensure_dir "${TARGET_HOME}/.local/bin" "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "755"
    ui_ok "~/.local/bin directory present"

    ensure_dir "${TARGET_HOME}/.ssh" "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "700"
    ui_ok "~/.ssh directory present (700)"

    typeset xinitrc="${TARGET_HOME}/.xinitrc"
    if [ ! -f "${xinitrc}" ]; then
        write_user_file "${xinitrc}" "755" <<'XINITRC'
#!/bin/sh
# ~/.xinitrc — fallback for startx; XDM uses ~/.xsession directly.
[ -f "${HOME}/.Xresources" ] && xrdb -merge "${HOME}/.Xresources"
exec "${HOME}/.xsession"
XINITRC
        ui_ok "~/.xinitrc written (fallback for startx)"
    else
        ui_skip "~/.xinitrc already exists, not overwriting"
    fi

    if [ -n "${DISPLAY:-}" ]; then
        typeset xauthority_file="${XAUTHORITY:-${TARGET_HOME}/.Xauthority}"
        run_cmd_quiet "xrdb merge .Xresources" \
            su -c "DISPLAY='${DISPLAY}' XAUTHORITY='${xauthority_file}' HOME='${TARGET_HOME}' xrdb -merge '${TARGET_HOME}/.Xresources'" "${TARGET_USER}" 2>/dev/null || true
        if [ "${RC}" -eq 0 ]; then
            ui_info "Xresources merged into running X session"
        else
            ui_warn "Could not merge Xresources into the running X session now; persistence on next login remains configured."
            log_warn "Runtime xrdb merge failed for DISPLAY=${DISPLAY} XAUTHORITY=${xauthority_file}"
        fi
    fi

    ui_step "Initialising hardware sensors"
    if command -v sensors-detect >/dev/null 2>&1; then
        run_cmd_quiet "sensors-detect auto" sensors-detect --auto 2>/dev/null || true
        ui_ok "sensors-detect completed (non-interactive)"
    else
        ui_info "sensors-detect not available; skip"
    fi

    ui_step "Checking locale configuration"
    if ! locale 2>/dev/null | grep -q 'LANG='; then
        ui_info "LANG not set system-wide; will rely on user profile"
        log_info "System locale not configured — user profile sets LANG"
    else
        ui_ok "System locale: $(locale 2>/dev/null | grep '^LANG=' | head -1)"
    fi

    ui_step "Final ownership verification"
    chown "${TARGET_USER}:$(id -gn "${TARGET_USER}")" "${TARGET_HOME}"
    chown -R "${TARGET_USER}:$(id -gn "${TARGET_USER}")" \
        "${TARGET_HOME}/.fluxbox" \
        "${TARGET_HOME}/.config" \
        "${TARGET_HOME}/.local" \
        "${TARGET_HOME}/.ssh" \
        2>/dev/null || true
    ui_ok "Ownership verified for ${TARGET_HOME}"

    chk_mark "11_user_env"
    ui_ok "User environment finalised."
    return 0
}

stage_validate() {
    ui_stage "12" "Post-Installation Validation"
    log_stage "VALIDATE"

    typeset val_ok=1

    ui_step "Validating critical binaries"
    typeset binary
    for binary in X xdm fluxbox xterm xrdb feh dunst nm-applet amixer pipewire; do
        if command -v "${binary}" >/dev/null 2>&1; then
            log_info "Binary OK: ${binary} ($(command -v "${binary}"))"
        else
            ui_warn "Binary not found: ${binary}"
            log_warn "Binary missing: ${binary}"
            case "${binary}" in
                X|xdm|fluxbox|xterm|xrdb|amixer)
                    ui_fail "CRITICAL binary missing: ${binary}"
                    val_ok=0
                    ;;
            esac
        fi
    done
    [ "${val_ok}" -eq 1 ] && ui_ok "Critical binaries present"

    ui_step "Validating configuration files"
    typeset conf
    for conf in \
        /etc/conf.d/xdm \
        /etc/X11/xdm/xdm-config \
        /etc/X11/xdm/Xsession \
        /etc/X11/xdm/Xservers \
        /etc/X11/xorg.conf.d/00-keyboard.conf \
        "${TARGET_HOME}/.xsession" \
        "${TARGET_HOME}/.fluxbox/init" \
        "${TARGET_HOME}/.fluxbox/keys" \
        "${TARGET_HOME}/.fluxbox/menu" \
        "${TARGET_HOME}/.Xresources"
    do
        if [ -f "${conf}" ]; then
            log_info "Config OK: ${conf}"
        else
            ui_warn "Config missing: ${conf}"
            log_warn "Config file missing: ${conf}"
            val_ok=0
        fi
    done
    [ "${val_ok}" -eq 1 ] && ui_ok "All configuration files present"

    ui_step "Validating ~/.xsession is executable"
    if [ -x "${TARGET_HOME}/.xsession" ]; then
        ui_ok "~/.xsession is executable"
    else
        ui_fail "~/.xsession is not executable"
        log_error "~/.xsession missing execute bit"
        chmod +x "${TARGET_HOME}/.xsession"
        ui_ok "~/.xsession execute bit corrected"
    fi

    ui_step "Validating persistent Xresources activation path"
    if grep -Eq 'xrdb -merge "(\$\{HOME\}|\$HOME|${TARGET_HOME})/\.Xresources"' "${TARGET_HOME}/.xsession" 2>/dev/null; then
        ui_ok "~/.xsession loads ~/.Xresources via xrdb"
    else
        ui_fail "~/.xsession does not load ~/.Xresources via xrdb"
        log_error "~/.xsession missing xrdb merge for ~/.Xresources"
        val_ok=0
    fi

    ui_step "Validating managed XTerm resource entries"
    if grep -q '^XTerm\*background:[[:space:]]*#1a1a2e$' "${TARGET_HOME}/.Xresources" 2>/dev/null && \
       grep -q '^XTerm\*foreground:[[:space:]]*#c8ccd4$' "${TARGET_HOME}/.Xresources" 2>/dev/null; then
        ui_ok "~/.Xresources contains managed XTerm colours"
    else
        ui_fail "~/.Xresources does not contain the expected managed XTerm colours"
        log_error "~/.Xresources missing expected XTerm colour entries"
        val_ok=0
    fi

    if [ -n "${DISPLAY:-}" ]; then
        ui_step "Validating loaded X resource database for the active session"
        typeset runtime_xauthority="${XAUTHORITY:-${TARGET_HOME}/.Xauthority}"
        typeset xrdb_query_out="${TMP_DIR}/xrdb_query.$$"
        su -c "DISPLAY='${DISPLAY}' XAUTHORITY='${runtime_xauthority}' HOME='${TARGET_HOME}' xrdb -query" "${TARGET_USER}" > "${xrdb_query_out}" 2>/dev/null
        if [ $? -eq 0 ] && grep -q '^XTerm\*background:[[:space:]]*#1a1a2e$' "${xrdb_query_out}" 2>/dev/null; then
            ui_ok "Active X session has the managed XTerm background loaded"
            log_info "xrdb runtime query confirmed managed XTerm resources"
        else
            ui_warn "Could not confirm managed XTerm resources in the active X session"
            log_warn "xrdb runtime query could not confirm managed XTerm resources"
        fi
        rm -f "${xrdb_query_out}" 2>/dev/null || true
    else
        ui_info "No active DISPLAY available; runtime xrdb query skipped"
        log_info "Skipped runtime xrdb query because DISPLAY is not set"
    fi

    if [ -x /etc/X11/xdm/Xsession ]; then
        ui_ok "/etc/X11/xdm/Xsession is executable"
    else
        chmod +x /etc/X11/xdm/Xsession
        ui_ok "/etc/X11/xdm/Xsession execute bit corrected"
    fi

    ui_step "Validating OpenRC display manager selector"
    if [ -f /etc/conf.d/xdm ] && grep -q '^DISPLAYMANAGER="xdm"$' /etc/conf.d/xdm 2>/dev/null; then
        ui_ok "/etc/conf.d/xdm selects xdm"
    else
        ui_fail "/etc/conf.d/xdm is missing or does not select xdm"
        log_error "/etc/conf.d/xdm missing or DISPLAYMANAGER is not xdm"
        val_ok=0
    fi

    ui_step "Validating required XDM service registration"
    typeset svc
    if ! svc_exists xdm; then
        ui_fail "Required /etc/init.d/xdm is missing"
        log_error "/etc/init.d/xdm missing during validation"
        val_ok=0
    elif svc_enabled xdm default 2>/dev/null || svc_enabled xdm boot 2>/dev/null; then
        ui_ok "Required XDM service enabled: xdm"
    else
        ui_fail "Required XDM service is not enabled: xdm"
        log_error "Required XDM service is not enabled: xdm"
        val_ok=0
    fi

    ui_step "Validating optional OpenRC services"
    for svc in NetworkManager; do
        if svc_enabled "${svc}" default 2>/dev/null || svc_enabled "${svc}" boot 2>/dev/null; then
            ui_ok "Service enabled: ${svc}"
        else
            ui_warn "Optional service not enabled: ${svc}"
        fi
    done

    ui_step "Starting and verifying XDM service"
    if xdm_activate_required; then
        ui_ok "XDM startup verification passed"
    else
        log_error "XDM activation verification failed"
        val_ok=0
    fi

    ui_step "Validating XKB layout file"
    if [ -f "/usr/share/X11/xkb/symbols/${KBD_LAYOUT}" ]; then
        ui_ok "XKB layout confirmed: ${KBD_LAYOUT}"
    else
        ui_fail "XKB layout file still missing: /usr/share/X11/xkb/symbols/${KBD_LAYOUT}"
        val_ok=0
    fi

    if [ "${HW_IS_INTEL_GPU}" -eq 1 ]; then
        ui_step "Validating Intel graphics"
        if pkg_installed mesa; then
            ui_ok "Mesa installed"
        else
            ui_warn "Mesa not installed — Intel acceleration unavailable"
        fi
        if [ "${HW_GPU_DRIVER_RECOMMENDED}" = "modesetting" ]; then
            ui_info "Using modesetting DDX (built into xorg-server)"
        elif pkg_installed xf86-video-intel; then
            ui_ok "xf86-video-intel DDX installed"
        fi
    fi

    ui_step "Validating audio"
    if command -v pipewire >/dev/null 2>&1; then
        ui_ok "PipeWire binary present"
    else
        ui_warn "PipeWire not found — audio startup may fail"
    fi
    if command -v wireplumber >/dev/null 2>&1; then
        ui_ok "WirePlumber binary present"
    else
        ui_warn "WirePlumber not found"
    fi

    if [ "${val_ok}" -eq 1 ]; then
        log_info "Validation: PASSED"
        ui_ok "Validation passed"
        chk_mark "12_validate"
        return 0
    fi

    log_error "Validation failed — critical requirements not satisfied"
    ui_fail "Validation failed — review log: ${LOGFILE}"
    return 1
}

stage_final_report() {
    ui_stage "13" "Final Report"
    log_stage "FINAL_REPORT"

    typeset stage_count=0 done_count=0 f tag ts xdm_state
    xdm_state="not detected"
    if svc_exists xdm && rc-service xdm status >/dev/null 2>&1; then
        xdm_state="active (xdm)"
    elif svc_exists xdm; then
        xdm_state="enabled or configured, not active (xdm)"
    fi
    for f in "${STATE_DIR}"/stage_*.done; do
        [ -f "${f}" ] || continue
        stage_count=$(( stage_count + 1 ))
        done_count=$(( done_count + 1 ))
        tag=$(basename "${f}" ".done")
        ts=$(cat "${f}" 2>/dev/null)
        log_info "Stage complete: ${tag} at ${ts}"
    done

    print ""
    print -- "${C_BOLD}  ┌─ Setup Summary ────────────────────────────────────────────┐${C_RST}"
    print -- "  │  Target user:       ${TARGET_USER}"
    print -- "  │  Home:              ${TARGET_HOME}"
    print -- "  │  Keyboard:          ${KBD_LAYOUT} / ${KBD_VARIANT:-none} / ${KBD_MODEL}"
    print -- "  │  CPU:               ${HW_CPU_MODEL}"
    print -- "  │  GPU:               $([ "${HW_IS_INTEL_GPU}" -eq 1 ] && print "Intel (${HW_GPU_DRIVER_RECOMMENDED})" || print "Non-Intel / degraded")"
    print -- "  │  Audio:             $([ "${HW_HAS_AUDIO}" -eq 1 ] && print "ALSA + PipeWire" || print "Not detected")"
    print -- "  │  Profile:           $([ "${HW_IS_LAPTOP}" -eq 1 ] && print "Laptop" || print "Desktop")"
    print -- "  │  XDM:               ${xdm_state}"
    print -- "  │  Stages complete:   ${done_count}"
    print -- "  │  Log file:          ${LOGFILE}"
    print -- "  │  State dir:         ${STATE_DIR}"
    print -- "  └────────────────────────────────────────────────────────────┘"
    print ""
    print -- "  ${C_BOLD}Next steps:${C_RST}"
    print "    1. XDM has been configured and verified as a required component"
    print "    2. If the login screen is not visible yet, switch to tty7 / vt7 or reboot once"
    print "    3. Log in as '${TARGET_USER}' — Fluxbox will start"
    print "    4. Right-click the desktop for the application menu"
    print "    5. Ctrl+Alt+Left/Right and Super+Left/Right switch workspaces"
    print "    6. Super+1..8 jumps to a workspace; Super+Shift+1..8 sends a window there"
    print "    7. Super+T opens a terminal (XTerm)"
    print ""
    print "    If audio is silent: run  ${C_BOLD}pavucontrol${C_RST}  from the menu"
    print "    Log file for troubleshooting: ${LOGFILE}"
    print ""

    log_info "Setup complete. Total stages: ${done_count}"
    chk_mark "13_final_report"
}

run_stage() {
    typeset tag="$1" display="$2" fn="$3"

    if chk_done "${tag}"; then
        typeset done_ts
        done_ts=$(cat "$(chk_file "${tag}")" 2>/dev/null)
        ui_skip "Stage already complete: ${display} (${done_ts})"
        log_info "Skipping completed stage: ${tag}"
        return 0
    fi

    log_stage "BEGIN ${tag}: ${display}"
    "${fn}"
    typeset fn_rc=$?

    if [ "${fn_rc}" -ne 0 ]; then
        LAST_FAILED_STAGE="${tag}"
        ui_final_fail
        ui_fail "Stage failed: ${display}"
        log_error "Stage ${tag} returned non-zero: ${fn_rc}"
        print ""
        print -- "  Resume command:"
        print -- "  ${SCRIPT_NAME} -u '${TARGET_USER}' -k '${KBD_LAYOUT}'${KBD_VARIANT:+ -V '${KBD_VARIANT}'}"
        print ""
        return "${fn_rc}"
    fi

    log_stage "END ${tag}: ${display}"
    return 0
}

run_all_stages() {
    run_stage "01_preflight"      "Preflight Validation"           stage_preflight || return 1
    run_stage "02_hardware"       "Hardware Discovery"             stage_hardware || return 1
    run_stage "03_packages"       "Package Installation"           stage_packages || return 1
    run_stage "04_services"       "OpenRC Service Configuration"   stage_services || return 1
    run_stage "05_graphics"       "Graphics and X11 Setup"         stage_graphics || return 1
    run_stage "06_xdm"            "XDM Display Manager Setup"      stage_xdm || return 1
    run_stage "07_fluxbox"        "Fluxbox Desktop Setup"          stage_fluxbox || return 1
    run_stage "08_audio"          "Audio Configuration"            stage_audio || return 1
    run_stage "09_keyboard"       "Keyboard Persistence"           stage_keyboard || return 1
    run_stage "10_desktop_config" "Desktop Software Config"        stage_desktop_config || return 1
    run_stage "11_user_env"       "User Environment Finalisation"  stage_user_env || return 1
    run_stage "12_validate"       "Post-Install Validation"        stage_validate || return 1
    run_stage "13_final_report"   "Final Report"                   stage_final_report || return 1
    return 0
}

main() {
    parse_args "$@"

    ui_banner
    print -- "  ${C_BOLD}${SCRIPT_NAME}${C_RST} ${SCRIPT_VERSION} — PID ${SCRIPT_PID}"
    print -- "  $(date '+%Y-%m-%d %H:%M:%S %Z')"

    if [ "${FORCE_RERUN}" -eq 1 ]; then
        ui_warn "Force rerun mode: all stage checkpoints will be ignored."
    fi
    if [ "${FORCE_REINSTALL_PACKAGES}" -eq 1 ]; then
        ui_warn "Force reinstall mode: package stage will reinstall queued packages."
    fi
    if [ "${AUTO_RETRY_ON_ERROR}" -eq 1 ]; then
        ui_warn "Auto retry mode: any stage failure restarts from stage 1 (max ${MAX_AUTO_RETRIES} attempts)."
    fi
    if [ "${GNOME1_THEME}" -eq 1 ]; then
        ui_warn "GNOME 1 style mode: Fluxbox will use a classic GNOME 1-inspired visual profile."
    fi

    if [ -d "${STATE_DIR}" ]; then
        chk_show_resume_status
    fi

    typeset attempt run_rc
    attempt=1
    while [ "${attempt}" -le "${MAX_AUTO_RETRIES}" ]; do
        CURRENT_ATTEMPT="${attempt}"
        LAST_FAILED_STAGE=""

        if [ "${attempt}" -gt 1 ]; then
            print ""
            ui_warn "Retry attempt ${attempt}/${MAX_AUTO_RETRIES}: restarting from stage 1."
            clear_stage_checkpoints
            FORCE_RERUN=1
            mkdir -p "${TMP_DIR}"
        fi

        run_all_stages
        run_rc=$?
        if [ "${run_rc}" -eq 0 ]; then
            rm -rf "${TMP_DIR}" 2>/dev/null || true
            ui_final_ok
            return 0
        fi

        if [ "${AUTO_RETRY_ON_ERROR}" -ne 1 ] || [ "${attempt}" -ge "${MAX_AUTO_RETRIES}" ]; then
            rm -rf "${TMP_DIR}" 2>/dev/null || true
            return 1
        fi

        log_warn "Attempt ${attempt} failed at stage ${LAST_FAILED_STAGE}; restarting from beginning"
        attempt=$(( attempt + 1 ))
    done

    rm -rf "${TMP_DIR}" 2>/dev/null || true
    return 1
}

trap '
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        ui_fail "Unexpected exit (code ${rc}). Re-run to resume."
        log_error "Unexpected exit code: ${rc}"
    fi
    rm -rf "${TMP_DIR}" 2>/dev/null || true
' EXIT

main "$@"
