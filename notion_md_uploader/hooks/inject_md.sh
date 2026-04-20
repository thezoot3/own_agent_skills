#!/bin/bash
INPUT=$(cat)
MARKDOWN_VAL=$(echo "$INPUT" | jq -r '.tool_input.markdown // empty')

if [[ "$MARKDOWN_VAL" == /* ]] && [[ "$MARKDOWN_VAL" == *.md ]] && [ -f "$MARKDOWN_VAL" ]; then
  UPDATED=$(echo "$INPUT" | jq --rawfile content "$MARKDOWN_VAL" \
    '.tool_input.markdown = $content | .tool_input')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"updatedInput\":$UPDATED}}"
  exit 0
fi

exit 0
