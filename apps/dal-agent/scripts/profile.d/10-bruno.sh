#!/usr/bin/env bash
# Bruno global profile (sourced by ~/.zshrc or ~/.bashrc)

export BRUNO_HOME="${BRUNO_HOME:-$HOME/.bruno}"
export BRUNO_CMD="${BRUNO_CMD:-bruno}"

# Ensure ~/.local/bin is on PATH
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Create vault directory if it doesn't exist
if [ ! -d "$BRUNO_HOME/vault" ]; then
  mkdir -p "$BRUNO_HOME/vault"
  chmod 700 "$BRUNO_HOME/vault"
fi

# Create logs directory if it doesn't exist
if [ ! -d "$BRUNO_HOME/logs" ]; then
  mkdir -p "$BRUNO_HOME/logs"
  chmod 700 "$BRUNO_HOME/logs"
fi

# Remove any existing bruno alias before defining function
unalias bruno 2>/dev/null || true

# Bruno aliases and functions
alias bruno-test='~/.local/bin/bruno-wrapper run <<< "echo \"Bruno wrapper test successful\""'
alias bruno-health='./scripts/check_bruno.sh'
alias bruno-sql='./scripts/bruno-sql.sh'
alias bruno-secure='./scripts/bruno-secure.sh'

# Function for Bruno run commands (replaces the broken alias)
bruno() {
    if [[ "$1" == "run" ]]; then
        shift
        ~/.local/bin/bruno-wrapper run "$@"
    else
        ~/.local/bin/bruno-wrapper "$@"
    fi
}

# Export function for use in subshells
export -f bruno

# Keychain integration helper
bruno-inject-credentials() {
    local project_dir="${PWD}"
    if [[ -f "$project_dir/scripts/keychain-secrets.sh" ]]; then
        source "$project_dir/scripts/keychain-secrets.sh"
        inject_environment
    else
        echo "⚠️  Keychain secrets script not found in current project" >&2
        return 1
    fi
}