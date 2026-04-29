#!/usr/bin/env bash
set -euo pipefail

DOTFILES=(
  ".tmux.conf"
  ".vimrc"
)

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--copy] [--dry-run] [--install-fonts] [--configure-gnome-terminal-font] [--no-vim-plug] [--no-vim-plugins]

Deploy dotfiles in this repository to the current user's home directory.

Options:
  --copy            Copy files instead of creating symbolic links.
  --dry-run         Show what would be done without changing files.
  --install-fonts   Install Guguru Sans Code.
  --configure-gnome-terminal-font
                    Set the default GNOME Terminal profile font to Guguru Sans Code.
  --no-vim-plug     Do not install vim-plug.
  --no-vim-plugins  Do not run PlugInstall after deploying .vimrc.
  -h, --help        Show this help.
USAGE
}

mode="link"
dry_run=0
install_fonts=0
configure_gnome_terminal_font=0
install_vim_plug=1
install_vim_plugins=1

while (($#)); do
  case "$1" in
    --copy)
      mode="copy"
      ;;
    --dry-run)
      dry_run=1
      ;;
    --install-fonts)
      install_fonts=1
      ;;
    --configure-gnome-terminal-font)
      configure_gnome_terminal_font=1
      ;;
    --no-vim-plug)
      install_vim_plug=0
      install_vim_plugins=0
      ;;
    --no-vim-plugins)
      install_vim_plugins=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
home_dir="${HOME:?HOME is not set}"
backup_dir="$home_dir/.dotfiles_backup/$(date +%Y%m%d%H%M%S)"
backup_created=0

run() {
  if ((dry_run)); then
    printf 'dry-run:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

download() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    run curl -fLo "$output" --create-dirs "$url"
  elif command -v wget >/dev/null 2>&1; then
    run mkdir -p "$(dirname "$output")"
    run wget -O "$output" "$url"
  else
    echo "error: curl or wget is required to install vim-plug" >&2
    return 1
  fi
}

install_guguru_sans_code() {
  local version="0.0.3"
  local font_dir="$home_dir/.local/share/fonts/GuguruSansCode"
  local archive_url="https://github.com/yuru7/guguru-sans-code/releases/download/v$version/GuguruSansCodeNF_v$version.zip"
  local tmpdir

  if ((!install_fonts)); then
    return
  fi

  if command -v fc-list >/dev/null 2>&1 && fc-list | grep -qi 'Guguru Sans Code'; then
    echo "ok: Guguru Sans Code is already installed"
    return
  fi

  if ! command -v unzip >/dev/null 2>&1; then
    echo "error: unzip is required to install Guguru Sans Code" >&2
    return 1
  fi

  echo "install: Guguru Sans Code NF $version -> $font_dir"
  if ((dry_run)); then
    run mkdir -p "$font_dir"
    download "$archive_url" "<temporary-archive>"
    run unzip -q "<temporary-archive>" -d "<temporary-directory>"
    run find "<temporary-directory>/GuguruSansCodeNF_v$version" -type f -name "*.ttf" -exec cp "{}" "$font_dir/" ";"
    run fc-cache -f "$font_dir"
    return
  fi

  tmpdir="$(mktemp -d)"
  download "$archive_url" "$tmpdir/GuguruSansCodeNF_v$version.zip"
  unzip -q "$tmpdir/GuguruSansCodeNF_v$version.zip" -d "$tmpdir"
  run mkdir -p "$font_dir"
  find "$tmpdir/GuguruSansCodeNF_v$version" -type f -name "*.ttf" -exec cp {} "$font_dir/" \;
  rm -rf "$tmpdir"

  if command -v fc-cache >/dev/null 2>&1; then
    run fc-cache -f "$font_dir"
  else
    echo "skip: fc-cache command is not available; restart applications if fonts are not visible" >&2
  fi
}

configure_gnome_terminal() {
  local profile
  local schema
  local font_name="Guguru Sans Code Console NF 14"

  if ((!configure_gnome_terminal_font)); then
    return
  fi

  if ! command -v gsettings >/dev/null 2>&1; then
    echo "skip: gsettings command is not available; cannot configure GNOME Terminal font" >&2
    return
  fi

  profile="$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")"
  if [[ -z "$profile" ]]; then
    echo "skip: GNOME Terminal default profile was not found" >&2
    return
  fi

  schema="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile/"
  echo "configure: GNOME Terminal default profile font -> $font_name"
  run gsettings set "$schema" use-system-font false
  run gsettings set "$schema" font "$font_name"
}

ensure_backup_dir() {
  if ((backup_created)); then
    return
  fi

  run mkdir -p "$backup_dir"
  backup_created=1
}

deploy_file() {
  local name="$1"
  local source="$repo_dir/$name"
  local target="$home_dir/$name"

  if [[ ! -e "$source" ]]; then
    echo "skip: $name does not exist in repository" >&2
    return
  fi

  if [[ -L "$target" ]]; then
    local current_link
    current_link="$(readlink "$target")"
    if [[ "$current_link" == "$source" ]]; then
      echo "ok: $target already points to $source"
      return
    fi
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    ensure_backup_dir
    echo "backup: $target -> $backup_dir/$name"
    run mv "$target" "$backup_dir/$name"
  fi

  if [[ "$mode" == "copy" ]]; then
    echo "copy: $source -> $target"
    run cp "$source" "$target"
  else
    echo "link: $target -> $source"
    run ln -s "$source" "$target"
  fi
}

ensure_vim_plug() {
  local plug_path="$home_dir/.vim/autoload/plug.vim"
  local plug_url="https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"

  if ((!install_vim_plug)); then
    return
  fi

  if [[ -f "$plug_path" ]]; then
    echo "ok: vim-plug already exists at $plug_path"
    return
  fi

  echo "install: vim-plug -> $plug_path"
  download "$plug_url" "$plug_path"
}

install_vimrc_plugins() {
  local vimrc="$repo_dir/.vimrc"
  local plugin_vimrc

  if ((!install_vim_plugins)); then
    return
  fi

  if ! command -v vim >/dev/null 2>&1; then
    echo "skip: vim command is not available; run :PlugInstall after installing vim" >&2
    return
  fi

  if ! grep -q 'plug#begin' "$vimrc"; then
    echo "skip: no vim-plug block found in $vimrc"
    return
  fi

  echo "install: vim plugins from .vimrc"
  if ((dry_run)); then
    echo "dry-run: create temporary vimrc containing only the vim-plug block from $vimrc"
    run vim -Nu "<temporary-vim-plug-only-vimrc>" -n -es -S NONE +'PlugInstall --sync' +qa
    return
  fi

  plugin_vimrc="$(mktemp)"
  awk '
    /plug#begin/ { in_plug = 1 }
    in_plug { print }
    /plug#end/ { in_plug = 0 }
  ' "$vimrc" >"$plugin_vimrc"

  if ! vim -Nu "$plugin_vimrc" -n -es -S NONE +'PlugInstall --sync' +qa; then
    rm -f "$plugin_vimrc"
    return 1
  fi
  rm -f "$plugin_vimrc"
}

main() {
  echo "repository: $repo_dir"
  echo "home: $home_dir"
  echo "mode: $mode"

  for dotfile in "${DOTFILES[@]}"; do
    deploy_file "$dotfile"
  done

  install_guguru_sans_code
  configure_gnome_terminal
  ensure_vim_plug
  install_vimrc_plugins

  if ((backup_created && !dry_run)); then
    echo "backup directory: $backup_dir"
  fi
}

main "$@"
