#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
configuration="${1:-release}"
app_name="myCodex Meter"
bundle_path="${project_dir}/dist/${app_name}.app"
contents_path="${bundle_path}/Contents"
binary_dir="${project_dir}/.build-app/${configuration}"
binary_path="${binary_dir}/CodexUsageMenu"
architecture="$(/usr/bin/uname -m)"

cd "${project_dir}"

compiler_flags=(
  -target "${architecture}-apple-macosx13.0"
  -framework AppKit
  -framework ServiceManagement
)

if [[ "${configuration}" == "release" ]]; then
  compiler_flags+=(-O)
else
  compiler_flags+=(-Onone -g)
fi

/bin/mkdir -p "${binary_dir}"
/usr/bin/xcrun swiftc \
  "${compiler_flags[@]}" \
  "${project_dir}"/Sources/CodexUsageMenu/*.swift \
  -o "${binary_path}"

/bin/mkdir -p "${contents_path}/MacOS" "${contents_path}/Resources"
/bin/cp "${binary_path}" "${contents_path}/MacOS/CodexUsageMenu"
/bin/cp "${project_dir}/Resources/Info.plist" "${contents_path}/Info.plist"

/usr/bin/codesign --force --deep --sign - "${bundle_path}"

echo "${bundle_path}"
