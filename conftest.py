"""Ensures the repo's own packages import without requiring `pip install -e .` first.

An editable install (see README.md "Getting Started") is still the
recommended setup -- this is a defensive fallback so `pytest` works
from a fresh checkout.
"""

import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent
for _path in (_REPO_ROOT, _REPO_ROOT / "tools"):
    if str(_path) not in sys.path:
        sys.path.insert(0, str(_path))
