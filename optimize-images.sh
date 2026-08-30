#!/bin/bash
#
# Compresses high-resolution image masters into web-ready WebP derivatives.
#
# Masters are never modified. Drop them in _images-intake/<role>/ and run this;
# derivatives land in images/ as <name>.webp. Both _images-intake/ and _masters/
# are gitignored and excluded from the Jekyll build, so masters never ship.
#
# Roles set quality and maximum width, both derived from measured display sizes:
#
#   hero     q95, max 2560px  full-bleed, fills the viewport
#   teaser   q90, max  800px  cards render at 325px desktop / 356px at 3x mobile
#   content  q90, max 1230px  .page-content is a fixed 615px column
#
# Images are never upscaled: a master narrower than the cap is only re-encoded.
# ICC colour profiles are preserved so colours do not shift; EXIF is dropped,
# which also strips camera and GPS data.
#
# Usage:
#   ./optimize-images.sh              convert everything in _images-intake/
#   ./optimize-images.sh --dry-run    report what would happen, write nothing
#
set -uo pipefail

INTAKE="_images-intake"
OUT="images"
DRY_RUN=false

bold=$'\033[1m'; reset=$'\033[0m'; red=$'\033[31m'; green=$'\033[32m'; yellow=$'\033[33m'

usage() {
  cat <<'EOF'
Usage: ./optimize-images.sh [--dry-run]

Reads high-resolution masters from _images-intake/<role>/ and writes optimized
WebP derivatives into images/.

Roles (subdirectory names):
  hero/       q95, max 2560px
  teaser/     q90, max  800px
  content/    q90, max 1230px

Options:
  --dry-run   Show what would be written without writing anything.
  -h, --help  Show this help.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '%sUnknown option: %s%s\n' "$red" "$1" "$reset" >&2; usage >&2; exit 1 ;;
  esac
done

for tool in sips cwebp; do
  command -v "$tool" >/dev/null || { printf '%sMissing required tool: %s%s\n' "$red" "$tool" "$reset" >&2; exit 1; }
done

quality_for() { case "$1" in hero) echo 95 ;; *) echo 90 ;; esac; }
maxwidth_for() { case "$1" in hero) echo 2560 ;; teaser) echo 800 ;; content) echo 1230 ;; esac; }

if [ ! -d "$INTAKE" ]; then
  printf '%s==> No %s directory. Creating it with role subdirectories.%s\n' "$bold" "$INTAKE" "$reset"
  mkdir -p "$INTAKE"/hero "$INTAKE"/teaser "$INTAKE"/content
  cat > "$INTAKE/README.txt" <<'EOF'
Drop high-resolution image masters into the role directory that matches how the
image will be used, then run ./optimize-images.sh from the repository root.

  hero/      the wide image at the top of a post (front matter "feature")
  teaser/    the card thumbnail in listings (front matter "teaser")
  content/   images placed inside the article body

Masters here are never modified, never committed and never built. Keep your own
permanent archive elsewhere; this is a working area you can empty at any time.
EOF
  printf 'Put masters in %s/{hero,teaser,content}/ and run this again.\n' "$INTAKE"
  exit 0
fi

$DRY_RUN && printf '%s==> DRY RUN. Nothing will be written.%s\n' "$yellow" "$reset"

total_in=0; total_out=0; converted=0; skipped=0; failed=0
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT

# A file placed in two role directories would produce one output name and the
# second role would silently overwrite the first. Detect that before any work.
collisions=$(find "$INTAKE" -mindepth 2 -maxdepth 2 -type f ! -name '.DS_Store' ! -name 'README.txt' \
  -exec basename {} \; 2>/dev/null \
  | sed 's/\.[^.]*$//' | sort | uniq -d)
if [ -n "$collisions" ]; then
  printf '%s==> Output name collision%s\n' "$red" "$reset" >&2
  printf 'These names appear in more than one role directory, so they would\n' >&2
  printf 'produce the same .webp and overwrite each other:\n\n' >&2
  printf '%s\n' "$collisions" | sed 's/^/  /' >&2
  printf '\nIf you want one image in two roles, give the smaller one a distinct\n' >&2
  printf 'name, for example wa4-teaser.png, and reference it accordingly.\n' >&2
  exit 1
fi

