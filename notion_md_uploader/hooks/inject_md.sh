#!/bin/bash
INPUT=$(cat)
MAX_FILE_BYTES=524288

warn() {
  echo "WARNING: inject_md.sh — $1" >&2
}

is_abs_md_file() {
  local path="$1"
  [[ "$path" == /* ]] && [[ "$path" == *.md ]] && [ -f "$path" ]
}

check_size() {
  local path="$1"
  local file_size

  file_size=$(wc -c < "$path")
  if [ "$file_size" -gt "$MAX_FILE_BYTES" ]; then
    warn "file size ${file_size} bytes exceeds 512KB: $path"
    return 1
  fi

  return 0
}

inject_file() {
  local json="$1"
  local path="$2"
  local filter="$3"
  local updated

  if ! is_abs_md_file "$path"; then
    printf '%s' "$json"
    return 1
  fi

  if ! check_size "$path"; then
    printf '%s' "$json"
    return 1
  fi

  updated=$(printf '%s' "$json" | jq --rawfile content "$path" "$filter" 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$updated" ]; then
    printf '%s' "$json"
    return 1
  fi

  printf '%s' "$updated"
  return 0
}

UPDATED=$(printf '%s' "$INPUT" | jq '.tool_input' 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$UPDATED" ]; then
  exit 0
fi

CHANGED=0

MARKDOWN_VAL=$(printf '%s' "$INPUT" | jq -r '.tool_input.markdown // empty' 2>/dev/null)
if [ -n "$MARKDOWN_VAL" ]; then
  NEW_UPDATED=$(inject_file "$UPDATED" "$MARKDOWN_VAL" '.markdown = $content')
  if [ $? -eq 0 ]; then
    UPDATED="$NEW_UPDATED"
    CHANGED=1
  fi
fi

NEW_STR_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_str_path // empty' 2>/dev/null)
if [ -n "$NEW_STR_PATH" ]; then
  NEW_UPDATED=$(inject_file "$UPDATED" "$NEW_STR_PATH" '.new_str = $content | del(.new_str_path)')
  if [ $? -eq 0 ]; then
    UPDATED="$NEW_UPDATED"
    CHANGED=1
  fi
fi

CONTENT_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.content_path // empty' 2>/dev/null)
if [ -n "$CONTENT_PATH" ]; then
  NEW_UPDATED=$(inject_file "$UPDATED" "$CONTENT_PATH" '.content = $content | del(.content_path)')
  if [ $? -eq 0 ]; then
    UPDATED="$NEW_UPDATED"
    CHANGED=1
  fi
fi

REPLACE_NEW_STR_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.replace_content.new_str_path // empty' 2>/dev/null)
if [ -n "$REPLACE_NEW_STR_PATH" ]; then
  NEW_UPDATED=$(inject_file "$UPDATED" "$REPLACE_NEW_STR_PATH" '.replace_content.new_str = $content | del(.replace_content.new_str_path)')
  if [ $? -eq 0 ]; then
    UPDATED="$NEW_UPDATED"
    CHANGED=1
  fi
fi

INSERT_CONTENT_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.insert_content.content_path // empty' 2>/dev/null)
if [ -n "$INSERT_CONTENT_PATH" ]; then
  NEW_UPDATED=$(inject_file "$UPDATED" "$INSERT_CONTENT_PATH" '.insert_content.content = $content | del(.insert_content.content_path)')
  if [ $? -eq 0 ]; then
    UPDATED="$NEW_UPDATED"
    CHANGED=1
  fi
fi

while IFS=$'\t' read -r idx path; do
  [ -n "$path" ] || continue
  if ! is_abs_md_file "$path"; then
    continue
  fi
  if ! check_size "$path"; then
    continue
  fi

  NEW_UPDATED=$(printf '%s' "$UPDATED" | jq --argjson i "$idx" --rawfile content "$path" \
    '.content_updates[$i].new_str = $content | del(.content_updates[$i].new_str_path)' 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$NEW_UPDATED" ]; then
    UPDATED="$NEW_UPDATED"
    CHANGED=1
  fi
done < <(printf '%s' "$INPUT" | jq -r '.tool_input.content_updates // [] | to_entries[] | select(.value.new_str_path? != null) | [.key, .value.new_str_path] | @tsv' 2>/dev/null)

while IFS=$'\t' read -r idx path; do
  [ -n "$path" ] || continue
  if ! is_abs_md_file "$path"; then
    continue
  fi
  if ! check_size "$path"; then
    continue
  fi

  NEW_UPDATED=$(printf '%s' "$UPDATED" | jq --argjson i "$idx" --rawfile content "$path" \
    '.update_content.content_updates[$i].new_str = $content | del(.update_content.content_updates[$i].new_str_path)' 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$NEW_UPDATED" ]; then
    UPDATED="$NEW_UPDATED"
    CHANGED=1
  fi
done < <(printf '%s' "$INPUT" | jq -r '.tool_input.update_content.content_updates // [] | to_entries[] | select(.value.new_str_path? != null) | [.key, .value.new_str_path] | @tsv' 2>/dev/null)

if [ "$CHANGED" -eq 1 ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"updatedInput\":$UPDATED}}"
fi

exit 0
