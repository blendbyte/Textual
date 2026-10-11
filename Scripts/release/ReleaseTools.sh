#!/bin/bash

# Sourced by the release scripts. release_python prints the path of a Python
# with the packages in Scripts/release/requirements.txt, set up once per Mac
# in ~/Library/Caches/Textual Release from pinned, checksum-verified
# downloads: python-build-standalone (the same build as Development/dev's VM
# bundle; keep the two in step) and the packages' wheels.

RELEASE_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_CACHE="${HOME}/Library/Caches/Textual Release"

PYTHON_RELEASE="20261003"
PYTHON_VERSION="3.13.16"
PYTHON_SHA256_ARM64="d8975d7df4f08f7b1c7aafcdfacbddcec3d366415f2c1a72b2466b6850815933"
PYTHON_SHA256_X86_64="8e9cb087305bfb8969f68a905f79f41469d4aa5220c1aa71ada7fc9953bdba0f"

release_python() {
	local requirements="${RELEASE_TOOLS_DIR}/requirements.txt"
	local stamp
	stamp="${PYTHON_VERSION}-$(shasum -a 256 "${requirements}" | cut -c1-12)"

	local environment="${RELEASE_CACHE}/python-${stamp}"

	if [ ! -x "${environment}/bin/python3" ]; then
		local arch sha

		case "$(uname -m)" in
			arm64) arch="aarch64"; sha="${PYTHON_SHA256_ARM64}" ;;
			*) arch="x86_64"; sha="${PYTHON_SHA256_X86_64}" ;;
		esac

		local name="cpython-${PYTHON_VERSION}+${PYTHON_RELEASE}-${arch}-apple-darwin-install_only.tar.gz"
		local archive="${RELEASE_CACHE}/${name}"

		mkdir -p "${RELEASE_CACHE}"

		if [ ! -f "${archive}" ]; then
			echo "Downloading Python ${PYTHON_VERSION} for the release tools…" >&2

			curl -fsSL -o "${archive}.partial" "https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_RELEASE}/${name//+/%2B}" >&2

			echo "${sha}  ${archive}.partial" | shasum -a 256 -c --quiet - >&2 || { rm -f "${archive}.partial"; echo "error: Python checksum mismatch" >&2; return 1; }

			mv "${archive}.partial" "${archive}"
		fi

		rm -rf "${environment}.partial"
		mkdir -p "${environment}.partial"

		tar -xzf "${archive}" -C "${environment}.partial" --strip-components 1

		"${environment}.partial/bin/python3" -m pip install --quiet --disable-pip-version-check --no-input \
			--require-hashes --only-binary :all: --no-deps -r "${requirements}" >&2 || { echo "error: installing the release tools' Python packages failed" >&2; return 1; }

		rm -rf "${environment}"
		mv "${environment}.partial" "${environment}"
	fi

	printf '%s' "${environment}/bin/python3"
}
