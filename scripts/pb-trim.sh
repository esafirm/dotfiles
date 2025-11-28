#!/usr/bin/env bash

pbtrim() {
  #!/bin/bash

  # 1. Get the current clipboard content
  CLIPBOARD_CONTENT=$(pbpaste)

  # 2. Extract leading whitespace and find the minimum length
  # The entire awk command is now on a single line for robustness.
  MIN_INDENT=$(echo "$CLIPBOARD_CONTENT" | \
    # Filter for lines that start with whitespace and are NOT entirely blank
    grep '^[[:space:]]*[^[:space:]]' | \
    # Capture the leading whitespace characters
    sed 's/^\([[:space:]]*\).*/\1/' | \
    # Find the length of the shortest leading whitespace
    awk '{ if (length == 0) next; if (!min || length < min) min = length } END { print min }')

  # 3. If a minimum indentation was found (i.e., not an empty string or '0')
  if [ ! -z "$MIN_INDENT" ] && [ "$MIN_INDENT" -gt 0 ]; then
    
    # Remove exactly MIN_INDENT number of any starting whitespace character
    TRIMMED_CONTENT=$(echo "$CLIPBOARD_CONTENT" | \
      sed "s/^[[:space:]]\{$MIN_INDENT\}//")

    # 4. Put the trimmed content back onto the clipboard
    echo "$TRIMMED_CONTENT" | pbcopy
  else
    # If no common indentation was found (or if the input was empty), copy the original back.
    echo "$CLIPBOARD_CONTENT" | pbcopy
    MIN_INDENT=0
  fi

  echo "Clipboard indentation trimmed by $MIN_INDENT character(s)."
}
