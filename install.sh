#!/bin/bash
# Dotfiles installer: symlinks git-tracked config files into $HOME.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: install.sh [--dry-run] [--platform macos|linux] [--install-apps|--skip-apps] [--help]

Symlinks git-tracked dotfiles into the home directory.
Only files tracked by git are used as installation sources.

Options:
  --dry-run          Print planned actions without making changes
  --platform VALUE   Override automatic platform detection
  --install-apps     Install missing applications without prompting
  --skip-apps        Do not install missing applications
  --help             Show this help text

Environment:
  DOTFILES_HOME      Target home directory (default: $HOME)
EOF
}

DRY_RUN=false
PLATFORM=""
INSTALL_APPS="ask"
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --platform)
            [ $# -ge 2 ] || { printf 'Missing value for --platform\n' >&2; exit 1; }
            PLATFORM="$2"
            shift 2 ;;
        --install-apps) INSTALL_APPS="yes"; shift ;;
        --skip-apps) INSTALL_APPS="no"; shift ;;
        --help|-h) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage; exit 1 ;;
    esac
done

# Source repository: directory containing this script (absolute).
SRC=$(cd "$(dirname "$0")" && pwd)

# Target home directory.
DOTFILES_HOME=${DOTFILES_HOME:-$HOME}
if [ -z "$PLATFORM" ]; then
    case "$(uname -s)" in
        Darwin) PLATFORM="macos" ;;
        Linux) PLATFORM="linux" ;;
        *) printf 'Unsupported platform: %s\n' "$(uname -s)" >&2; exit 1 ;;
    esac
fi
case "$PLATFORM" in
    macos|linux) ;;
    *) printf 'Unsupported platform: %s\n' "$PLATFORM" >&2; exit 1 ;;
esac

# Verify source is a git repository.
if ! git -C "$SRC" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Error: %s is not a git repository\n' "$SRC" >&2
    exit 1
fi

BACKUP_BASE="$DOTFILES_HOME/.dotfiles-backup"
BACKUP_DIR=""

# Counters.
linked=0
skipped=0
backed_up=0
excluded=0
platform_skipped=0

