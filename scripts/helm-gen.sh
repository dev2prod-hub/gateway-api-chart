#!/usr/bin/env bash
####
# Run it for the root repo directory
####
# This script is used to generate the helm chart for the given helm chart directory
# and validate the generated manifest using the kubectl-validate command
# https://github.com/kubernetes-sigs/kubectl-validate
####
set -eo pipefail

K8S_VALIDATE_ENABLED="${K8S_VALIDATE_ENABLED:-false}"
# Function to check if the kubectl-validate and HELM command is installed
function check_dependencies() {
  # Alternative is: https://github.com/yannh/kubeconform
  if [ "$K8S_VALIDATE_ENABLED" != "true" ]; then
    echo "Skipping kubectl-validate as K8S_VALIDATE_ENABLED is not set to true"
    else
    if ! command -v kubectl-validate &> /dev/null; then
      echo "kubectl-validate could not be found. Please install it using the following command:"
      echo "go install sigs.k8s.io/kubectl-validate@latest"
      exit 1
    fi
  fi

  if ! command -v helm &> /dev/null; then
    echo "helm could not be found. Please install it using the following command:"
    echo "brew install helm"
    exit 1
  fi
}
check_dependencies

ns="${namespace:-demo}"
env="${env:-dev}"
PROJ_DIR="${PROJ_DIR:-$(pwd)}"
HELM_DIR="${HELM_DIR:-charts}"
####
# Change me
HELM_CHART_NAME="${HELM_CHART_NAME:-"gateway-api"}"
####

HELM_CHART="${PROJ_DIR}/${HELM_DIR}/${HELM_CHART_NAME}"
OUT_DIR="$PROJ_DIR/tmp/_helm-gen"
env="${env:-dev}"

mkdir -p "$OUT_DIR"
rm -rf "${OUT_DIR:?}/"*
printf "Generating helm chart for %s...\nENV: %s\n" "$HELM_CHART_NAME" "$env"

extra_values="$HELM_CHART/${env}-values.yaml"
VALUES=""
if [[ -f ${extra_values} ]]; then
  VALUES="--values=${extra_values}"
  printf "Extra Values has been added: %s\n###\n\n" "$extra_values"
else
  printf "Extra Values did not found: %s\n###\n" "$extra_values"
fi

helm template "$HELM_CHART" \
  --create-namespace \
  --namespace "$ns" \
  --debug \
  --output-dir "${OUT_DIR}" ${VALUES}

printf "\n####\nHelm chart generated successfully\nDIR: %s\n####\n" "$OUT_DIR"

if [ "$K8S_VALIDATE_ENABLED" == "true" ]; then
  printf "\n####\nValidating the generated manifest\n####\n"
  kubectl-validate "${OUT_DIR}/"
fi
