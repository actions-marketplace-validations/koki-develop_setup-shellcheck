#!/usr/bin/env bash
set -euo pipefail

repo="koalaman/shellcheck"

curl_args=(-sSL)
if [ -n "${GITHUB_TOKEN:-}" ]; then
  curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

# --- Version Resolution ---

# Strip v prefix if present (from user input like "v0.11.0").
version="${INPUT_VERSION#v}"

if [ "${version}" = "latest" ]; then
  api_url="https://api.github.com/repos/${repo}/releases/latest"
else
  api_url="https://api.github.com/repos/${repo}/releases/tags/v${version}"
fi

release_json=$(curl "${curl_args[@]}" "${api_url}") || {
  echo "::error::Failed to fetch release info from GitHub API"
  exit 1
}

tag=$(echo "${release_json}" | jq -r '.tag_name')
if [ -z "${tag}" ] || [ "${tag}" = "null" ]; then
  echo "::error::ShellCheck version '${INPUT_VERSION}' was not found"
  exit 1
fi
version="${tag#v}"

echo "Installing ShellCheck v${version}..."

# --- Platform Detection ---

case "${RUNNER_OS}" in
  Linux)   os="linux" ;;
  macOS)   os="darwin" ;;
  Windows) os="windows" ;;
  *)
    echo "::error::Unsupported OS: ${RUNNER_OS}"
    exit 1
    ;;
esac

case "${RUNNER_ARCH}" in
  X64)   arch="x86_64" ;;
  ARM64) arch="aarch64" ;;
  *)
    echo "::error::Unsupported architecture: ${RUNNER_ARCH}"
    exit 1
    ;;
esac

# ShellCheck ships a single x86_64 zip for Windows and per-arch tar.xz archives
# for Linux/macOS.
if [ "${os}" = "windows" ]; then
  archive_name="shellcheck-v${version}.zip"
  ext="zip"
else
  archive_name="shellcheck-v${version}.${os}.${arch}.tar.xz"
  ext="tar.xz"
fi

# --- Download ---

base_url="https://github.com/${repo}/releases/download/v${version}"
install_dir="${RUNNER_TEMP}/shellcheck"
mkdir -p "${install_dir}"

echo "Downloading ${archive_name}..."
http_code=$(curl "${curl_args[@]}" -w "%{http_code}" -o "${install_dir}/${archive_name}" "${base_url}/${archive_name}")
if [ "${http_code}" -ne 200 ]; then
  if [ "${http_code}" -eq 404 ]; then
    echo "::error::ShellCheck v${version} is not available for ${RUNNER_OS}/${RUNNER_ARCH}"
  else
    echo "::error::Failed to download ${base_url}/${archive_name} (HTTP ${http_code})"
  fi
  exit 1
fi

# --- Checksum Verification ---

# The GitHub API exposes a per-asset digest (sha256:...) for recent releases.
# Older releases return null; in that case we skip verification.
expected_hash=$(echo "${release_json}" | jq -r --arg name "${archive_name}" '.assets[] | select(.name == $name) | .digest // empty')
expected_hash="${expected_hash#sha256:}"

if [ -n "${expected_hash}" ]; then
  if command -v sha256sum &> /dev/null; then
    actual_hash=$(sha256sum "${install_dir}/${archive_name}" | awk '{print $1}')
  elif command -v shasum &> /dev/null; then
    actual_hash=$(shasum -a 256 "${install_dir}/${archive_name}" | awk '{print $1}')
  else
    echo "::error::Neither sha256sum nor shasum is available"
    exit 1
  fi

  if [ "${actual_hash}" != "${expected_hash}" ]; then
    echo "::error::Checksum verification failed for ${archive_name}"
    echo "::error::Expected: ${expected_hash}"
    echo "::error::Actual:   ${actual_hash}"
    exit 1
  fi

  echo "Checksum verified."
else
  echo "::warning::No checksum available for ${archive_name}; skipping verification"
fi

# --- Extract and Add to PATH ---

echo "Extracting ${archive_name}..."
if [ "${ext}" = "zip" ]; then
  unzip -q "${install_dir}/${archive_name}" -d "${install_dir}" || {
    echo "::error::Failed to extract ${archive_name}"
    exit 1
  }
  # The zip contains shellcheck.exe at the archive root.
  bin_dir="${install_dir}"
else
  tar xJf "${install_dir}/${archive_name}" -C "${install_dir}" || {
    echo "::error::Failed to extract ${archive_name}"
    exit 1
  }
  # The tarball extracts to a shellcheck-v${version}/ directory containing the binary.
  bin_dir="${install_dir}/shellcheck-v${version}"
fi

echo "${bin_dir}" >> "${GITHUB_PATH}"

echo "ShellCheck v${version} installed successfully."