for role in hero teaser content; do
  dir="$INTAKE/$role"
  [ -d "$dir" ] || continue

  q=$(quality_for "$role")
  maxw=$(maxwidth_for "$role")

  # collect candidate files without a subshell, so counters survive
  files=()
  while IFS= read -r f; do files+=("$f"); done < <(find "$dir" -maxdepth 1 -type f ! -name '.DS_Store' ! -name 'README.txt' | sort)
  [ ${#files[@]} -eq 0 ] && continue

  printf '\n%s==> %s  (quality %s, max width %spx)%s\n' "$bold" "$role" "$q" "$maxw" "$reset"

  for src in "${files[@]}"; do
    base=$(basename "$src")
    stem="${base%.*}"
    ext=$(printf '%s' "${base##*.}" | tr '[:upper:]' '[:lower:]')

    case "$ext" in
      png|jpg|jpeg|tif|tiff|heic) : ;;
      svg)
        printf '  %-42s %sskipped%s  vector, already optimal\n' "$base" "$yellow" "$reset"
        skipped=$((skipped+1)); continue ;;
      gif)
        printf '  %-42s %sskipped%s  may be animated, convert by hand\n' "$base" "$yellow" "$reset"
        skipped=$((skipped+1)); continue ;;
      *)
        printf '  %-42s %sskipped%s  unsupported type .%s\n' "$base" "$yellow" "$reset" "$ext"
        skipped=$((skipped+1)); continue ;;
    esac

    natw=$(sips -g pixelWidth "$src" 2>/dev/null | awk -F': ' '/pixelWidth/{print $2}')
    if [ -z "${natw:-}" ]; then
      printf '  %-42s %sFAILED%s   could not read dimensions\n' "$base" "$red" "$reset"
      failed=$((failed+1)); continue
    fi

    target=$maxw
    note=""
    if [ "$natw" -le "$maxw" ]; then
      target=$natw
      note="re-encode only, ${natw}px master"
    else
      note="${natw}px -> ${target}px"
    fi

    in_kb=$(( $(stat -f%z "$src") / 1024 ))
    dest="$OUT/$stem.webp"

    if $DRY_RUN; then
      printf '  %-42s %s -> %s  (%s)\n' "$base" "${in_kb}K" "$stem.webp" "$note"
      total_in=$((total_in+in_kb)); converted=$((converted+1))
      continue
    fi

    # Normalize to a lossless PNG first so resize and encode are not double-lossy.
    master="$tmp/$stem.master.png"
    if ! sips -s format png "$src" --out "$master" >/dev/null 2>&1; then
      printf '  %-42s %sFAILED%s   could not decode\n' "$base" "$red" "$reset"
      failed=$((failed+1)); continue
    fi

    resized="$master"
    if [ "$target" -lt "$natw" ]; then
      resized="$tmp/$stem.resized.png"
      if ! sips -s format png --resampleWidth "$target" "$master" --out "$resized" >/dev/null 2>&1; then
        printf '  %-42s %sFAILED%s   could not resize\n' "$base" "$red" "$reset"
        failed=$((failed+1)); continue
      fi
    fi

    mkdir -p "$OUT"
    if ! cwebp -q "$q" -metadata icc -quiet "$resized" -o "$dest" 2>/dev/null; then
      printf '  %-42s %sFAILED%s   webp encode failed\n' "$base" "$red" "$reset"
      failed=$((failed+1)); continue
    fi

    out_kb=$(( $(stat -f%z "$dest") / 1024 ))
    total_in=$((total_in+in_kb)); total_out=$((total_out+out_kb))
    converted=$((converted+1))

    ratio=$(awk -v a="$in_kb" -v b="$out_kb" 'BEGIN{ if (b>0) printf "%.1fx", a/b; else printf "n/a" }')
    printf '  %-42s %6sK -> %6sK  %s%7s smaller%s  %s\n' \
      "$base" "$in_kb" "$out_kb" "$green" "$ratio" "$reset" "$note"

    rm -f "$master" "$resized"
  done
done

printf '\n%s==> Summary%s\n' "$bold" "$reset"
if [ "$converted" -eq 0 ]; then
  printf '  Nothing to convert. Put masters in %s/{hero,teaser,content}/\n' "$INTAKE"
else
  if $DRY_RUN; then
    printf '  %s file(s) would be converted, %s skipped, %s failed\n' "$converted" "$skipped" "$failed"
  else
    saved=$((total_in-total_out))
    ratio=$(awk -v a="$total_in" -v b="$total_out" 'BEGIN{ if (b>0) printf "%.1fx", a/b; else printf "n/a" }')
    printf '  converted %s, skipped %s, failed %s\n' "$converted" "$skipped" "$failed"
    printf '  %sK -> %sK  (%s smaller, %sK saved)\n' "$total_in" "$total_out" "$ratio" "$saved"
  fi
fi

if [ "$failed" -gt 0 ]; then
  printf '\n%sSome files failed. Nothing else was affected.%s\n' "$red" "$reset"
  exit 1
fi

if ! $DRY_RUN && [ "$converted" -gt 0 ]; then
  cat <<EOF

Next steps:
  1. Reference the .webp files in your article.
  2. ./serve.sh                      preview the real compressed images
  3. ./publish.sh -m "..." --push    go live

Masters in $INTAKE/ were not touched. Move them to your archive and empty the
directory when you are done.
EOF
fi
