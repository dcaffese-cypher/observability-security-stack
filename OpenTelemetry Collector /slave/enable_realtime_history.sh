#!/usr/bin/env bash
set -euo pipefail

# Snippet to add (uses same marker for detection)
snippet='## Real-time history to Loki'

# Content to add (heredoc-friendly)
snippet_content() {
cat <<'EOF'
## Real-time history to Loki
shopt -s histappend
PROMPT_COMMAND="history -a;$PROMPT_COMMAND"
EOF
}

# Add snippet to a local file (creates file if it doesn't exist)
add_snippet_local() {
  local file="$1"
  local who="$2"

  # Ensure directory exists
  mkdir -p "$(dirname "$file")" 2>/dev/null || true

  if [ -f "$file" ]; then
    if grep -qF "${snippet}" "$file" 2>/dev/null; then
      echo "ℹ️  $file already contains configuration – skipped ($who)"
      return 0
    fi
  fi

  # Add safely (with a newline first)
  {
    echo ''
    snippet_content
  } >> "$file"
  echo "✅ Configuration added to $file ($who)"
}

# Add snippet to a file as root using sudo (uses tee for compatibility)
add_snippet_root() {
  local file="/root/.bashrc"
  local who="root"

  # create /root if it doesn't exist (usually not needed, but we check)
  if sudo test -d /root 2>/dev/null; then
    if sudo test -f "$file" 2>/dev/null && sudo grep -qF "${snippet}" "$file" 2>/dev/null; then
      echo "ℹ️  $file already contains configuration – skipped (root)"
      return 0
    fi

    # Write with sudo tee (append). We use a heredoc with literal 'EOF' to preserve $
    sudo bash -c "mkdir -p /root 2>/dev/null || true; cat >> $file <<'EOF'

$(snippet_content)
EOF
"
    echo "✅ Configuration added to $file (root)"
  else
    echo "⚠️  Cannot access /root for writing. Run this script as root or check permissions."
    return 1
  fi
}

# Add snippet to /etc/profile.d (global) — recommended for Rocky if you want to apply to all users
add_snippet_global() {
  local dropin="/etc/profile.d/realtime-history-loki.sh"
  if [ "$(id -u)" -ne 0 ]; then
    # if not root, try with sudo
    if sudo test -f "$dropin" 2>/dev/null && sudo grep -qF "${snippet}" "$dropin" 2>/dev/null; then
      echo "ℹ️  $dropin already contains configuration – skipped (global)"
      return 0
    fi

    echo "🔐 Attempting to add global configuration to $dropin using sudo..."
    sudo bash -c "cat > $dropin <<'EOF'
$(snippet_content)
EOF
chmod 0644 $dropin
"
    echo "✅ Global configuration added to $dropin (via sudo)"
  else
    # we are root
    if [ -f "$dropin" ] && grep -qF "${snippet}" "$dropin" 2>/dev/null; then
      echo "ℹ️  $dropin already contains configuration – skipped (global)"
      return 0
    fi
    cat > "$dropin" <<'EOF'
$(snippet_content)
EOF
    chmod 0644 "$dropin"
    echo "✅ Global configuration added to $dropin (root)"
  fi
}

# ---------------------------
# Shell detection for current user
# ---------------------------
user_shell="$(basename "${SHELL:-/bin/bash}")"

case "$user_shell" in
  bash)
    user_file="$HOME/.bashrc"
    ;;
  zsh)
    user_file="$HOME/.zshrc"
    ;;
  *)
    # Default: try with .bashrc and .profile
    user_file="$HOME/.bashrc"
    ;;
esac

# 1️⃣ Add to user executing the script
add_snippet_local "$user_file" "$USER"

# 2️⃣ Try to add to root (if already root or using sudo)
if [ "$(id -u)" -eq 0 ]; then
  # Already root: add to /root/.bashrc and /etc/profile.d
  add_snippet_local /root/.bashrc root || true
  add_snippet_global
else
  # Not root: try with sudo to /root/.bashrc and /etc/profile.d
  if command -v sudo >/dev/null 2>&1; then
    # Add to /root/.bashrc via sudo
    echo "🔐 Attempting to add configuration to root user (/root/.bashrc) using sudo..."
    add_snippet_root || echo "⚠️  Could not add to /root/.bashrc with sudo."

    # Add global if desired — we do it by default. If you don't want global, comment the next line.
    add_snippet_global || echo "⚠️  Could not add global configuration (/etc/profile.d)."
  else
    echo "⚠️  'sudo' is not available. Run this script as root to add configuration to /root and /etc/profile.d."
  fi
fi

echo "Done. To apply changes in current session, run: source $user_file"
