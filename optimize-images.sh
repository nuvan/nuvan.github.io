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
# Every image usable as an og:image also gets a JPEG social card, because
# LinkedIn will not render a WebP preview. See the social cards section below.
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

Also regenerates JPEG social cards for every og:image, into images/ and
_data/social-images.yml, so link previews work on LinkedIn as well as on X,
Facebook and Slack. This runs even when there are no masters to convert.

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

# ---------------------------------------------------------------------------
# Social card derivatives
# ---------------------------------------------------------------------------
# Link unfurlers need a JPEG. LinkedIn does not list WebP among the formats it
# accepts for og:image, so a WebP-only site shows a text-only card there even
# though X, Facebook and Slack all render WebP fine. Every image that can become
# an og:image therefore also gets a JPEG card.
#
# Cards are derived from images/ rather than from masters in _images-intake/.
# Most og:images were published long before this step existed and their masters
# are no longer in intake, and images/ is what the site actually ships, so
# deriving from it means the card can never disagree with the page. The extra
# generation loss is irrelevant at the size a card is displayed.
#
# Cards are capped at 1200px, which is what the platforms render at, and are
# never upscaled, following the same rule as the roles above. Exact dimensions
# are recorded in _data/social-images.yml so _includes/open-graph.html can
# declare og:image:width and og:image:height, which lets a crawler lay the card
# out on first scrape instead of fetching the file to measure it, and can fall
# back to the original image when no card exists.

SOCIAL_MAXW=1200
SOCIAL_Q=70
SOCIAL_MANIFEST="_data/social-images.yml"

# Images the Open Graph include names directly when a post has no feature image.
# Keep this in sync with _includes/open-graph.html.
SOCIAL_SITE_DEFAULTS="share01.webp fbprofile.webp"

social_total=0; social_made=0; social_current=0; social_failed=0
social_rows="$tmp/social-rows"
: > "$social_rows"

# An og:image is a published post's feature image, plus the site-level defaults.
#
# Only files whose name starts with a date are considered, because that is the
# rule Jekyll itself applies: anything else in _posts is not published. Several
# drafts live here under a draft_ prefix and reference images that were never
# compressed, so scanning every file would report failures for images that no
# live page can ask for.
#
# The octal escapes strip any quotes surrounding the front matter value.
social_names=$(
  {
    find _posts -type f -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*' -print0 2>/dev/null \
      | xargs -0 grep -hoE '^[[:space:]]*feature:[[:space:]]+[^[:space:]]+' 2>/dev/null | awk '{print $2}'
    printf '%s\n' $SOCIAL_SITE_DEFAULTS
  } | tr -d '\042\047' | sed '/^$/d;/-social\.jpg$/d' | sort -u
)

