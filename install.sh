#!/usr/bin/env bash
# Install cat-cursor for Omarchy / Hyprland + Quickshell.
# Safe to re-run. Does not modify the cat runtime files.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_PATH="$UNIT_DIR/cat-cursor.service"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
MARKER_BEGIN="-- omarchy-cat-cursor begin"
MARKER_END="-- omarchy-cat-cursor end"
CONF_MARKER_BEGIN="# omarchy-cat-cursor begin"
CONF_MARKER_END="# omarchy-cat-cursor end"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "install.sh: missing dependency: $1" >&2
    exit 1
  }
}

need hyprctl
need quickshell
need python3
need systemctl

chmod +x "$ROOT/cat-cursor" "$ROOT/install.sh"
[[ -f $ROOT/uninstall.sh ]] && chmod +x "$ROOT/uninstall.sh"

mkdir -p "$UNIT_DIR"
cat >"$UNIT_PATH" <<EOF
[Unit]
Description=Animated cat cursor
After=graphical-session.target
PartOf=graphical-session.target

[Service]
ExecStart=$ROOT/cat-cursor run
ExecStopPost=/usr/bin/hyprctl eval "hl.config({cursor = {invisible = false}})"
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF

write_block_file() {
  local path="$1"
  cat >"$path"
}

upsert_marked_block() {
  local file="$1"
  local begin="$2"
  local end="$3"
  local block_file="$4"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  local tmp
  tmp="$(mktemp)"
  if grep -F -- "$begin" "$file" >/dev/null; then
    awk -v begin="$begin" -v end="$end" -v block_file="$block_file" '
      BEGIN {
        while ((getline line < block_file) > 0) {
          block = block line "\n"
        }
        close(block_file)
      }
      $0 == begin { printf "%s", block; skip=1; next }
      $0 == end { skip=0; next }
      !skip { print }
    ' "$file" >"$tmp"
  else
    cat "$file" >"$tmp"
    [[ -s $tmp ]] && printf '\n' >>"$tmp"
    cat "$block_file" >>"$tmp"
  fi
  mv "$tmp" "$file"
}

# Drop pre-marker install lines so first-time upgrade does not duplicate binds/rules.
scrub_legacy_lua() {
  local file="$1"
  [[ -f $file ]] || return 0
  grep -F -- "$MARKER_BEGIN" "$file" >/dev/null && return 0
  local tmp
  tmp="$(mktemp)"
  grep -Ev 'cat-cursor|Cat attack|Toggle cat cursor|Cat cursor is a small overlay|Cat cursor overlay' "$file" >"$tmp" || true
  mv "$tmp" "$file"
}

LOOK_BLOCK="$(mktemp)"
BIND_BLOCK="$(mktemp)"
CONF_BLOCK="$(mktemp)"
trap 'rm -f "$LOOK_BLOCK" "$BIND_BLOCK" "$CONF_BLOCK"' EXIT

write_block_file "$LOOK_BLOCK" <<EOF
$MARKER_BEGIN
-- Cat cursor overlay: disable Hyprland layer easing so the sprite stays on the pointer.
-- Sprite run/jump/attack animations are unchanged.
hl.layer_rule({ match = { namespace = "cat-cursor" }, no_anim = true, animation = "none" })
$MARKER_END
EOF

write_block_file "$BIND_BLOCK" <<EOF
$MARKER_BEGIN
-- Cat cursor controls
o.bind("mouse:272", "Cat attack", "$ROOT/cat-cursor attack", { non_consuming = true, ignore_mods = true })
o.bind("SUPER + ALT + C", "Toggle cat cursor", "$ROOT/cat-cursor toggle")
$MARKER_END
EOF

write_block_file "$CONF_BLOCK" <<EOF
$CONF_MARKER_BEGIN
# Cat cursor: no layer easing (sprite animations stay on). Toggle: Super+Alt+C
layerrule = noanim, namespace:^(cat-cursor)$
bind = SUPER ALT, C, exec, $ROOT/cat-cursor toggle
bind = , mouse:272, exec, $ROOT/cat-cursor attack
$CONF_MARKER_END
EOF

if [[ -f $HYPR_DIR/looknfeel.lua || -f $HYPR_DIR/bindings.lua || -d /usr/share/omarchy ]]; then
  scrub_legacy_lua "$HYPR_DIR/looknfeel.lua"
  scrub_legacy_lua "$HYPR_DIR/bindings.lua"
  upsert_marked_block "$HYPR_DIR/looknfeel.lua" "$MARKER_BEGIN" "$MARKER_END" "$LOOK_BLOCK"
  upsert_marked_block "$HYPR_DIR/bindings.lua" "$MARKER_BEGIN" "$MARKER_END" "$BIND_BLOCK"
else
  upsert_marked_block "$HYPR_DIR/cat-cursor.conf" "$CONF_MARKER_BEGIN" "$CONF_MARKER_END" "$CONF_BLOCK"
  if [[ -f $HYPR_DIR/hyprland.conf ]] && ! grep -Fq 'cat-cursor.conf' "$HYPR_DIR/hyprland.conf"; then
    printf '\nsource = %s/cat-cursor.conf\n' "$HYPR_DIR" >>"$HYPR_DIR/hyprland.conf"
  fi
fi

# Optional Omarchy plugin registration (copy, never symlink — validate forbids links).
PLUGIN_ID="io.github.AlbertMerle.cat-cursor"
PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"
if command -v omarchy >/dev/null 2>&1 && [[ "$(basename "$ROOT")" != "$PLUGIN_ID" ]]; then
  mkdir -p "$(dirname "$PLUGIN_DIR")"
  rm -rf "$PLUGIN_DIR"
  mkdir -p "$PLUGIN_DIR"
  for name in \
    manifest.json Service.qml install.sh uninstall.sh README.md LICENSE \
    cat-cursor shell.qml tracker.py layers.py frame-bounds.json \
    cat-mister-actions.png measure_frames.py; do
    [[ -e $ROOT/$name ]] && cp -a "$ROOT/$name" "$PLUGIN_DIR/$name"
  done
  chmod +x "$PLUGIN_DIR/cat-cursor" "$PLUGIN_DIR/install.sh"
  [[ -f $PLUGIN_DIR/uninstall.sh ]] && chmod +x "$PLUGIN_DIR/uninstall.sh"
  if command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi
  if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 || true
  fi
fi

systemctl --user daemon-reload
systemctl --user enable --now cat-cursor.service
hyprctl reload >/dev/null 2>&1 || true

echo "cat-cursor installed from $ROOT"
echo "Toggle with Super+Alt+C. Attack on left click."
echo "Useful: $ROOT/cat-cursor start|stop|toggle|attack"
