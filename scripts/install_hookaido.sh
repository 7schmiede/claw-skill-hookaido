#!/usr/bin/env bash
set -euo pipefail

repo="nuetzliches/hookaido"
default_tag="v2.2.0"

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
  echo "${default_tag}"
}

normalize_sha256() {
  local value
  value="$(printf '%s' "$1" | sed 's/^sha256://I' | tr -d '[:space:]')"

  if [[ ! "$value" =~ ^[[:xdigit:]]{64}$ ]]; then
    echo "Invalid SHA256 checksum: ${1}" >&2
    exit 1
  fi

  printf '%s' "$value" | tr '[:upper:]' '[:lower:]'
}

hash_file_sha256() {
  local file="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return
  fi

  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$file" | awk '{print $2}'
    return
  fi

  echo "Missing dependency: sha256sum, shasum, or openssl is required." >&2
  exit 1
}

expected_sha_for_pinned_artifact() {
  case "$1" in
    "hookaido_v2.2.0_darwin_amd64.tar.gz") echo "c10f0e6f3e34b0fc4a9622057bfb7108f01ee90ff7eab7fd7a6c68ea5a09a8cf" ;;
    "hookaido_v2.2.0_darwin_arm64.tar.gz") echo "5ea0f3e3183ea0906ea236790ad153983ecf5d2515b27723fde4e318b5345a9b" ;;
    "hookaido_v2.2.0_linux_amd64.tar.gz") echo "f1edc566720cb6b04a15207be4e43a726615f3b7843beb876d385a730811272c" ;;
    "hookaido_v2.2.0_linux_arm64.tar.gz") echo "631b5b955e07fda43e066571cd54f788426dc031b4f5fff37da993e8feb5f050" ;;
    "hookaido_v2.2.0_windows_amd64.zip") echo "1adbcbf53af3cfaf10f050d4145c91a31faa3174dda5a3c9ed68a2a4bd7862a7" ;;
    "hookaido_v2.2.0_windows_arm64.zip") echo "f4682a27e1503a06f19dcb69a937bea284498ce3c77108fc92e65b40fb0feba1" ;;
    *)
      echo "No pinned checksum available for artifact: $1" >&2
      exit 1
      ;;
  esac
}

resolve_expected_sha() {
  local tag="$1"
  local artifact="$2"

  if [[ -n "${HOOKAIDO_SHA256:-}" ]]; then
    normalize_sha256 "${HOOKAIDO_SHA256}"
    return
  fi

  if [[ "$tag" == "$default_tag" ]]; then
    expected_sha_for_pinned_artifact "$artifact"
    return
  fi

  echo "No checksum available for ${artifact} (HOOKAIDO_VERSION=${tag})." >&2
  echo "Set HOOKAIDO_SHA256 to the expected checksum for this version." >&2
  exit 1
}

main() {
  local os arch tag ext artifact url tmpdir archive install_dir binary_name extracted_bin dest expected_sha actual_sha
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
  expected_sha="$(resolve_expected_sha "$tag" "$artifact")"

  tmpdir="$(mktemp -d)"
  trap 'if [[ -n "${tmpdir:-}" ]]; then rm -rf "$tmpdir"; fi' EXIT
  archive="${tmpdir}/${artifact}"

  echo "Downloading ${url}"
  curl --proto '=https' --tlsv1.2 -fL "$url" -o "$archive"

  actual_sha="$(normalize_sha256 "$(hash_file_sha256 "$archive")")"
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    echo "Checksum verification failed for ${artifact}." >&2
    echo "Expected: ${expected_sha}" >&2
    echo "Actual:   ${actual_sha}" >&2
    exit 1
  fi

  echo "Verified SHA256 for ${artifact}"

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

  if [[ "$os" == "windows" ]]; then
    install_dir="${HOOKAIDO_INSTALL_DIR:-$HOME/.openclaw/tools/hookaido}"
  else
    install_dir="${HOOKAIDO_INSTALL_DIR:-$HOME/.local/bin}"
  fi
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
