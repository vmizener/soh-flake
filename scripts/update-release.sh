#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_FILE="$REPO_ROOT/release-linux.nix"
CURRENT_VERSION=$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' "$RELEASE_FILE")

function ci_output() {
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "$1=$2" >> "$GITHUB_OUTPUT"
  fi
}

# shellcheck disable=SC2016,SC2288
function get_latest_version() {
  local -n _NAME=$1
  local -n _VERSION=$2
  local -n _URL=$3
  local ADDRESS="repos/HarbourMasters/Shipwright/releases/latest"
  local QUERY='
    first(.assets[] | select(.name | endswith("-Linux.zip"))) as $asset |
    {
      name: ($asset.name | sub("-Linux\\.zip$"; "")),
      version: .tag_name,
      url: $asset.browser_download_url
    }
  '
  local INFO
  if command -v gh &>/dev/null; then
    INFO=$(gh api "$ADDRESS" | jq -r "$QUERY")
  elif command -v , &>/dev/null; then
    INFO=$(, gh api "$ADDRESS" | jq -r "$QUERY")
  elif command -v curl &>/dev/null; then
    local AUTH_HEADERS=()
    [[ -n "${GH_TOKEN:-}" ]] && AUTH_HEADERS=(-H "Authorization: Bearer ${GH_TOKEN}")
    INFO=$(
      curl -sSL "${AUTH_HEADERS[@]}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/$ADDRESS" \
      | jq -r "$QUERY"
    )
  else
    echo "Failed to get remote version: neither gh, ',', nor curl found" >&2
    exit 1
  fi

  _NAME=$(echo "$INFO" | jq -r ".name")
  _VERSION=$(echo "$INFO" | jq -r ".version")
  _URL=$(echo "$INFO" | jq -r ".url")

  if [ -z "$_VERSION" ] || [ "$_VERSION" = "null" ] || [ -z "$_URL" ] || [ "$_URL" = "null" ]; then
    echo "Failed to find valid release version or Linux zip asset" >&2
    exit 1
  fi
}

NAME="" VERSION="" URL=""
get_latest_version NAME VERSION URL

if [ "$VERSION" = "$CURRENT_VERSION" ]; then
  echo "Repository is up-to-date (${CURRENT_VERSION})."
  ci_output "has_update" "false"
  exit 0
fi

echo "New release detected: $VERSION ($NAME)"
ci_output "has_update" "true"
ci_output "version" "$VERSION"
ci_output "name" "$NAME"

# Break early if `--check-only` is passed in
[[ "${1:-}" == "--check-only" ]] && exit 0

RAW_HASH=$(nix-prefetch-url --unpack --type sha256 "$URL")
SRI_HASH=$(nix hash convert --to sri "sha256:$RAW_HASH")

cat <<EOF > "$RELEASE_FILE"
{
  name = "$NAME";
  version = "$VERSION";
  hash = "$SRI_HASH";
}
EOF

nix fmt "$RELEASE_FILE"
echo "Updated $RELEASE_FILE to $VERSION ($NAME)."
