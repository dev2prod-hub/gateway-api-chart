#!/bin/bash
# Set the chart `version:` in one Chart.yaml. Bumps the CHART version only --
# `appVersion` tracks the vendored Gateway API bundle and is set by update-crds.sh.
new_version=${1:-$(cat VERSION)}
chart_name=${2:-"gateway-api-routes"}
chart_file="charts/${chart_name}/Chart.yaml"

old_version=$(grep -m1 '^version:' "$chart_file" | awk '{print $2}')
printf "Bumping the version of the Helm \"%s\" from %s => %s\n" "$chart_name" "$old_version" "$new_version"

# Anchored at ^version: so appVersion/apiVersion/kubeVersion cannot be clobbered,
# and no `sed -i` -- its syntax differs between GNU and BSD/macOS sed.
tmp=$(mktemp)
sed "s|^version:.*|version: ${new_version}|" "$chart_file" > "$tmp" && mv "$tmp" "$chart_file"
