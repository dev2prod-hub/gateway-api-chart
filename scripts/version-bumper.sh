#!/bin/bash
new_version=$1
sed -i "s/version: .*/version: $new_version/" charts/gateway-api/Chart.yaml
