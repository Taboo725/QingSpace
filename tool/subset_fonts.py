#!/usr/bin/env python3
"""Subsets the bundled Source Han Serif CN weights down to the characters the
app can realistically need.

The full CN fonts carry ~31,000 glyphs each and weigh ~10.7 MB, which made them
roughly half the download. Modern Chinese text is covered to ~99.75% of
character occurrences by GB2312's 6,763 hanzi, so that plus punctuation, Latin
and the app's own UI strings is what gets kept.

A character outside the subset does not render as tofu: Flutter's engine falls
back to a platform font (Noto Serif/Sans CJK on Android, Microsoft YaHei on
Windows) for glyphs the asset font lacks. A rare character in a name therefore
appears in the system face rather than the serif — a visible but graceful
degradation, and the alternative is ~45 MB of download for everyone.

The character set is built entirely offline from Python's own gb2312 codec, so
this is deterministic and needs no network.

Usage
-----
    python -m pip install fonttools
    python tool/subset_fonts.py [--source DIR]

`--source` defaults to build/fonts_full/. Put the upstream OTFs there; get them
from the "SourceHanSerifCN.zip" asset of
https://github.com/adobe-fonts/source-han-serif/releases (OFL 1.1).
On the first run the script offers to move the current assets/fonts/ originals
into that directory for you.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_DIR = os.path.join(REPO_ROOT, 'assets', 'fonts')
DEFAULT_SOURCE = os.path.join(REPO_ROOT, 'build', 'fonts_full')

WEIGHTS = ['Regular', 'Medium', 'SemiBold', 'Bold', 'Heavy']


# ── Character set ────────────────────────────────────────────────────────────


def gb2312_chars() -> set[str]:
    """Every character encodable in GB2312 — 6,763 hanzi plus symbols."""
    chars = set()
    for high in range(0xA1, 0xFF):
        for low in range(0xA1, 0xFF):
            try:
                chars.add(bytes([high, low]).decode('gb2312'))
            except UnicodeDecodeError:
                continue
    return chars


def ranges(*spans: tuple[int, int]) -> set[str]:
    return {chr(cp) for start, end in spans for cp in range(start, end + 1)}


# Characters that are common today but predate GB2312 or sit outside it.
SUPPLEMENT = set(
    '〇々〜∶￥·—…‘’“”→←↑↓√×÷°℃±≤≥≠№℡'
    '啰喽咯嘞噢哦嗯呗嘛哟唔嘿嘻嘭砰哒'
    '镕堃玥瑄祎赟韬喆昇邨'
)


def source_literals() -> set[str]:
    """Every character appearing in a Dart string literal under lib/.

    Guarantees the app's own UI text renders in the bundled face even if a
    character somehow falls outside GB2312.
    """
    chars: set[str] = set()
    pattern = re.compile(r"'([^'\\\n]*)'|\"([^\"\\\n]*)\"")
    for root, _, files in os.walk(os.path.join(REPO_ROOT, 'lib')):
        for name in files:
            if not name.endswith('.dart'):
                continue
            text = open(os.path.join(root, name), encoding='utf-8').read()
            for single, double in pattern.findall(text):
                chars.update(single or double)
    return chars


def build_charset() -> set[str]:
    charset = gb2312_chars()
    charset |= ranges(
        (0x0020, 0x007E),  # ASCII printable
        (0x00A0, 0x00FF),  # Latin-1 supplement
        (0x2000, 0x206F),  # General punctuation: — … “ ” ‘ ’ ·
        (0x2460, 0x2473),  # Circled digits
        (0x3000, 0x303F),  # CJK punctuation: 。、《》【】
        (0xFE30, 0xFE4F),  # CJK compatibility forms
        (0xFF00, 0xFFEF),  # Fullwidth forms
    )
    charset |= SUPPLEMENT
    charset |= source_literals()
    return {c for c in charset if c.isprintable() or c == ' '}


# ── Subsetting ───────────────────────────────────────────────────────────────


def subset_one(source: str, target: str, charset: set[str]) -> tuple[int, int]:
    from fontTools import subset

    options = subset.Options()
    # Keep the layout features that matter for mixed Latin/CJK running text and
    # drop the rest (vertical writing, ruby, the full set of stylistic variants).
    options.layout_features = ['kern', 'liga', 'clig', 'calt', 'ccmp', 'locl']
    options.name_IDs = ['*']
    options.name_legacy = True
    options.notdef_outline = True
    options.recalc_bounds = True
    options.drop_tables += ['DSIG']
    options.hinting = False
    options.desubroutinize = False

    font = subset.load_font(source, options)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text=''.join(sorted(charset)))
    subsetter.subset(font)
    subset.save_font(font, target, options)
    font.close()
    return os.path.getsize(source), os.path.getsize(target)


def bootstrap_source(source_dir: str) -> None:
    """Move pristine originals out of assets/ on first run, if that is what is there."""
    os.makedirs(source_dir, exist_ok=True)
    for weight in WEIGHTS:
        name = f'SourceHanSerifCN-{weight}.otf'
        src = os.path.join(source_dir, name)
        if os.path.exists(src):
            continue
        asset = os.path.join(ASSET_DIR, name)
        if not os.path.exists(asset):
            continue
        # A pristine CN weight is ~10 MB; an already-subset one is far smaller.
        if os.path.getsize(asset) > 6 * 1024 * 1024:
            print(f'  moving original {name} -> {os.path.relpath(source_dir, REPO_ROOT)}/')
            shutil.copy2(asset, src)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', default=DEFAULT_SOURCE,
                        help='directory holding the full upstream OTFs')
    args = parser.parse_args()

    try:
        import fontTools  # noqa: F401
    except ImportError:
        sys.exit("fonttools is required:  python -m pip install fonttools")

    bootstrap_source(args.source)

    missing = [w for w in WEIGHTS
               if not os.path.exists(os.path.join(args.source, f'SourceHanSerifCN-{w}.otf'))]
    if missing:
        sys.exit(
            f"Missing full fonts for: {', '.join(missing)}\n"
            f"Put the upstream OTFs in {args.source}\n"
            "Download: https://github.com/adobe-fonts/source-han-serif/releases"
        )

    charset = build_charset()
    hanzi = sum(1 for c in charset if '一' <= c <= '鿿')
    print(f'Character set: {len(charset)} code points ({hanzi} hanzi)\n')

    total_before = total_after = 0
    for weight in WEIGHTS:
        name = f'SourceHanSerifCN-{weight}.otf'
        before, after = subset_one(
            os.path.join(args.source, name), os.path.join(ASSET_DIR, name), charset
        )
        total_before += before
        total_after += after
        print(f'  {name:<36}{before / 1048576:>7.1f}M -> {after / 1048576:>5.1f}M'
              f'  ({after / before * 100:.0f}%)')

    print(f'\n  {"total":<36}{total_before / 1048576:>7.1f}M -> {total_after / 1048576:>5.1f}M'
          f'  (saves {(total_before - total_after) / 1048576:.1f}M)')


if __name__ == '__main__':
    main()
