#!/usr/bin/env bash
# Generate static/index.html from README.md (single source of truth)
# Adds SEO meta tags; outputs HTML for gh-pages.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
README="$REPO_ROOT/README.md"
OUT="$REPO_ROOT/static/index.html"
mkdir -p "$(dirname "$OUT")"

# SEO head template
read -r -d '' SEO_HEAD << 'HEAD' || true
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Gateway API Helm Chart | Kubernetes Gateway API - Install from charts.cdnn.host</title>
  <meta name="description" content="Gateway API Helm Chart — Install Kubernetes Gateway API CRDs, GatewayClass, Gateway, HTTPRoute, GRPCRoute via Helm. Successor to Ingress. https://charts.cdnn.host/">
  <meta name="keywords" content="gateway api helm chart, gateway api, kubernetes, helm chart, helm, ingress, gateway, httproute, gatewayclass, envoy, aws alb, gke">
  <link rel="canonical" href="https://charts.cdnn.host/">
  <meta property="og:title" content="Gateway API Helm Chart | charts.cdnn.host">
  <meta property="og:description" content="Install Kubernetes Gateway API via Helm. gateway-api and gateway-api-routes charts.">
  <meta property="og:url" content="https://charts.cdnn.host/">
  <style>
    :root { --fg: #1f2328; --fg-muted: #656d76; --border: #d0d7de; --bg-code: #f6f8fa; --accent: #0969da; --bg: #ffffff; }
    @media (prefers-color-scheme: dark) { :root { --fg: #e6edf3; --fg-muted: #8b949e; --border: #30363d; --bg-code: #161b22; --accent: #58a6ff; --bg: #0d1117; } }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif; font-size: 16px; line-height: 1.6; color: var(--fg); background: var(--bg); max-width: 800px; margin: 0 auto; padding: 2rem 1.5rem; }
    a { color: var(--accent); text-decoration: none; }
    a:hover { text-decoration: underline; }
    h1 { font-size: 1.75rem; font-weight: 600; margin-bottom: 0.5rem; }
    h2 { font-size: 1.25rem; margin-top: 2rem; margin-bottom: 0.75rem; border-bottom: 1px solid var(--border); padding-bottom: 0.3rem; }
    h3 { font-size: 1.1rem; margin-top: 1.5rem; margin-bottom: 0.5rem; }
    p { margin: 0.75rem 0; }
    ul, ol { margin: 0.75rem 0; padding-left: 1.5rem; }
    li { margin: 0.25rem 0; }
    table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
    th, td { border: 1px solid var(--border); padding: 0.5rem 0.75rem; text-align: left; }
    th { background: var(--bg-code); font-weight: 600; }
    code { background: var(--bg-code); padding: 0.2em 0.4em; border-radius: 6px; font-size: 0.9em; }
    pre { background: var(--bg-code); padding: 1rem; overflow-x: auto; border-radius: 8px; border: 1px solid var(--border); font-size: 0.875rem; }
    pre code { background: none; padding: 0; }
    img { max-width: 100%; }
    hr { border: none; border-top: 1px solid var(--border); margin: 2rem 0; }
    .badges { margin: 0.5rem 0; }
    .badges img { vertical-align: middle; margin-right: 0.5rem; }
    blockquote { margin: 1rem 0; padding-left: 1rem; border-left: 4px solid var(--border); color: var(--fg-muted); }
  </style>
</head>
<body>
HEAD

# Convert markdown to HTML body (try pandoc, then npx marked)
convert_md() {
  if command -v pandoc &>/dev/null; then
    pandoc "$README" -f gfm -t html 2>/dev/null
  elif command -v npx &>/dev/null; then
    npx --yes marked --gfm < "$README" 2>/dev/null
  elif python3 -c "import markdown" 2>/dev/null; then
    python3 -c "import markdown; print(markdown.markdown(open(\"$README\").read(), extensions=['tables', 'fenced_code']))"
  else
    echo "Error: need pandoc, npx/marked, or python-markdown. Install: brew install pandoc | npm i -g marked | pip install markdown" >&2
    exit 1
  fi
}

# Write output
{
  echo "$SEO_HEAD"
  convert_md
  echo '</body>'
  echo '</html>'
} > "$OUT"

echo "Generated $OUT from $README"
