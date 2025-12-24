#!/bin/bash

###############################################################################
# GitHub Access Setup Script for VPS Servers
#
# - Configures global git username and email
# - Sets up GitHub Personal Access Tokens (PATs)
# - Supports host-wide tokens or per-repo tokens
# - Allows updating/replacing tokens on subsequent runs
#
# NOTE: When using credential helper 'store', tokens are saved in plaintext
#       in ~/.git-credentials. Use repo-scoped, least-privilege tokens.
###############################################################################

set -euo pipefail

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

print_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
print_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
print_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

prompt_nonempty() {
  local prompt="$1"; local var
  while true; do
    read -r -p "$prompt" var
    if [[ -n "$var" ]]; then
      echo "$var"
      return 0
    fi
    print_warn "Value cannot be empty."
  done
}

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    print_ok "git is already installed ($(git --version))."
    return
  fi

  print_info "git not found. Attempting to install (Ubuntu/Debian only)..."
  if command -v apt-get >/dev/null 2>&1; then
    if [[ $EUID -ne 0 ]]; then
      print_error "Run as root or with sudo to install git, or install git manually."
      exit 1
    fi
    apt-get update -qq && apt-get install -y git
    print_ok "git installed."
  else
    print_error "Package manager 'apt-get' not found. Please install git manually."
    exit 1
  fi
}

configure_identity() {
  echo
  print_info "Configuring global git identity..."

  local current_name current_email
  current_name=$(git config --global user.name || true)
  current_email=$(git config --global user.email || true)

  echo "Current name : ${current_name:-<not set>}"
  echo "Current email: ${current_email:-<not set>}"
  echo

  local name email
  name=$(prompt_nonempty "Enter git user.name  (e.g., John Doe): ")
  email=$(prompt_nonempty "Enter git user.email (e.g., you@example.com): ")

  git config --global user.name "$name"
  git config --global user.email "$email"

  print_ok "Global git identity set to '$name' <$email>."
}

ensure_credential_store() {
  # Use the simple file-based credential store (~/.git-credentials)
  local helper
  helper=$(git config --global credential.helper || true)

  if [[ "$helper" != "store" && "$helper" != *store* ]]; then
    print_info "Configuring git credential helper to 'store' (plaintext in ~/.git-credentials)."
    git config --global credential.helper store
  else
    print_ok "Credential helper already includes 'store'."
  fi
}

mask_token_line() {
  # Hide the token when displaying credentials
  sed -E 's#(https?://[^:]+):[^@]*(@github.com.*)#\1:***\2#'
}

list_github_credentials() {
  local cred_file="$HOME/.git-credentials"
  if [[ ! -f "$cred_file" ]]; then
    print_warn "No ~/.git-credentials file found."
    return
  fi
  print_info "Stored GitHub credentials (token masked):"
  grep "github.com" "$cred_file" | mask_token_line || print_warn "No github.com entries found."
}

add_or_update_token() {
  echo
  print_info "GitHub token configuration"
  echo "How do you want to scope this token?"
  echo "  1) Host-wide for all repos on github.com"
  echo "  2) Specific repo (recommended per-project)"
  echo
  read -r -p "Choose option (1/2): " scope_choice

  local username token scope_url match_pattern

  username=$(prompt_nonempty "Enter your GitHub username (for URL): ")

  echo
  echo "Token input options:"
  echo "  1) Visible (easier to paste)"
  echo "  2) Hidden (more secure)"
  read -r -p "Choose option (1/2, default: 1): " token_visibility
  token_visibility=${token_visibility:-1}

  echo
  if [[ "$token_visibility" == "2" ]]; then
    echo -n "Enter GitHub Personal Access Token (hidden): "
    read -rs token
    echo
  else
    print_info "Enter GitHub Personal Access Token (visible - paste-friendly):"
    read -r token
  fi

  if [[ -z "$token" ]]; then
    print_error "Token cannot be empty."
    return 1
  fi

  case "$scope_choice" in
    2)
      echo
      print_info "Example repo URL: https://github.com/owner/repo.git"
      scope_url=$(prompt_nonempty "Enter GitHub repo URL to scope this token to: ")
      # Normalize URL: strip trailing .git if present
      scope_url=${scope_url%.git}

      # Extract path part after github.com
      local path
      path=$(echo "$scope_url" | sed -E 's#https?://github.com(/.*)#\1#')
      if [[ -z "$path" || "$path" == "$scope_url" ]]; then
        print_error "Invalid GitHub repo URL. Must be https://github.com/owner/repo[.git]"
        return 1
      fi

      match_pattern="https://$username:@github.com$path"
      new_line="https://$username:$token@github.com$path"
      ;;
    *)
      # Host-wide
      scope_url="https://github.com"
      match_pattern="https://$username:@github.com"
      new_line="https://$username:$token@github.com"
      ;;
  esac

  local cred_file="$HOME/.git-credentials"
  touch "$cred_file"

  # Remove any existing lines for this user/scope (very loose match to avoid leaks)
  if grep -q "github.com" "$cred_file" 2>/dev/null; then
    # Remove lines that match this username and github.com
    grep -v "https://$username:.*@github.com" "$cred_file" > "${cred_file}.tmp" || true
    mv "${cred_file}.tmp" "$cred_file"
  fi

  echo "$new_line" >> "$cred_file"
  chmod 600 "$cred_file"

  print_ok "Token stored for $scope_url (user: $username)."
  print_warn "Remember: token is stored in plaintext in $cred_file. Use minimal scopes." 
}

remove_github_credentials() {
  local cred_file="$HOME/.git-credentials"
  if [[ ! -f "$cred_file" ]]; then
    print_warn "No ~/.git-credentials file found."
    return
  fi

  echo
  print_info "Remove GitHub credentials"
  list_github_credentials
  echo
  read -r -p "Enter GitHub username whose credentials you want to remove (or press Enter to cancel): " user
  if [[ -z "$user" ]]; then
    print_info "Cancelled."
    return
  fi

  if ! grep -q "https://$user:.*@github.com" "$cred_file" 2>/dev/null; then
    print_warn "No credentials found for user '$user' on github.com."
    return
  fi

  grep -v "https://$user:.*@github.com" "$cred_file" > "${cred_file}.tmp" || true
  mv "${cred_file}.tmp" "$cred_file"

  print_ok "Removed credentials for user '$user' on github.com."
}

main_menu() {
  echo ""
  echo "=========================================="
  echo " GitHub Setup & Token Manager"
  echo "=========================================="
  echo " 1) Configure git username/email"
  echo " 2) Add/Update GitHub token"
  echo " 3) List stored GitHub credentials"
  echo " 4) Remove GitHub credentials by username"
  echo " 5) Exit"
  echo "=========================================="
  echo ""
}

main() {
  ensure_git
  ensure_credential_store

  while true; do
    main_menu
    read -r -p "Choose an option (1-5): " choice
    case "$choice" in
      1)
        configure_identity
        ;;
      2)
        add_or_update_token
        ;;
      3)
        list_github_credentials
        ;;
      4)
        remove_github_credentials
        ;;
      5)
        print_info "Done. Bye."
        exit 0
        ;;
      *)
        print_warn "Invalid choice. Please select 1-5."
        ;;
    esac
    echo
  done
}

main "$@"