# Map a repo-relative path to an absolute target path.
# Echo the target and return 0 if mappable; return 1 otherwise.
map_target() {
    local file="$1"
    case "$file" in
        .config/*)
            printf '%s/%s\n' "$DOTFILES_HOME" "$file" ;;
        .local/bin/*)
            printf '%s/%s\n' "$DOTFILES_HOME" "$file" ;;
        .omp/*)
            printf '%s/.omp/agent/%s\n' "$DOTFILES_HOME" "${file#.omp/}" ;;
        keyboard/hammerspoon/*)
            printf '%s/.hammerspoon/%s\n' "$DOTFILES_HOME" "${file#keyboard/hammerspoon/}" ;;
        keyboard/karabiner/*)
            printf '%s/.config/karabiner/%s\n' "$DOTFILES_HOME" "${file#keyboard/karabiner/}" ;;
        launchd/*)
            printf '%s/Library/LaunchAgents/%s\n' "$DOTFILES_HOME" "${file#launchd/}" ;;
        .aerospace.toml|.tmux.conf|.vimrc)
            printf '%s/%s\n' "$DOTFILES_HOME" "$file" ;;
        *)
            return 1 ;;
    esac
    return 0
}
supports_platform() {
    local file="$1"
    case "$PLATFORM:$file" in
        linux:.aerospace.toml|linux:keyboard/hammerspoon/*|linux:keyboard/karabiner/*|linux:launchd/*)
            return 1 ;;
    esac
    return 0
}
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

application_exists() {
    local command_name="$1" mac_app="${2:-}"
    command_exists "$command_name" && return 0
    [ "$PLATFORM" = "macos" ] && [ -n "$mac_app" ] && [ -d "/Applications/$mac_app.app" ]
}

install_missing_applications() {
    local missing=""
    application_exists ghostty Ghostty || missing="$missing ghostty"
    application_exists tmux || missing="$missing tmux"
    application_exists nvim || missing="$missing neovim"
    application_exists omp || missing="$missing omp"
    if [ "$PLATFORM" = "macos" ]; then
        application_exists aerospace AeroSpace || missing="$missing aerospace"
    fi
    [ -n "$missing" ] || { printf 'applications: all required applications are installed\n'; return; }

    printf 'Missing applications:%s\n' "$missing"
    if [ "$INSTALL_APPS" = "ask" ]; then
        if [ ! -t 0 ]; then
            printf 'applications: skipped because input is not interactive\n'
            return
        fi
        printf 'Install missing applications? [y/N] '
        read -r answer
        case "$answer" in y|Y|yes|YES) INSTALL_APPS="yes" ;; *) INSTALL_APPS="no" ;; esac
    fi
    [ "$INSTALL_APPS" = "yes" ] || { printf 'applications: skipped\n'; return; }

    if [ "$PLATFORM" = "macos" ]; then
        if ! command_exists brew; then
            printf 'Warning: Homebrew is required to install missing applications\n' >&2
            return
        fi
        for app in $missing; do
            case "$app" in
                ghostty) install_command brew install --cask ghostty || true ;;
                tmux|neovim) install_command brew install "$app" || true ;;
                aerospace) install_command brew install --cask nikitabobko/tap/aerospace || true ;;
                omp) install_command brew install can1357/tap/omp || true ;;
            esac
        done
        return
    fi

    local system_packages=""
    for app in $missing; do
        case "$app" in
            tmux|neovim) system_packages="$system_packages $app" ;;
            ghostty) printf 'Install Ghostty from https://ghostty.org/docs/install/binary\n' ;;
            omp) install_command sh -c 'curl -fsSL https://omp.sh/install | sh' || true ;;
        esac
    done
    if [ -n "$system_packages" ]; then
        if command_exists apt-get; then install_command sudo apt-get install -y $system_packages || true
        elif command_exists dnf; then install_command sudo dnf install -y $system_packages || true
        elif command_exists pacman; then install_command sudo pacman -S --needed --noconfirm $system_packages || true
        elif command_exists zypper; then install_command sudo zypper --non-interactive install $system_packages || true
        elif command_exists apk; then install_command sudo apk add $system_packages || true
        else printf 'Install these packages with your package manager:%s\n' "$system_packages"
        fi
    fi
}

install_command() {
    if $DRY_RUN; then
        printf '[dry-run] install:'
        printf ' %q' "$@"
        printf '\n'
    else
        if ! "$@"; then
            printf 'Warning: application install failed:' >&2
            printf ' %q' "$@" >&2
            printf '\n' >&2
            return 1
        fi
    fi
}



# Skip documentation and screenshots within mapped paths.
# Firmware, tests, and tools source are excluded by having no mapping.
should_skip() {
    local base="$1"
    case "$base" in
        README*.md|*.png) return 0 ;;
    esac
    return 1
}

ensure_backup_dir() {
    if [ -z "$BACKUP_DIR" ]; then
        BACKUP_DIR="$BACKUP_BASE/$(date +%Y%m%d-%H%M%S)"
        if $DRY_RUN; then
            printf '[dry-run] backup directory: %s\n' "$BACKUP_DIR"
        else
            mkdir -p "$BACKUP_DIR"
        fi
    fi
}

install_file() {
    local src="$1" target="$2"
    local target_dir
    target_dir=$(dirname "$target")

    # Already linked to our source - skip.
    if [ -L "$target" ]; then
        local existing
        existing=$(readlink "$target")
        if [ "$existing" = "$src" ]; then
            printf 'skip      %s\n' "$target"
            skipped=$((skipped + 1))
            return 0
        fi
    fi

    # Existing file/dir/symlink - back up before linking.
    if [ -e "$target" ] || [ -L "$target" ]; then
        ensure_backup_dir
        local rel="${target#"$DOTFILES_HOME"/}"
        local backup_path="$BACKUP_DIR/$rel"
        local backup_dir
        backup_dir=$(dirname "$backup_path")
        if $DRY_RUN; then
            printf '[dry-run] backup %s -> %s\n' "$target" "$backup_path"
        else
            mkdir -p "$backup_dir"
            mv "$target" "$backup_path"
        fi
        backed_up=$((backed_up + 1))
    fi

    # Create parent directory and symlink.
    if $DRY_RUN; then
        printf '[dry-run] link %s -> %s\n' "$target" "$src"
    else
        mkdir -p "$target_dir"
        ln -s "$src" "$target"
        printf 'link      %s -> %s\n' "$target" "$src"
    fi
    linked=$((linked + 1))
}

# --- Main ---

printf 'source:   %s\n' "$SRC"
printf 'home:     %s\n' "$DOTFILES_HOME"
printf 'dry-run:  %s\n' "$DRY_RUN"
printf 'platform: %s\n' "$PLATFORM"
printf '\n'
if [ -f "$SRC/.gitmodules" ]; then
    if $DRY_RUN; then
        printf '[dry-run] git submodule update --init --recursive\n'
    else
        git -C "$SRC" submodule update --init --recursive
    fi
fi


# Get the list of git-tracked files only (never ignored or untracked).
tracked_files=$(git -C "$SRC" ls-files) || {
    printf 'Error: git ls-files failed\n' >&2
    exit 1
}

total=0
while IFS= read -r file; do
    total=$((total + 1))
    if ! supports_platform "$file"; then
        platform_skipped=$((platform_skipped + 1))
        continue
    fi
    if ! target=$(map_target "$file"); then
        excluded=$((excluded + 1))
        continue
    fi
    if should_skip "$(basename "$file")"; then
        excluded=$((excluded + 1))
        continue
    fi
    install_file "$SRC/$file" "$target"
done <<< "$tracked_files"

printf '\n'
printf 'Summary: %d tracked, %d linked, %d skipped, %d backed up, %d platform-only, %d excluded\n' \
    "$total" "$linked" "$skipped" "$backed_up" "$platform_skipped" "$excluded"
if [ -n "$BACKUP_DIR" ]; then
    printf 'Backup:  %s\n' "$BACKUP_DIR"
fi
if $DRY_RUN; then
    printf '(dry-run: no changes made)\n'
fi
printf '\n'
install_missing_applications
