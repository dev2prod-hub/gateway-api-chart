#!/bin/bash
new_version=${1:-$(cat VERSION)}
chart_name=${2:-"gateway-api-routes"}

old_version=$(grep "version:" "charts/${chart_name}/Chart.yaml" | awk '{print $2}')
printf "Bumping the version of the Helm \"%s\" from %s => %s\n" "$chart_name" "$old_version" "$new_version"
sed -i "s/version: .*/version: $new_version/" "charts/${chart_name}/Chart.yaml"
