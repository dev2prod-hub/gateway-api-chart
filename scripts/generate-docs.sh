#!/bin/bash
# Generate README.md for each chart using README.md.gotmpl templates
# The templates preserve custom sections like "Chart Purpose"
helm-docs -c ./charts
