#!/usr/bin/env bash
# Install the Pi tmux sidebar.
#
# Copies the scripts to a prefix (default ~/.local/bin), generates
# ~/.config/tmux/pi-sidebar.tmux.conf with the right paths, and tells you
# the one source-file line to add to your tmux config.
set -euo pipefail

PREFIX="${PI_SIDEBAR_PREFIX:-$HOME/.local/bin}"
PI_EXT_DIR="$HOME/.pi/agent/extensions"
OMP_EXT_DIR="$HOME/.omp/agent/extensions"
TMUX_CONF_DIR="$HOME/.config/tmux"
CONF_FILE="$TMUX_CONF_DIR/pi-sidebar.tmux.conf"
TOGGLE="$PREFIX/tmux-pi-sidebar-toggle"
SIDEBAR_CMD="$PREFIX/tmux-pi-sidebar"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Pi tmux sidebar to $PREFIX ..."
mkdir -p "$PREFIX" "$TMUX_CONF_DIR" "$PI_EXT_DIR"

# Core scripts.
for script in \
  tmux-pi-sidebar \
  tmux-pi-sidebar-toggle \
  tmux-pi-sidebar-daemon \
  tmux-pi-sidebar-outer \
  tmux-pi-sidebar-outer-control \
  tmux-pi-sidebar-inner-client; do
  cp "$script_dir/$script" "$PREFIX/$script"
  chmod +x "$PREFIX/$script"
done

# Pre-compiled sidebar view binary (arm64 only). Skip if the host arch
# does not match; the Python tmux-pi-sidebar script works as a fallback.
if [ -f "$script_dir/pi-sidebar-view" ]; then
  host_arch="$(uname -m 2>/dev/null || echo "")"
  if [ "$host_arch" = "arm64" ] || [ "$host_arch" = "aarch64" ]; then
    cp "$script_dir/pi-sidebar-view" "$PREFIX/pi-sidebar-view"
    chmod +x "$PREFIX/pi-sidebar-view"
    echo "Installed pi-sidebar-view (arm64 binary)."
  else
    echo "Skipping pi-sidebar-view: host is $host_arch, binary is arm64 only."
    echo "  The Python tmux-pi-sidebar script will be used instead."
  fi
fi

# Install the Pi extension that bridges agent status to @pi_agent_status
# so the sidebar can show per-session status icons. Skip if already present.
if [ ! -f "$PI_EXT_DIR/pi-sidebar-status.ts" ] || ! cmp -s "$script_dir/pi-sidebar-status.ts" "$PI_EXT_DIR/pi-sidebar-status.ts"; then
  cp "$script_dir/pi-sidebar-status.ts" "$PI_EXT_DIR/pi-sidebar-status.ts"
  echo "Installed Pi extension to $PI_EXT_DIR/pi-sidebar-status.ts"
else
  echo "Pi extension already up to date."
fi

# Also install the extension for OMP if the OMP extensions dir exists.
if [ -d "$OMP_EXT_DIR" ]; then
  if [ ! -f "$OMP_EXT_DIR/pi-sidebar-status.ts" ] || ! cmp -s "$script_dir/pi-sidebar-status.ts" "$OMP_EXT_DIR/pi-sidebar-status.ts"; then
    cp "$script_dir/pi-sidebar-status.ts" "$OMP_EXT_DIR/pi-sidebar-status.ts"
    echo "Installed OMP extension to $OMP_EXT_DIR/pi-sidebar-status.ts"
  fi
fi

echo "Writing $CONF_FILE ..."
sed -e "s|__SIDEBAR_TOGGLE__|$TOGGLE|g" \
    -e "s|__SIDEBAR_CMD__|$SIDEBAR_CMD|g" \
    "$script_dir/pi-sidebar.tmux.conf.template" > "$CONF_FILE"

# Offer to wire it into the user's tmux.conf if not already present.
TMUX_CONF="$HOME/.tmux.conf"
if [ -f "$TMUX_CONF" ] && ! grep -q "pi-sidebar.tmux.conf" "$TMUX_CONF"; then
  printf '\nsource-file %s\n' "$CONF_FILE" >> "$TMUX_CONF"
  echo "Added source-file line to $TMUX_CONF."
elif [ ! -f "$TMUX_CONF" ]; then
  printf 'source-file %s\n' "$CONF_FILE" > "$TMUX_CONF"
  echo "Created $TMUX_CONF with the source-file line."
else
  echo "Already wired into $TMUX_CONF."
fi

echo
echo "Done. Reload tmux config to activate:"
echo "  tmux source-file ~/.tmux.conf"
echo
echo "Then populate every window with a sidebar:"
echo "  $TOGGLE ensure-all"
echo
echo "Toggle expanded/collapsed with prefix+B."
echo
echo "If Pi was already running, reload it (e.g. /reload) so the new extension"
echo "is picked up; new Pi sessions pick it up automatically."
