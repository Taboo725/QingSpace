#!/usr/bin/env python3
"""Checks that the committed icon masters still match tool/generate_icon.py.

Run by CI. Compares *pixels*, not file bytes: PNG encoders differ between
Pillow versions and platforms, so a byte comparison would fail on an unrelated
toolchain bump while the artwork is identical. The SVG is plain text and is
compared exactly.

Usage:  python tool/verify_icon.py
Exit code 1 and a GitHub Actions error annotation if anything drifted.
"""

from __future__ import annotations

import os
import subprocess
import sys

from PIL import Image, ImageChops

import generate_icon

# Pillow's resampling is deterministic, so an exact match is the norm; this
# only absorbs a last-bit rounding change in a future Pillow release.
MAX_CHANNEL_DIFF = 2

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def committed(path: str) -> bytes | None:
    """The blob at HEAD for a repo-relative path, or None if untracked."""
    result = subprocess.run(
        ['git', 'show', f'HEAD:{path}'],
        cwd=REPO_ROOT,
        capture_output=True,
    )
    return result.stdout if result.returncode == 0 else None


def fail(message: str) -> None:
    print(f'::error::{message}')
    print(
        "Run 'python tool/generate_icon.py' (and 'dart run flutter_launcher_icons') "
        'and commit the result.'
    )
    sys.exit(1)


def main() -> None:
    import io

    for name, expected in generate_icon.build_images().items():
        path = f'assets/icon/{name}'
        blob = committed(path)
        if blob is None:
            fail(f'{path} is not committed.')

        actual = Image.open(io.BytesIO(blob))
        if actual.size != expected.size:
            fail(f'{path}: committed {actual.size}, generator produces {expected.size}')
        if actual.mode != expected.mode:
            fail(f'{path}: committed mode {actual.mode}, generator produces {expected.mode}')

        diff = ImageChops.difference(actual.convert('RGBA'), expected.convert('RGBA'))
        worst = max(channel[1] for channel in diff.getextrema())
        if worst > MAX_CHANNEL_DIFF:
            fail(f'{path}: differs from the generator by up to {worst}/255 per channel')
        print(f'  {name:24} OK (max channel delta {worst})')

    blob = committed('assets/icon/icon.svg')
    if blob is None:
        fail('assets/icon/icon.svg is not committed.')
    if blob.decode('utf-8').replace('\r\n', '\n') != generate_icon.build_svg():
        fail('assets/icon/icon.svg differs from the generator output.')
    print(f'  {"icon.svg":24} OK')

    print('Icons match tool/generate_icon.py.')


if __name__ == '__main__':
    main()
