#!/usr/bin/env bash
set -euo pipefail

repo="nuetzliches/hookaido"
default_tag="v2.15.1"

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
    "hookaido_v2.15.1_darwin_amd64.tar.gz") echo "767f514461465211240f43345c5cc8ca9be4713b3fb1e37afdf77ed722bec72c" ;;
    "hookaido_v2.15.1_darwin_arm64.tar.gz") echo "45b51d7449d01246fce6baab1e18e7e38854860d9e81a52106460b33d8a23225" ;;
    "hookaido_v2.15.1_linux_amd64.tar.gz") echo "ab021b5edae52c46a74e841b7f9801854620781a83bbdc188afc563a097b7cfe" ;;
    "hookaido_v2.15.1_linux_arm64.tar.gz") echo "17cc0488a8da240f313d9e4c6400e83812db519ec1f6b27ab3296cefa7894046" ;;
    "hookaido_v2.15.1_windows_amd64.zip") echo "58b6b2422b8acd6a9a0d47f261999aea4ad4285624918afcd151225213ca2d88" ;;
    "hookaido_v2.15.1_windows_arm64.zip") echo "ec830085a26d74c370aff819482bdc2f3bbc9a319ef8e9c5bd3f5d400f403558" ;;
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
