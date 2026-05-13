#!/usr/bin/env bash
set -e
MANIFEST="integrity.sha256"

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: $MANIFEST not found."
  exit 1
fi

echo "=== Checking parts ==="
FAILED=0
while IFS= read -r LINE; do
  EXPECTED_HASH=$(echo "$LINE" | awk '{print $1}')
  FILE=$(echo "$LINE" | awk '{print $2}')
  [[ "$FILE" != *.part.* ]] && continue
  if [ ! -f "$FILE" ]; then
    echo "MISSING: $FILE"
    FAILED=$((FAILED + 1))
    continue
  fi
  ACTUAL_HASH=$(sha256sum "$FILE" | awk '{print $1}')
  if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
    echo "CORRUPTED: $FILE"
    FAILED=$((FAILED + 1))
  fi
done < "$MANIFEST"

if [ "$FAILED" -gt 0 ]; then
  echo "ERROR: $FAILED file(s) are broken. Stop."
  exit 1
fi

echo "=== Putting parts together ==="
BASE_NAMES=$(grep '\.part\.' "$MANIFEST" | awk '{print $2}' \
  | sed 's/\.part\.[0-9]*$//' | sort -u)

while IFS= read -r BASE; do
  [ -z "$BASE" ] && continue
  echo "Building: $BASE"
  cat "${BASE}".part.* > "$BASE"
  
  # Check the combined file
  EXPECTED=$(grep "  $BASE$" "$MANIFEST" | awk '{print $1}')
  if [ -n "$EXPECTED" ]; then
    ACTUAL=$(sha256sum "$BASE" | awk '{print $1}')
    if [ "$ACTUAL" == "$EXPECTED" ]; then
      echo "OK: $BASE"
      echo "Unzipping back to normal..."
      gunzip "$BASE"
    else
      echo "ERROR: Hash is wrong after building."
      exit 1
    fi
  fi
done <<< "$BASE_NAMES"

echo "All done!"
