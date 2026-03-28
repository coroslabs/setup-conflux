#!/usr/bin/env bash
set -euo pipefail

# Conflux shell installer — downloads, verifies, and installs the conflux CLI.
# Requires GITHUB_TOKEN with contents:read on coroslabs/conflux.

REPO="coroslabs/conflux"
API_BASE="https://api.github.com"
VERSION="${CONFLUX_VERSION:-latest}"
INSTALL_DIR="${CONFLUX_INSTALL_DIR:-$HOME/.local/bin}"

# --- Validation ---

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Error: GITHUB_TOKEN is required."
  echo ""
  echo "Create a fine-grained PAT with contents:read on coroslabs/conflux:"
  echo "  https://github.com/settings/personal-access-tokens/new"
  echo ""
  echo "Usage:"
  echo "  GITHUB_TOKEN=ghp_xxx curl -fsSL <installer-url> | sh"
  exit 1
fi

# --- Platform detection ---

detect_platform() {
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)

  case "$OS" in
    linux)  OS_NAME="linux" ;;
    darwin) OS_NAME="darwin" ;;
    *)
      echo "Error: Unsupported operating system: $OS"
      echo "The shell installer supports macOS and Linux."
      echo "For Windows, use 'go install' or download directly from GitHub Releases."
      exit 1
      ;;
  esac

  case "$ARCH" in
    x86_64|amd64)  ARCH_NAME="amd64" ;;
    aarch64|arm64) ARCH_NAME="arm64" ;;
    *)
      echo "Error: Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac
}

# --- Version resolution ---

resolve_version() {
  if [ "$VERSION" = "latest" ]; then
    VERSION=$(curl -fsSL \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "${API_BASE}/repos/${REPO}/releases/latest" | \
      grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

    if [ -z "$VERSION" ]; then
      echo "Error: Failed to resolve latest version."
      echo "Check that your GITHUB_TOKEN has contents:read on ${REPO}."
      exit 1
    fi
  fi
  echo "Installing conflux ${VERSION}..."
}

# --- Download and verify ---

download_and_verify() {
  ARCHIVE="conflux_${VERSION#v}_${OS_NAME}_${ARCH_NAME}.tar.gz"
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' EXIT

  # Fetch release metadata once
  RELEASE_JSON=$(curl -fsSL \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "${API_BASE}/repos/${REPO}/releases/tags/${VERSION}")

  # Get asset IDs (private repos require the asset API endpoint, not browser_download_url)
  ARCHIVE_ASSET_ID=$(echo "$RELEASE_JSON" | \
    grep -B3 "\"name\": *\"${ARCHIVE}\"" | \
    grep '"id"' | head -1 | sed 's/[^0-9]//g')

  CHECKSUMS_ASSET_ID=$(echo "$RELEASE_JSON" | \
    grep -B3 '"name": *"checksums.txt"' | \
    grep '"id"' | head -1 | sed 's/[^0-9]//g')

  if [ -z "$ARCHIVE_ASSET_ID" ]; then
    echo "Error: Could not find asset ${ARCHIVE} in release ${VERSION}."
    exit 1
  fi

  if [ -z "$CHECKSUMS_ASSET_ID" ]; then
    echo "Error: Could not find checksums.txt in release ${VERSION}."
    exit 1
  fi

  # Download archive via asset API
  echo "Downloading ${ARCHIVE}..."
  curl -fsSL \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/octet-stream" \
    -o "${TMPDIR}/${ARCHIVE}" \
    "${API_BASE}/repos/${REPO}/releases/assets/${ARCHIVE_ASSET_ID}"

  # Download checksums via asset API
  curl -fsSL \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/octet-stream" \
    -o "${TMPDIR}/checksums.txt" \
    "${API_BASE}/repos/${REPO}/releases/assets/${CHECKSUMS_ASSET_ID}"

  # Verify checksum
  EXPECTED=$(grep "$ARCHIVE" "${TMPDIR}/checksums.txt" | awk '{print $1}')
  if [ -z "$EXPECTED" ]; then
    echo "Error: ${ARCHIVE} not found in checksums.txt"
    exit 1
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL=$(sha256sum "${TMPDIR}/${ARCHIVE}" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    ACTUAL=$(shasum -a 256 "${TMPDIR}/${ARCHIVE}" | awk '{print $1}')
  else
    echo "Error: Neither sha256sum nor shasum found. Cannot verify checksum."
    exit 1
  fi

  if [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "Error: Checksum verification failed!"
    echo "  Expected: ${EXPECTED}"
    echo "  Got:      ${ACTUAL}"
    exit 1
  fi

  echo "Checksum verified."

  # Extract
  mkdir -p "$INSTALL_DIR"
  tar -xzf "${TMPDIR}/${ARCHIVE}" -C "$INSTALL_DIR" conflux
  chmod +x "${INSTALL_DIR}/conflux"
}

# --- Post-install ---

post_install() {
  echo ""
  echo "Conflux ${VERSION} installed to ${INSTALL_DIR}/conflux"

  case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
      echo ""
      echo "Add ${INSTALL_DIR} to your PATH:"
      echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
      echo ""
      echo "To make this permanent, add the line above to your shell profile:"
      echo "  ~/.bashrc, ~/.zshrc, or ~/.profile"
      ;;
  esac

  echo ""
  echo "Verify installation:"
  echo "  conflux version"
}

# --- Main ---

detect_platform
resolve_version
download_and_verify
post_install
