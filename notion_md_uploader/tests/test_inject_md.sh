#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$ROOT_DIR/notion_md_uploader/hooks/inject_md.sh"
FIXTURES_DIR="$ROOT_DIR/notion_md_uploader/tests/fixtures"

assert_eq() {
  local label="$1"
  local actual="$2"
  local expected="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $label" >&2
    echo "EXPECTED:" >&2
    printf '%s\n' "$expected" >&2
    echo "ACTUAL:" >&2
    printf '%s\n' "$actual" >&2
    exit 1
  fi

  echo "PASS: $label"
}

assert_empty() {
  local label="$1"
  local actual="$2"

  if [[ -n "$actual" ]]; then
    echo "FAIL: $label" >&2
    printf '%s\n' "$actual" >&2
    exit 1
  fi

  echo "PASS: $label"
}

extract_json() {
  local input_json="$1"
  local jq_filter="$2"
  printf '%s' "$input_json" | jq -r "$jq_filter"
}

CREATE_MAIN_PATH="$FIXTURES_DIR/create_main.md"
REPLACEMENT_PATH="$FIXTURES_DIR/replacement.md"
APPENDIX_PATH="$FIXTURES_DIR/appendix.md"

CREATE_MAIN_EXPECTED="$(<"$CREATE_MAIN_PATH")"
REPLACEMENT_EXPECTED="$(<"$REPLACEMENT_PATH")"
APPENDIX_EXPECTED="$(<"$APPENDIX_PATH")"

create_output="$(printf '{"tool_input":{"markdown":"%s","parent":{"page_id":"abc"}}}' "$CREATE_MAIN_PATH" | "$HOOK")"
assert_eq \
  "create-pages markdown injection" \
  "$(extract_json "$create_output" '.hookSpecificOutput.updatedInput.markdown')" \
  "$CREATE_MAIN_EXPECTED"

replace_output="$(printf '{"tool_input":{"type":"replace_content","replace_content":{"new_str_path":"%s"}}}' "$CREATE_MAIN_PATH" | "$HOOK")"
assert_eq \
  "replace-content new_str_path injection" \
  "$(extract_json "$replace_output" '.hookSpecificOutput.updatedInput.replace_content.new_str')" \
  "$CREATE_MAIN_EXPECTED"

update_output="$(printf '{"tool_input":{"type":"update_content","update_content":{"content_updates":[{"old_str":"OLD","new_str_path":"%s"}]}}}' "$REPLACEMENT_PATH" | "$HOOK")"
assert_eq \
  "nested update_content injection" \
  "$(extract_json "$update_output" '.hookSpecificOutput.updatedInput.update_content.content_updates[0].new_str')" \
  "$REPLACEMENT_EXPECTED"

top_level_update_output="$(printf '{"tool_input":{"content_updates":[{"old_str":"OLD","new_str_path":"%s"}]}}' "$REPLACEMENT_PATH" | "$HOOK")"
assert_eq \
  "top-level content_updates injection" \
  "$(extract_json "$top_level_update_output" '.hookSpecificOutput.updatedInput.content_updates[0].new_str')" \
  "$REPLACEMENT_EXPECTED"

append_output="$(printf '{"tool_input":{"type":"insert_content","insert_content":{"content_path":"%s"}}}' "$APPENDIX_PATH" | "$HOOK")"
assert_eq \
  "insert-content content_path injection" \
  "$(extract_json "$append_output" '.hookSpecificOutput.updatedInput.insert_content.content')" \
  "$APPENDIX_EXPECTED"

top_level_new_str_output="$(printf '{"tool_input":{"page_id":"page","new_str_path":"%s"}}' "$CREATE_MAIN_PATH" | "$HOOK")"
assert_eq \
  "top-level new_str_path injection" \
  "$(extract_json "$top_level_new_str_output" '.hookSpecificOutput.updatedInput.new_str')" \
  "$CREATE_MAIN_EXPECTED"

relative_path_output="$(printf '{"tool_input":{"markdown":"./relative/path.md"}}' | "$HOOK")"
assert_empty "relative path ignored" "$relative_path_output"

tmp_dir="$(mktemp -d /tmp/inject-md-test.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
large_file="$tmp_dir/large.md"

python3 - "$large_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
payload = "# Oversized\n\n" + ("x" * 530000)
path.write_text(payload, encoding="utf-8")
PY

oversized_output="$(printf '{"tool_input":{"markdown":"%s"}}' "$large_file" | "$HOOK" 2>/dev/null)"
assert_empty "oversized file skipped" "$oversized_output"

echo "All inject_md.sh regression tests passed."