if [ -n "$social_names" ]; then
  printf '\n%s==> social cards  (JPEG for link unfurlers, quality %s, max width %spx)%s\n' \
    "$bold" "$SOCIAL_Q" "$SOCIAL_MAXW" "$reset"

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    social_total=$((social_total+1))
    stem="${name%.*}"
    src="$OUT/$name"
    dest="$OUT/$stem-social.jpg"

    if [ ! -f "$src" ]; then
      printf '  %-42s %sFAILED%s   referenced but missing from %s/\n' "$name" "$red" "$reset" "$OUT"
      social_failed=$((social_failed+1)); continue
    fi

    # Regenerate only when the source is newer, so reruns are cheap.
    if [ -f "$dest" ] && [ "$dest" -nt "$src" ]; then
      w=$(sips -g pixelWidth  "$dest" 2>/dev/null | awk -F': ' '/pixelWidth/{print $2}')
      h=$(sips -g pixelHeight "$dest" 2>/dev/null | awk -F': ' '/pixelHeight/{print $2}')
      printf '"%s"|%s-social.jpg|%s|%s\n' "$stem" "$stem" "${w:-0}" "${h:-0}" >> "$social_rows"
      printf '  %-42s %scurrent%s\n' "$name" "$green" "$reset"
      social_current=$((social_current+1)); continue
    fi

    natw=$(sips -g pixelWidth "$src" 2>/dev/null | awk -F': ' '/pixelWidth/{print $2}')
    if [ -z "${natw:-}" ]; then
      printf '  %-42s %sFAILED%s   could not read dimensions\n' "$name" "$red" "$reset"
      social_failed=$((social_failed+1)); continue
    fi

    resample=""
    note="re-encode only, ${natw}px source"
    if [ "$natw" -gt "$SOCIAL_MAXW" ]; then
      resample="--resampleWidth $SOCIAL_MAXW"
      note="${natw}px -> ${SOCIAL_MAXW}px"
    fi

    if $DRY_RUN; then
      printf '  %-42s would write %-34s (%s)\n' "$name" "$stem-social.jpg" "$note"
      social_made=$((social_made+1)); continue
    fi

    if ! sips -s format jpeg -s formatOptions "$SOCIAL_Q" $resample "$src" --out "$dest" >/dev/null 2>&1; then
      printf '  %-42s %sFAILED%s   jpeg encode failed\n' "$name" "$red" "$reset"
      social_failed=$((social_failed+1)); continue
    fi

    w=$(sips -g pixelWidth  "$dest" 2>/dev/null | awk -F': ' '/pixelWidth/{print $2}')
    h=$(sips -g pixelHeight "$dest" 2>/dev/null | awk -F': ' '/pixelHeight/{print $2}')
    if [ -z "${w:-}" ] || [ -z "${h:-}" ]; then
      printf '  %-42s %sFAILED%s   could not measure output\n' "$name" "$red" "$reset"
      social_failed=$((social_failed+1)); continue
    fi
    printf '"%s"|%s-social.jpg|%s|%s\n' "$stem" "$stem" "$w" "$h" >> "$social_rows"

    out_kb=$(( $(stat -f%z "$dest") / 1024 ))
    printf '  %-42s %6sK  %sx%s  %s\n' "$name" "$out_kb" "$w" "$h" "$note"
    social_made=$((social_made+1))
  done <<SOCIAL_LIST
$social_names
SOCIAL_LIST

  # The manifest is what the template reads, so write it whenever we have rows,
  # including a run where everything was already current.
  if ! $DRY_RUN && [ -s "$social_rows" ]; then
    mkdir -p "$(dirname "$SOCIAL_MANIFEST")"
    {
      printf '# Generated by optimize-images.sh. Do not edit by hand.\n'
      printf '#\n'
      printf '# Maps an image stem to its JPEG social card and the exact pixel size of that\n'
      printf '# card, so _includes/open-graph.html can declare og:image:width and\n'
      printf '# og:image:height. Regenerate by running ./optimize-images.sh\n'
      sort "$social_rows" | while IFS='|' read -r key file w h; do
        [ -n "$key" ] || continue
        printf '%s:\n  file: %s\n  width: %s\n  height: %s\n' "$key" "$file" "$w" "$h"
      done
    } > "$SOCIAL_MANIFEST"
    printf '  %s written, %s entr%s\n' "$SOCIAL_MANIFEST" \
      "$(grep -c '^  file:' "$SOCIAL_MANIFEST")" \
      "$([ "$(grep -c '^  file:' "$SOCIAL_MANIFEST")" -eq 1 ] && echo y || echo ies)"
  fi

  failed=$((failed+social_failed))
fi

printf '\n%s==> Summary%s\n' "$bold" "$reset"
if [ "$converted" -eq 0 ]; then
  printf '  No masters to convert. Put masters in %s/{hero,teaser,content}/\n' "$INTAKE"
  printf '  social cards: %s written, %s already current\n' "$social_made" "$social_current"
else
  if $DRY_RUN; then
    printf '  %s file(s) would be converted, %s skipped, %s failed\n' "$converted" "$skipped" "$failed"
  else
    saved=$((total_in-total_out))
    ratio=$(awk -v a="$total_in" -v b="$total_out" 'BEGIN{ if (b>0) printf "%.1fx", a/b; else printf "n/a" }')
    printf '  converted %s, skipped %s, failed %s\n' "$converted" "$skipped" "$failed"
    printf '  social cards: %s written, %s already current\n' "$social_made" "$social_current"
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
