#!/usr/bin/env bash
set -Eeuo pipefail

error() {
  echo "::error::$*" >&2
}

warn() {
  echo "::warning::$*" >&2
}

mask_secret() {
  local value="${1:-}"
  if [[ -n "$value" ]]; then
    echo "::add-mask::$value"
  fi
}

require_non_empty() {
  local name="$1"
  local value="$2"

  if [[ -z "$value" ]]; then
    error "Input '$name' is required."
    exit 1
  fi
}

normalize_bool() {
  local name="$1"
  local value="${2:-}"
  local lower
  lower="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"

  case "$lower" in
    true|1|yes|y|on) printf 'true' ;;
    false|0|no|n|off|"") printf 'false' ;;
    *)
      error "Input '$name' must be a boolean value: true or false. Got: $value"
      exit 1
      ;;
  esac
}

require_non_negative_int() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    error "Input '$name' must be a non-negative integer. Got: $value"
    exit 1
  fi
}

require_positive_int() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    error "Input '$name' must be a positive integer. Got: $value"
    exit 1
  fi
}

truncate_text() {
  local text="$1"
  local max_chars="$2"

  if (( max_chars > 0 && ${#text} > max_chars )); then
    if (( max_chars == 1 )); then
      printf '…'
    else
      printf '%s…' "${text:0:max_chars-1}"
    fi
  else
    printf '%s' "$text"
  fi
}

redact() {
  local text="$1"
  local token="${INPUT_BOT_TOKEN:-}"

  if [[ -n "$token" ]]; then
    text="${text//$token/[REDACTED_TELEGRAM_BOT_TOKEN]}"
  fi

  printf '%s' "$text"
}

build_default_message() {
  local repo="${GITHUB_REPOSITORY_NAME:-${GITHUB_REPOSITORY:-unknown/repository}}"
  local server_url="${GITHUB_SERVER_URL_VALUE:-${GITHUB_SERVER_URL:-https://github.com}}"
  local title="${INPUT_RELEASE_TITLE:-${EVENT_RELEASE_TITLE:-}}"
  local tag="${INPUT_RELEASE_TAG:-${EVENT_RELEASE_TAG:-${GITHUB_REF_NAME_VALUE:-${GITHUB_REF_NAME:-}}}}"
  local url="${INPUT_RELEASE_URL:-${EVENT_RELEASE_URL:-}}"
  local body="${INPUT_RELEASE_BODY:-${EVENT_RELEASE_BODY:-}}"
  local actor="${EVENT_RELEASE_AUTHOR:-${GITHUB_ACTOR_VALUE:-${GITHUB_ACTOR:-}}}"

  if [[ -z "$title" ]]; then
    title="${tag:-release}"
  fi

  if [[ -z "$url" && -n "$tag" && "$repo" != "unknown/repository" ]]; then
    url="${server_url}/${repo}/releases/tag/${tag}"
  fi

  local message
  message="🚀 New release: ${title}
Repository: ${repo}"

  if [[ -n "$tag" ]]; then
    message+=$'\n'"Tag: ${tag}"
  fi

  if [[ -n "$actor" ]]; then
    message+=$'\n'"Author: ${actor}"
  fi

  if [[ -n "$url" ]]; then
    message+=$'\n'"${url}"
  fi

  if [[ "$include_release_body" == "true" && "$max_body_chars" -gt 0 && -n "$body" ]]; then
    body="$(truncate_text "$body" "$max_body_chars")"
    message+=$'\n\n'"${body}"
  fi

  printf '%s' "$message"
}

mask_secret "${INPUT_BOT_TOKEN:-}"

require_non_empty "bot-token" "${INPUT_BOT_TOKEN:-}"
require_non_empty "chat-id" "${INPUT_CHAT_ID:-}"

if ! command -v curl >/dev/null 2>&1; then
  error "curl is required but was not found on PATH."
  exit 1
fi

if [[ -n "${INPUT_MESSAGE_THREAD_ID:-}" && ! "${INPUT_MESSAGE_THREAD_ID}" =~ ^[0-9]+$ ]]; then
  error "Input 'message-thread-id' must be an integer when provided."
  exit 1
fi

require_non_negative_int "max-body-chars" "${INPUT_MAX_BODY_CHARS:-1200}"
require_positive_int "max-message-chars" "${INPUT_MAX_MESSAGE_CHARS:-3900}"

include_release_body="$(normalize_bool "include-release-body" "${INPUT_INCLUDE_RELEASE_BODY:-true}")"
disable_notification="$(normalize_bool "disable-notification" "${INPUT_DISABLE_NOTIFICATION:-false}")"
disable_link_preview="$(normalize_bool "disable-link-preview" "${INPUT_DISABLE_LINK_PREVIEW:-false}")"
protect_content="$(normalize_bool "protect-content" "${INPUT_PROTECT_CONTENT:-false}")"
max_body_chars="${INPUT_MAX_BODY_CHARS:-1200}"
max_message_chars="${INPUT_MAX_MESSAGE_CHARS:-3900}"

if (( max_message_chars > 4096 )); then
  warn "Input 'max-message-chars' is greater than Telegram's 4096 character limit. Using 4096."
  max_message_chars=4096
fi

if [[ -n "${INPUT_TEXT:-}" ]]; then
  text="$INPUT_TEXT"
else
  text="$(build_default_message)"
fi

text="$(truncate_text "$text" "$max_message_chars")"

if [[ -z "$text" ]]; then
  error "Message text is empty after applying inputs."
  exit 1
fi

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

api_url="https://api.telegram.org/bot${INPUT_BOT_TOKEN}/sendMessage"

curl_args=(
  --silent
  --show-error
  --request POST
  --output "$response_file"
  --write-out "%{http_code}"
  --data-urlencode "chat_id=${INPUT_CHAT_ID}"
  --data-urlencode "text=${text}"
  --data-urlencode "disable_notification=${disable_notification}"
  --data-urlencode "protect_content=${protect_content}"
)

if [[ -n "${INPUT_MESSAGE_THREAD_ID:-}" ]]; then
  curl_args+=(--data-urlencode "message_thread_id=${INPUT_MESSAGE_THREAD_ID}")
fi

if [[ -n "${INPUT_PARSE_MODE:-}" ]]; then
  curl_args+=(--data-urlencode "parse_mode=${INPUT_PARSE_MODE}")
fi

if [[ "$disable_link_preview" == "true" ]]; then
  curl_args+=(--data-urlencode 'link_preview_options={"is_disabled":true}')
fi

http_status="$(curl "${curl_args[@]}" "$api_url" || true)"
response_body="$(cat "$response_file" 2>/dev/null || true)"

if [[ ! "$http_status" =~ ^[0-9][0-9][0-9]$ ]]; then
  error "Telegram API request failed before receiving a valid HTTP status. curl output: $(redact "$http_status")"
  exit 1
fi

if [[ ! "$http_status" =~ ^2[0-9][0-9]$ ]]; then
  error "Telegram API request failed with HTTP $http_status. Response: $(redact "$response_body")"
  exit 1
fi

if ! grep -q '"ok"[[:space:]]*:[[:space:]]*true' "$response_file"; then
  error "Telegram API response did not contain ok=true. Response: $(redact "$response_body")"
  exit 1
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "sent=true"
    echo "http-status=$http_status"
  } >> "$GITHUB_OUTPUT"
fi

echo "Telegram notification sent."
