#!/usr/bin/env bash
set -euo pipefail

snippet='## Real-time history to Loki'

add_snippet() {
  local file="$1" who="$2"

  if grep -q "${snippet}" "$file" 2>/dev/null; then
    echo "ℹ️  $file already contains configuration – skipped ($who)"
  else
    {
      echo ''
      echo "${snippet}"
      echo 'shopt -s histappend'
      echo 'PROMPT_COMMAND="history -a;$PROMPT_COMMAND"'
    } >> "$file"
    echo "✅ Configuration added to $file ($who)"
  fi
}

# 1️⃣ User executing the script
add_snippet "$HOME/.bashrc" "$USER"

# 2️⃣ Root user
if [ "$(id -u)" -eq 0 ]; then
  add_snippet /root/.bashrc root        # already root
else
  sudo bash -c "$(declare -f add_snippet); add_snippet /root/.bashrc root"
fi
