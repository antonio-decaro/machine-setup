#!/bin/sh
set -eu

umask 022

# login-env bootstrap installer
# Designed to be run via: curl -fsSL <URL>/install.sh | sh
# Installs a modular login environment under ~/.config/login and hooks it into shell startup.

# Install .config relative to where the script is run
BASE_DIR="$HOME"
CONFIG_ROOT="$BASE_DIR/.config"
CACHE_ROOT="$BASE_DIR/.cache"
LOGIN_DIR="$CONFIG_ROOT/login"
CACHE_DIR="$CACHE_ROOT/login"
MODULES_CONF="$CONFIG_ROOT/modules.conf"

mkdir -p "$LOGIN_DIR" "$LOGIN_DIR/software" "$CACHE_DIR"
mkdir -p "$HOME/.local/bin" "$HOME/.local/lib" "$HOME/.local/include"

# -------------------------------------------------
# Write core scripts
# -------------------------------------------------

cat > "$LOGIN_DIR/env.sh" <<'EOF'
#!/usr/bin/env bash

LOGIN_DIR="$HOME/.config/login"

# Prevent double-loading
if [[ -n "${LOGIN_ENV_LOADED:-}" ]]; then
  [[ -n "${PS1:-}" ]] && echo "[login] Environment already initialized — skipping."
  return
fi
export LOGIN_ENV_LOADED=1

# Source numbered scripts in a stable order
for f in "$LOGIN_DIR"/[0-9][0-9]-*.sh; do
  [[ -r "$f" ]] && source "$f"
done

# Source software snippets (optional)
if [[ -d "$LOGIN_DIR/software" ]]; then
  for f in "$LOGIN_DIR"/software/*.sh; do
    [[ -r "$f" ]] && source "$f"
  done
fi
EOF

chmod 0755 "$LOGIN_DIR/env.sh"

# -------------------------------------------------
# PATH setup
# -------------------------------------------------

cat > "$LOGIN_DIR/10-paths.sh" <<'EOF'
#!/usr/bin/env bash

# User-local installs
export PATH="$HOME/.local/bin:$PATH"

# Only add if directories exist
if [[ -d "$HOME/.local/lib" ]]; then
  export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
fi
EOF

chmod 0755 "$LOGIN_DIR/10-paths.sh"

# -------------------------------------------------
# Modules loader + resume
# -------------------------------------------------

cat > "$LOGIN_DIR/20-modules.sh" <<'EOF'
#!/usr/bin/env bash

# If modules aren't available, do nothing
command -v module &>/dev/null || return 0

MODULES_CONF="$HOME/.config/modules.conf"

# Load modules listed in modules.conf (one per line, # comments allowed)
if [[ -r "$MODULES_CONF" ]]; then
  while IFS= read -r mod; do
    case "$mod" in
      ""|\#*) continue ;;
    esac
    module load "$mod" >/dev/null 2>&1 || module load "$mod"
  done < "$MODULES_CONF"
fi

_summary="$(module -t list 2>&1 | sed '/^No modules loaded$/d')"
[[ -z "$_summary" ]] && _summary="(no modules loaded)"

# Print only in interactive shells
if [[ -n "${PS1:-}" ]]; then
  echo "----- [login] Loaded modules -----"
  echo "$_summary"
  echo "-----------------------------------------"
fi
EOF

chmod 0755 "$LOGIN_DIR/20-modules.sh"

# -------------------------------------------------
# Aliases placeholder
# -------------------------------------------------

cat > "$LOGIN_DIR/30-aliases.sh" <<'EOF'
#!/usr/bin/env bash

# Place your aliases and helper functions here
# Example:
# alias ll='ls -lah'
EOF

chmod 0755 "$LOGIN_DIR/30-aliases.sh"

# -------------------------------------------------
# Software snippets placeholder
# -------------------------------------------------

SOFTWARE_EXAMPLE="$LOGIN_DIR/software/example.sh"
if [ ! -e "$SOFTWARE_EXAMPLE" ]; then
  cat > "$SOFTWARE_EXAMPLE" <<'EOF'
#!/usr/bin/env bash
# Optional: software-specific environment snippets.
# Keep this file as a template or delete it.
EOF
  chmod 0755 "$SOFTWARE_EXAMPLE"
fi

# -------------------------------------------------
# Create modules.conf if missing
# -------------------------------------------------

if [ ! -f "$MODULES_CONF" ]; then
  cat > "$MODULES_CONF" <<'EOF'
# One module per line. Lines starting with # are ignored.
# Examples:
# shared
# slurm/slurm/23.11.10
# gcc/12.2.0
# openmpi/4.1.6
# cuda/12.3
EOF
fi

# -------------------------------------------------
# Hook into shell startup files
# -------------------------------------------------

HOOK='[ -r "$HOME/.config/login/env.sh" ] && . "$HOME/.config/login/env.sh"'

append_hook() {
  rc="$1"
  # Create if missing
  if [ ! -f "$rc" ]; then
    printf '%s\n' "# login-env" "$HOOK" > "$rc"
    echo "[install] created $rc with login-env hook"
    return
  fi
  # Append if not present
  if ! grep -F "$HOOK" "$rc" >/dev/null 2>&1; then
    printf '\n%s\n%s\n' "# login-env" "$HOOK" >> "$rc"
    echo "[install] appended login-env hook to $rc"
  else
    echo "[install] hook already present in $rc"
  fi
}

# Bash interactive
append_hook "$HOME/.bashrc"

# Ensure login shells load bashrc (common on macOS / minimal envs)
if [ ! -f "$HOME/.bash_profile" ]; then
  cat > "$HOME/.bash_profile" <<'EOF'
# login-env: ensure interactive config is loaded for login shells
[ -r "$HOME/.bashrc" ] && . "$HOME/.bashrc"
EOF
  echo "[install] created ~/.bash_profile to source ~/.bashrc"
fi

# Zsh (macOS default)
append_hook "$HOME/.zshrc"

# For some systems using ~/.profile
if [ -f "$HOME/.profile" ]; then
  append_hook "$HOME/.profile"
fi

# -------------------------------------------------
# Final message
# -------------------------------------------------

cat <<EOF

✅ Installed login environment

Config directory:
  $LOGIN_DIR

Entry point:
  $LOGIN_DIR/env.sh

Modules list:
  $MODULES_CONF

Next steps:
  1) Edit $MODULES_CONF to list the modules you want loaded on login.
  2) Open a new terminal OR run:
       . "$LOGIN_DIR/env.sh"
EOF