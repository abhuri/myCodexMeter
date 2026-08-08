#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
app_name="myCodex Meter"
source_bundle="${project_dir}/dist/${app_name}.app"
destination_bundle="/Applications/${app_name}.app"
destination_binary="${destination_bundle}/Contents/MacOS/CodexUsageMenu"

"${script_dir}/build-app.sh" release

if [[ ! -d "${source_bundle}" ]]; then
  echo "Build output not found: ${source_bundle}" >&2
  exit 1
fi

# Stop only running copies of this app so macOS opens the canonical bundle below.
for pid in $(/usr/bin/pgrep -x CodexUsageMenu 2>/dev/null || true); do
  command_path="$(/bin/ps -p "${pid}" -o command= 2>/dev/null || true)"
  if [[ "${command_path}" == *"/myCodex Meter.app/Contents/MacOS/CodexUsageMenu"* ]]; then
    /bin/kill "${pid}" 2>/dev/null || true
  fi
done

/usr/bin/ditto "${source_bundle}" "${destination_bundle}"
/usr/bin/codesign --verify --deep --strict "${destination_bundle}"

"${destination_binary}" --launch-at-login enable
/usr/bin/open "${destination_bundle}"

echo "Installed: ${destination_bundle}"
echo "Launch at Login: $("${destination_binary}" --launch-at-login status)"
