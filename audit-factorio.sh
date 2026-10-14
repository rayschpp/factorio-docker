#!/usr/bin/env bash
# audit-factorio.sh — Self-contained: download, extract, audit
# Usage: docker run --rm factorio-audit ./audit-factorio.sh [VERSION] [DURATION_SECONDS]

set -euo pipefail

FACTORIO_VERSION="${1:-2.1.19}"
DURATION="${2:-60}"
FACTORIO_DIR="./.opt/factorio"
TARBALL="/tmp/factorio.tar.xz"
URL="https://www.factorio.com/get-download/${FACTORIO_VERSION}/headless/linux64"

# Write excludes to a temp file (edit EXCLUDES_PATTERNS to tighten)
EXCLUDES_PATTERNS=(
    'doc-html/*'
    '*.txt'
    '*.example.*'
    'data/base/campaigns/*'
#    '*/campaigns/*'
)
printf '%s\n' "${EXCLUDES_PATTERNS[@]}" > /tmp/excludes.txt

# --- 1. Download ---
if [[ ! -f "$TARBALL" ]]; then
    echo "=== Downloading Factorio ${FACTORIO_VERSION} headless ==="
    wget --no-check-certificate "$URL" -O "$TARBALL"
else
    echo "=== Using cached tarball: $TARBALL ==="
fi

# --- 2. Extract ---
rm -rf "$FACTORIO_DIR"
mkdir -p "$FACTORIO_DIR"

echo "=== Extracting with excludes ==="
tar -xf "$TARBALL" -C "$FACTORIO_DIR" --strip-components=1 \
    --exclude-from=/tmp/excludes.txt

mkdir -p "$FACTORIO_DIR/saves" "$FACTORIO_DIR/mods" "$FACTORIO_DIR/config"

# --- 3. List all files ---
ALL_FILES="/tmp/all_files.txt"
find "$FACTORIO_DIR" -type f | sort > "$ALL_FILES"
TOTAL=$(wc -l < "$ALL_FILES")
SIZE=$(du -sh "$FACTORIO_DIR" | awk '{print $1}')
echo "Extracted: $TOTAL files, $SIZE"

# --- 4. Run under strace ---
echo "=== Running factorio under strace for ${DURATION}s ==="
TRACE_FILE="/tmp/strace.out"
timeout "$DURATION" strace -f -e trace=openat,stat,statx \
    -o "$TRACE_FILE" \
    "$FACTORIO_DIR/bin/x64/factorio" \
    --start-server \
    --server-settings "$FACTORIO_DIR/data/server-settings.example.json" \
    2>/dev/null || true

# --- 5. Extract accessed paths ---
ACCESSED_FILES="/tmp/accessed_files.txt"
{
    grep -oP '(?<=openat\(AT_FDCWD, ")[^"]+(?=", O_)' "$TRACE_FILE"
    grep -oP '(?<=stat\(")[^"]+(?="\))' "$TRACE_FILE"
    grep -oP '(?<=statx\(AT_FDCWD, ")[^"]+(?=",)' "$TRACE_FILE"
} | grep "^$FACTORIO_DIR/" | sort -u > "$ACCESSED_FILES" || true
ACCESSED=$(wc -l < "$ACCESSED_FILES")

# --- 6. Find unused ---
UNUSED_FILES="/tmp/unused_files.txt"
comm -23 "$ALL_FILES" "$ACCESSED_FILES" > "$UNUSED_FILES"
UNUSED=$(wc -l < "$UNUSED_FILES")
UNUSED_SIZE=$(du -ch $(cat "$UNUSED_FILES" | head -500) 2>/dev/null | tail -1 | awk '{print $1}')

# --- 7. Report ---
{
    echo "=============================================="
    echo " Factorio ${FACTORIO_VERSION} Audit — ${DURATION}s"
    echo "=============================================="
    echo ""
    echo "Total:          $TOTAL files, $SIZE"
    echo "Accessed:       $ACCESSED"
    echo "Unused:         $UNUSED  (~${UNUSED_SIZE})"
    echo ""
    echo "--- UNUSED BY DIRECTORY (top 20) ---"
    while IFS= read -r f; do
        rel="${f#$FACTORIO_DIR/}"
        echo "$rel" | awk -F'/' '{print $1"/"$2"/"}'
    done < "$UNUSED_FILES" | sort | uniq -c | sort -rn | head -20
    echo ""
    echo "--- SUGGESTED --exclude PATTERNS ---"
    while IFS= read -r f; do
        rel="${f#$FACTORIO_DIR/}"
        echo "$rel" | awk -F'/' '{print $1"/"$2"/"}'
    done < "$UNUSED_FILES" | sort | uniq -c | sort -rn | head -20 | \
        awk '{printf "    \"--exclude=%s/*\",\n", $2}'
    echo ""
    echo "--- UNUSED FILE SAMPLE (first 50) ---"
    head -50 "$UNUSED_FILES" | sed "s|$FACTORIO_DIR/||"
} | tee /tmp/report.txt

echo ""
echo "✅ Done. Copy suggested excludes into the EXCLUDES array and re-run."