#!/usr/bin/env bash
# Publish pages and sites to launchly from a terminal.
#
#   launchly.sh connect [name]                 connect this machine (link and code)
#   launchly.sh publish <dir|file.html> [--name "Name"] [--site <slug>] [--message "note"]
#   launchly.sh sites                          list the workspace's sites
#
# Needs curl and python3 (to read JSON); publishing a folder also needs zip.
# The API key is read from LAUNCHLY_API_KEY, or from the file `connect` writes.
set -euo pipefail

BASE_URL="${LAUNCHLY_URL:-https://app.launchly.ai}"
KEY_FILE="${LAUNCHLY_KEY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/launchly/key}"

die() {
	echo "launchly: $*" >&2
	exit 1
}

need() {
	command -v "$1" >/dev/null 2>&1 || die "this needs \`$1\`, which is not installed"
}

# json <field.path> reads one value from the JSON on stdin; empty when missing.
json() {
	python3 -c '
import json, sys
value = json.load(sys.stdin)
for part in sys.argv[1].split("."):
    value = value.get(part) if isinstance(value, dict) else None
print("" if value is None else value)
' "$1" 2>/dev/null || true
}

# json_body key=value ... builds a JSON object from string pairs.
json_body() {
	python3 -c '
import json, sys
print(json.dumps(dict(pair.split("=", 1) for pair in sys.argv[1:])))
' "$@"
}

api_key() {
	if [ -n "${LAUNCHLY_API_KEY:-}" ]; then
		printf '%s' "$LAUNCHLY_API_KEY"
	elif [ -f "$KEY_FILE" ]; then
		cat "$KEY_FILE"
	else
		die "not connected. Run \`$0 connect\` first, or set LAUNCHLY_API_KEY"
	fi
}

# api <method> <path> [json body] calls the REST API and prints the answer.
api() {
	local method="$1" path="$2" body="${3:-}" response status key
	# On its own line, so that a missing key stops the script here.
	key="$(api_key)" || exit 1
	local args=(-sS -X "$method" -H "Authorization: Bearer $key" -w '\n%{http_code}')

	if [ -n "$body" ]; then
		args+=(-H 'Content-Type: application/json' -d "$body")
	fi

	response="$(curl "${args[@]}" "$BASE_URL/api/v1$path")"
	status="${response##*$'\n'}"
	response="${response%$'\n'*}"

	if [ "$status" -ge 400 ]; then
		die "$method $path failed ($status): $(printf '%s' "$response" | json message)"
	fi

	printf '%s' "$response"
}

connect() {
	local name="${1:-$(hostname 2>/dev/null || echo terminal)}" started device_code interval answer error key

	need curl
	need python3

	started="$(curl -sS -X POST "$BASE_URL/api/agent/connect" \
		-H 'Content-Type: application/json' -d "$(json_body "client_name=$name")")"
	device_code="$(printf '%s' "$started" | json device_code)"
	[ -n "$device_code" ] || die "could not start: $started"
	interval="$(printf '%s' "$started" | json interval)"

	echo "Open $(printf '%s' "$started" | json verification_uri_complete)"
	echo "and check that it shows the code $(printf '%s' "$started" | json user_code)"
	echo "Waiting for you to approve (up to 10 minutes)..."

	while true; do
		sleep "${interval:-5}"
		answer="$(curl -sS -X POST "$BASE_URL/api/agent/connect/token" \
			-H 'Content-Type: application/json' -d "$(json_body "device_code=$device_code")")"
		key="$(printf '%s' "$answer" | json api_key)"

		if [ -n "$key" ]; then
			mkdir -p "$(dirname "$KEY_FILE")"
			(umask 077 && printf '%s' "$key" >"$KEY_FILE")
			echo "Connected to the workspace \"$(printf '%s' "$answer" | json workspace.name)\"."
			echo "The key is saved in $KEY_FILE"
			return
		fi

		error="$(printf '%s' "$answer" | json error)"
		case "$error" in
		authorization_pending) ;;
		slow_down) sleep 5 ;;
		access_denied) die "you declined the request" ;;
		expired_token) die "the code ran out. Run \`$0 connect\` again" ;;
		*) die "could not connect: $answer" ;;
		esac
	done
}

publish() {
	local source="" name="" site="" message="" created snapshot upload_url content_type result

	while [ $# -gt 0 ]; do
		case "$1" in
		--name) name="$2"; shift 2 ;;
		--site) site="$2"; shift 2 ;;
		--message) message="$2"; shift 2 ;;
		-*) die "unknown option $1" ;;
		*) source="$1"; shift ;;
		esac
	done

	need curl
	need python3
	need zip
	[ -n "$source" ] || die "say what to publish: a folder with an index.html, or one .html file"
	[ -e "$source" ] || die "$source does not exist"

	# Not local: the cleanup runs when the script exits, after this function has returned.
	work="$(mktemp -d)"
	trap 'rm -rf "${work:-}"' EXIT

	# One zip either way: a single page becomes index.html.
	if [ -d "$source" ]; then
		[ -f "$source/index.html" ] || die "$source has no index.html. Build first; launchly does not run builds"
		(cd "$source" && zip -qr "$work/site.zip" . -x '.git/*' -x 'node_modules/*' -x '.DS_Store')
	else
		cp "$source" "$work/index.html"
		(cd "$work" && zip -q site.zip index.html)
	fi

	if [ -z "$site" ]; then
		[ -n "$name" ] || name="$(basename "$(cd "$(dirname "$source")" && pwd)/$(basename "$source")" .html)"
		created="$(api POST /sites "$(json_body "name=$name")")"
		site="$(printf '%s' "$created" | json slug)"
	fi

	snapshot="$(api POST "/sites/$site/snapshots" "$(if [ -n "$message" ]; then json_body "message=$message"; else echo '{}'; fi)")"
	upload_url="$(printf '%s' "$snapshot" | json upload.url)"
	content_type="$(printf '%s' "$snapshot" | python3 -c 'import json,sys; print(json.load(sys.stdin)["upload"]["headers"]["Content-Type"])')"
	[ -n "$upload_url" ] || die "no upload address in the answer: $snapshot"

	curl -sS -f -X PUT -H "Content-Type: $content_type" --data-binary "@$work/site.zip" "$upload_url" >/dev/null ||
		die "the upload failed"

	api POST "/sites/$site/snapshots/$(printf '%s' "$snapshot" | json snapshot.id)/finalize" '{}' >/dev/null
	result="$(api GET "/sites/$site")"

	echo "Published: $(printf '%s' "$result" | json url)"
	echo "Site: $site"
	echo "Who can open it: $(printf '%s' "$result" | json access.description)"
}

case "${1:-}" in
connect) shift; connect "$@" ;;
publish) shift; publish "$@" ;;
sites) api GET /sites ;;
*) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
