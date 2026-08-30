#!/usr/bin/env python3
"""
One-time migration of the existing image library to WebP.

Reads pristine masters from _masters/, writes role-appropriate WebP derivatives
into images/, rewrites every reference in posts, pages, templates and configs,
then removes the superseded raster files from git.

Roles are detected from actual usage, not guessed:
  hero     front matter "feature"          q95, max 2560px
  teaser   front matter "teaser"           q90, max  800px
  content  referenced in an article body   q90, max 1230px
  chrome   referenced from templates/config  role assigned explicitly below

Images are never upscaled. SVGs are never touched. Run with --dry-run first.

Usage:
  ./migrate-images.py --dry-run
  ./migrate-images.py
"""

import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

MASTERS = "_masters"
IMAGES = "images"
RASTER = (".png", ".jpg", ".jpeg", ".tif", ".tiff")

QUALITY = {"hero": 95, "teaser": 90, "content": 90}
MAXWIDTH = {"hero": 2560, "teaser": 800, "content": 1230}

# Site chrome is not referenced through front matter, so its role is explicit.
# Value is (role, master_override_or_None).
CHROME = {
    # The live hero is a heavily compressed 39K JPEG. bgs/bg01_1600x800.jpg is
    # the same 1600x800 uncompressed original, so use it as the master instead.
    "bg01_1600x800_mini.jpg": ("hero", "bgs/bg01_1600x800.jpg"),
    "mvjournal-background.png": ("hero", None),
    "blog_awatar.jpg": ("content", None),
    "fbprofile.jpg": ("content", None),   # Twitter card fallback
    "share01.jpg": ("content", None),     # Open Graph fallback
}

# Posts reference spectacles.jpeg but the file on disk was spectacles.png, so
# those images have always been broken. Repair by pointing them at the
# derivative built from the real master.
REPAIRS = {"spectacles.jpeg": "spectacles.png"}

BOLD, RESET, GREEN, YELLOW, RED = "\033[1m", "\033[0m", "\033[32m", "\033[33m", "\033[31m"


