#!/usr/bin/env bash
set -euo pipefail

repo="nuetzliches/hookaido"
api_url="https://api.github.com/repos/${repo}/releases/latest"

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    MINGW* | MSYS* | CYGWIN*) echo "windows" ;;
    *)
      echo "Unsupported OS: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "amd64" ;;
    arm64 | aarch64) echo "arm64" ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

resolve_tag() {
  if [[ -n "${HOOKAIDO_VERSION:-}" ]]; then
    echo "${HOOKAIDO_VERSION}"
    return
  fi

  local tag
  tag="$(
    curl -fsSL "$api_url" \
      | tr -d '\n' \
      | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p'
  )"

  if [[ -z "$tag" ]]; then
    echo "Could not resolve latest hookaido version from GitHub API." >&2
    exit 1
  fi

  echo "$tag"
}

main() {
  local os arch tag ext artifact url tmpdir archive install_dir binary_name extracted_bin dest
  os="$(detect_os)"
  arch="$(detect_arch)"
  tag="$(resolve_tag)"

  if [[ "$os" == "windows" ]]; then
    ext="zip"
    binary_name="hookaido.exe"
  else
    ext="tar.gz"
    binary_name="hookaido"
  fi

  artifact="hookaido_${tag}_${os}_${arch}.${ext}"
  url="https://github.com/${repo}/releases/download/${tag}/${artifact}"

  tmpdir="$(mktemp -d)"
  trap 'if [[ -n "${tmpdir:-}" ]]; then rm -rf "$tmpdir"; fi' EXIT
  archive="${tmpdir}/${artifact}"

  echo "Downloading ${url}"
  curl -fL "$url" -o "$archive"

  if [[ "$ext" == "zip" ]]; then
    if ! command -v unzip >/dev/null 2>&1; then
      echo "Missing dependency: unzip" >&2
      exit 1
    fi
    unzip -q "$archive" -d "$tmpdir"
  else
    tar -xzf "$archive" -C "$tmpdir"
  fi

  extracted_bin="$(find "$tmpdir" -type f -name "$binary_name" | head -n 1 || true)"
  if [[ -z "$extracted_bin" ]]; then
    echo "Binary ${binary_name} not found in extracted archive." >&2
    exit 1
  fi

  install_dir="${HOOKAIDO_INSTALL_DIR:-$HOME/.local/bin}"
  mkdir -p "$install_dir"
  dest="${install_dir}/${binary_name}"

  if command -v install >/dev/null 2>&1; then
    install -m 0755 "$extracted_bin" "$dest"
  else
    cp "$extracted_bin" "$dest"
    chmod +x "$dest"
  fi

  echo "Installed ${binary_name} to ${dest}"
  echo "Add to PATH if needed: export PATH=\"${install_dir}:\$PATH\""
}

main "$@"
