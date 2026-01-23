#!/bin/bash

set -euo pipefail
ENABLE_BUILD_VER=${ENABLE_BUILD_VER:-false}
# Function to display usage
usage() {
  printf "Usage: %s [major|minor|patch|pre-release] [pre-release-label (optional)]\n" "$0"
  exit 1
}

# Function to ensure script is run from the root of the project
ensure_project_root() {
  if [ ! -d .git ]; then
    printf "Error: Script must be run from the root of the project (where the .git directory is located).\n"
    exit 1
  fi
}

# Function to ensure VERSION file exists
ensure_version_file() {
  if [ ! -f VERSION ]; then
    printf "VERSION file not found. Creating one with initial version 0.1.0-alpha.1.\n"
    printf "0.1.0-alpha.1\n" > VERSION
  fi
}

# Function to parse the current version
parse_version() {
  current_version=$(cat VERSION)
  IFS='.' read -r major minor patch <<< "${current_version%%-*}"
  pre_release="${current_version#*-}"
  pre_release="${pre_release%%+*}"
}

# Function to bump the version
bump_version() {
  case "$1" in
    major)
      # Indicates that the version contains incompatible changes with the previous version
      major=$((major + 1))
      minor=0
      patch=0
      pre_release=""
      ;;
    minor)
      # Indicates that the version contains backward-compatible changes
      minor=$((minor + 1))
      patch=0
      pre_release=""
      ;;
    patch)
      # Indicates that the version is a bug fix release
      patch=$((patch + 1))
      pre_release=""
      ;;
    pre-release)
      # Indicates that the version is unstable and might not satisfy the intended compatibility requirements as denoted by its associated normal version
      if [[ "$pre_release" =~ ^[a-zA-Z]+ ]]; then
        pre_release="${2:-${pre_release%%.*}}.$(( ${pre_release##*.} + 1 ))"
      else
        pre_release="${2:-alpha}.1"
      fi
      ;;
    *)
      usage
      ;;
  esac
}

# Function to construct the new version
construct_new_version() {
  new_version="$major.$minor.$patch"
  if [ -n "$pre_release" ]; then
    new_version="$new_version-$pre_release"

    if [ "$ENABLE_BUILD_VER" = true ]; then
      short_commit_hash=$(git rev-parse --short HEAD)
      new_version="$new_version+build.$short_commit_hash"
    fi

  fi
}

# Function to update the VERSION file
update_version_file() {
  printf "%s\n" "$new_version" > VERSION
  printf "Updated VERSION file.\n"
}

# Helm chart version bump
helm_chart_version_bump() {
  new_version=${new_version:-$1}
  chart_dir=${chart_dir:-charts/gateway-api}
  printf "Bumping version in Helm chart %s to %s\n" "$chart_dir" "$new_version"
  sed -i "s/version: .*/version: $new_version/" "${chart_dir}/Chart.yaml"
}

# Function to commit and tag changes
commit_and_tag_changes() {
  git add VERSION
  git add charts/
  git commit -m "Bump version to $new_version"
  printf "Committed the version bump.\n"
  git tag -a "v$new_version" -m "Release v$new_version"
  # git push origin main --tags
  printf "Tagged and pushed version v%s.\n" "$new_version"
}

# Function to check Git state
check_git_state() {
  git fetch --prune
  if [ -n "$(git status --porcelain)" ]; then
    printf "Warning: Working directory is not clean. Ensure changes are committed.\n"
  fi
}

# Main script execution
main() {
  if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    usage
  fi

  ensure_project_root
  ensure_version_file
  parse_version

  printf "Current version: %s\n" "$current_version"

  bump_version "$1" "${2:-}"
  construct_new_version

  printf "New version: %s\n" "$new_version"

  update_version_file
  source scripts/helm-bump.sh "$new_version" "gateway-api"
  source scripts/helm-bump.sh "$new_version" "gateway-api-routes"
  source scripts/generate-docs.sh

  commit_and_tag_changes
  check_git_state

  printf "Version bump script completed successfully.\n"
}

main "$@"