def sh(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def dims(path):
    r = sh(["sips", "-g", "pixelWidth", "-g", "pixelHeight", path])
    w = h = None
    for line in r.stdout.splitlines():
        if "pixelWidth:" in line:
            w = int(line.split(":")[1])
        if "pixelHeight:" in line:
            h = int(line.split(":")[1])
    return w, h


def source_files():
    """Every file whose text may contain an image reference."""
    pats = [
        "_posts/**/*.md", "_layouts/*.html", "_includes/*.html",
        "*.md", "*/*.md", "_data/*", "atom.xml",
    ]
    files = []
    for p in pats:
        files += glob.glob(p, recursive=True)
    files += ["_config.yml", "_local_config.yml"]
    return [f for f in files if os.path.isfile(f)]


def build_role_map():
    """Classify each referenced image by how it is actually used."""
    hero, teaser, content = set(), set(), set()
    for post in glob.glob("_posts/**/*.md", recursive=True):
        src = open(post, encoding="utf-8", errors="replace").read()
        parts = src.split("---")
        fm = parts[1] if src.startswith("---") and len(parts) > 2 else ""
        body = src.split("---", 2)[2] if len(parts) > 2 else src
        m = re.search(r"^\s*feature:\s*(\S+)", fm, re.M)
        if m:
            hero.add(m.group(1).strip())
        m = re.search(r"^\s*teaser:\s*(\S+)", fm, re.M)
        if m:
            teaser.add(m.group(1).strip())
        for f in re.findall(r"images/([A-Za-z0-9._#-]+\.(?:png|jpg|jpeg))", body, re.I):
            content.add(f)
    return hero, teaser, content


def convert(master, dest, quality, maxw, tmpdir):
    """Master -> WebP. Returns (out_kb, natural_width, target_width) or None."""
    w, _ = dims(master)
    if not w:
        return None
    target = min(w, maxw)
    stem = os.path.splitext(os.path.basename(dest))[0]
    png = os.path.join(tmpdir, stem + ".master.png")
    if sh(["sips", "-s", "format", "png", master, "--out", png]).returncode != 0:
        return None
    src = png
    if target < w:
        rs = os.path.join(tmpdir, stem + ".rs.png")
        if sh(["sips", "-s", "format", "png", "--resampleWidth", str(target),
               png, "--out", rs]).returncode != 0:
            return None
        src = rs
    os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
    if sh(["cwebp", "-q", str(quality), "-metadata", "icc", "-quiet",
           src, "-o", dest]).returncode != 0:
        return None
    return os.path.getsize(dest) // 1024, w, target


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    dry = args.dry_run

    if not os.path.isdir(MASTERS):
        sys.exit(f"{RED}No {MASTERS}/ directory. Nothing to migrate from.{RESET}")
    for tool in ("sips", "cwebp"):
        if not shutil.which(tool):
            sys.exit(f"{RED}Missing required tool: {tool}{RESET}")

    hero, teaser, content = build_role_map()
    dual = sorted(hero & teaser)

    # Decide a plan entry for every raster currently in images/.
    rasters = sorted(
        p[len(IMAGES) + 1:] for p in glob.glob(f"{IMAGES}/**/*", recursive=True)
        if os.path.isfile(p) and p.lower().endswith(RASTER)
    )

    plan = []          # (rel, role, master_rel, out_rel, extra_teaser_out|None)
    unresolved = []
    for rel in rasters:
        base = os.path.basename(rel)
        if base in CHROME:
            role, override = CHROME[base]
            master_rel = override or rel
        elif base in hero:
            role, master_rel = "hero", rel
        elif base in content:
            role, master_rel = "content", rel
        elif base in teaser:
            role, master_rel = "teaser", rel
        else:
            unresolved.append(rel)
            continue
        if not os.path.exists(os.path.join(MASTERS, master_rel)):
            unresolved.append(f"{rel} (no master at {master_rel})")
            continue
        stem = os.path.splitext(rel)[0]
        extra = f"{os.path.splitext(base)[0]}-teaser.webp" if base in dual else None
        plan.append((rel, role, master_rel, f"{stem}.webp", extra))

    # Repairs: build a derivative for a reference whose file never existed.
    repairs = []
    for broken, master_base in REPAIRS.items():
        if os.path.exists(os.path.join(MASTERS, master_base)):
            out = os.path.splitext(master_base)[0] + ".webp"
            repairs.append((broken, master_base, out))

    print(f"{BOLD}==> Plan{RESET}")
    print(f"  rasters to convert : {len(plan)}")
    print(f"  dual-role (hero+teaser, gets an extra -teaser derivative): "
          f"{', '.join(dual) if dual else 'none'}")
    print(f"  repairs            : {', '.join(b for b, _, _ in repairs) if repairs else 'none'}")
    if unresolved:
        print(f"  {YELLOW}unresolved (left alone){RESET} : {len(unresolved)}")
        for u in unresolved:
            print(f"      {u}")
    print()

    if dry:
        print(f"{YELLOW}==> DRY RUN. No files written, no references changed.{RESET}\n")

    tmpdir = tempfile.mkdtemp()
    total_in = total_out = 0
    made = {}          # old rel -> new rel
    teaser_out = {}    # base -> -teaser.webp name
    failures = []

    try:
        for role in ("hero", "teaser", "content"):
            entries = [p for p in plan if p[1] == role]
            if not entries:
                continue
            print(f"{BOLD}==> {role}  (q{QUALITY[role]}, max {MAXWIDTH[role]}px){RESET}")
            for rel, _, master_rel, out_rel, extra in entries:
                master = os.path.join(MASTERS, master_rel)
                in_kb = os.path.getsize(master) // 1024
                if dry:
                    w, _ = dims(master)
                    tgt = min(w or 0, MAXWIDTH[role])
                    note = f"{w}px -> {tgt}px" if w and tgt < w else f"re-encode only, {w}px"
                    print(f"  {os.path.basename(rel):<44}{in_kb:>7}K -> {os.path.basename(out_rel)}  ({note})")
                    total_in += in_kb
                    made[rel] = out_rel
                    if extra:
                        teaser_out[os.path.basename(rel)] = extra
                    continue

                res = convert(master, os.path.join(IMAGES, out_rel),
                              QUALITY[role], MAXWIDTH[role], tmpdir)
                if not res:
                    print(f"  {os.path.basename(rel):<44}{RED}FAILED{RESET}")
                    failures.append(rel)
                    continue
                out_kb, w, tgt = res
                total_in += in_kb
                total_out += out_kb
                made[rel] = out_rel
                ratio = f"{in_kb / out_kb:.1f}x" if out_kb else "n/a"
                note = f"{w}px -> {tgt}px" if tgt < w else f"re-encode only, {w}px"
                print(f"  {os.path.basename(rel):<44}{in_kb:>7}K -> {out_kb:>6}K  "
                      f"{GREEN}{ratio:>7} smaller{RESET}  {note}")

                if extra:
                    r2 = convert(master, os.path.join(IMAGES, extra),
                                 QUALITY["teaser"], MAXWIDTH["teaser"], tmpdir)
                    if r2:
                        total_out += r2[0]
                        teaser_out[os.path.basename(rel)] = extra
                        print(f"  {'  + ' + extra:<44}{'':>7}  {r2[0]:>6}K  "
                              f"{GREEN}(teaser variant){RESET}")
            print()

        if repairs:
            print(f"{BOLD}==> repairs{RESET}")
            for broken, master_base, out in repairs:
                master = os.path.join(MASTERS, master_base)
                in_kb = os.path.getsize(master) // 1024
                if dry:
                    print(f"  {broken:<44}-> {out}  (from master {master_base})")
                    total_in += in_kb
                else:
                    res = convert(master, os.path.join(IMAGES, out),
                                  QUALITY["content"], MAXWIDTH["content"], tmpdir)
                    if res:
                        total_in += in_kb
                        total_out += res[0]
                        print(f"  {broken:<44}{in_kb:>7}K -> {res[0]:>6}K  "
                              f"{GREEN}repaired{RESET} from {master_base}")
                    else:
                        failures.append(broken)
            print()
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    if failures:
        print(f"{RED}==> {len(failures)} conversion(s) failed. "
              f"No references were rewritten.{RESET}")
        return 1

    # ---- rewrite references -------------------------------------------------
    rename = {os.path.basename(o): os.path.basename(n) for o, n in made.items()}
    for broken, _, out in repairs:
        rename[broken] = os.path.basename(out)

    changed = {}
    for path in source_files():
        original = open(path, encoding="utf-8", errors="replace").read()
        text = original
        edits = 0

        is_post = path.startswith("_posts/")
        if is_post and text.startswith("---") and text.count("---") >= 2:
            head, fm, body = text.split("---", 2)
        else:
            head = fm = None
            body = text

        # front matter teaser uses the -teaser variant when one exists
        if fm is not None:
            def fix_fm(m, key):
                val = m.group(2).strip()
                if key == "teaser" and val in teaser_out:
                    new = teaser_out[val]
                elif val in rename:
                    new = rename[val]
                else:
                    return m.group(0)
                return f"{m.group(1)}{new}"

            for key in ("teaser", "feature"):
                fm, n = re.subn(rf"(^\s*{key}:\s*)(\S+)",
                                lambda m, k=key: fix_fm(m, k), fm, flags=re.M)
                edits += n

        # any images/<name> path, in bodies, templates and configs
        def fix_path(m):
            name = m.group(1)
            return f"images/{rename[name]}" if name in rename else m.group(0)

        body, n = re.subn(r"images/([A-Za-z0-9._#-]+\.(?:png|jpg|jpeg))", fix_path, body)
        edits += n

        # bare filenames in config values (avatar, logo, teaser defaults)
        if path.endswith((".yml", ".yaml")):
            for key in ("avatar", "logo", "teaser"):
                def fix_cfg(m):
                    val = m.group(2).strip()
                    return f"{m.group(1)}{rename[val]}" if val in rename else m.group(0)
                body, n = re.subn(rf"(^\s*{key}:\s*)(\S+)", fix_cfg, body, flags=re.M)
                edits += n

        text = f"{head}---{fm}---{body}" if fm is not None else body
        if edits and text != original:
            changed[path] = edits
            if not dry:
                open(path, "w", encoding="utf-8").write(text)

    print(f"{BOLD}==> Reference rewrites{RESET}")
    if changed:
        for p in sorted(changed):
            print(f"  {changed[p]:>3} in {p}")
        print(f"  {len(changed)} file(s), {sum(changed.values())} reference(s)")
    else:
        print("  none")
    print()

    # ---- remove superseded rasters -----------------------------------------
    old = [os.path.join(IMAGES, rel) for rel in made if os.path.exists(os.path.join(IMAGES, rel))]
    print(f"{BOLD}==> Superseded raster removal{RESET}")
    print(f"  {len(old)} file(s)")
    if not dry and old:
        r = sh(["git", "rm", "-q"] + old)
        if r.returncode != 0:
            print(f"  {YELLOW}git rm reported: {r.stderr.strip()}{RESET}")
    print()

    print(f"{BOLD}==> Summary{RESET}")
    if dry:
        print(f"  would convert {len(plan)} raster(s) plus {len(repairs)} repair(s)")
        print(f"  masters total {total_in:,}K")
        print(f"\n{YELLOW}Dry run only. Re-run without --dry-run to apply.{RESET}")
    else:
        saved = total_in - total_out
        ratio = f"{total_in / total_out:.1f}x" if total_out else "n/a"
        print(f"  {total_in:,}K -> {total_out:,}K   ({ratio} smaller, {saved:,}K saved)")
        print("\n  Next: ./serve.sh to preview, then ./publish.sh -m \"...\" --push")
    return 0


if __name__ == "__main__":
    sys.exit(main())
