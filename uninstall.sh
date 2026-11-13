#!/usr/bin/env bash
# Remove cat-cursor service and config blocks written by install.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
UNIT_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/cat-cursor.service"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
MARKER_BEGIN="-- omarchy-cat-cursor begin"
MARKER_END="-- omarchy-cat-cursor end"
CONF_MARKER_BEGIN="# omarchy-cat-cursor begin"
CONF_MARKER_END="# omarchy-cat-cursor end"
PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/io.github.AlbertMerle.cat-cursor"

systemctl --user disable --now cat-cursor.service >/dev/null 2>&1 || true
rm -f "$UNIT_PATH"
systemctl --user daemon-reload >/dev/null 2>&1 || true
hyprctl eval 'hl.config({cursor = {invisible = false}})' >/dev/null 2>&1 || true

strip_markers() {
  local file="$1" begin="$2" end="$3"
  [[ -f $file ]] || return 0
  local tmp
  tmp="$(mktemp)"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { skip=1; next }
    $0 == end { skip=0; next }
    !skip { print }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

strip_markers "$HYPR_DIR/looknfeel.lua" "$MARKER_BEGIN" "$MARKER_END"
strip_markers "$HYPR_DIR/bindings.lua" "$MARKER_BEGIN" "$MARKER_END"
strip_markers "$HYPR_DIR/cat-cursor.conf" "$CONF_MARKER_BEGIN" "$CONF_MARKER_END"
rm -f "$HYPR_DIR/cat-cursor.conf"

if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin disable io.github.AlbertMerle.cat-cursor >/dev/null 2>&1 || true
fi
# Only remove the copied plugin tree, never the checkout being run from.
if [[ -d $PLUGIN_DIR && $PLUGIN_DIR != "$ROOT" ]]; then
  rm -rf "$PLUGIN_DIR"
fi

hyprctl reload >/dev/null 2>&1 || true
echo "cat-cursor uninstalled"
