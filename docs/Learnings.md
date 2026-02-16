# Learnings

## 2026-02-16: Use Metadata + Auto-Captions Before Heavy Media Analysis

- For sermon extraction planning, check `<video>.info.json` first for description scripture references and auto-caption availability before running expensive video/audio analysis.
- A practical default is: transcript keyword trigger for start/end, then a brief manual trim window (+/- 30-90 seconds).

---

## 2026-02-15: Add a Scripted User-Level Repair Attempt Before Manual Dependency Fixes

- For broken CLI Python tools, add a tiny scripted repair pass (`python -m pip --user`, then verification) before escalating to manual system package-manager steps.
- In distro-managed Python environments, `ensurepip --user` can be blocked by external-management policy (PEP 668), so scripts should print that failure clearly and continue to manual guidance.

---

## 2026-02-14: Add a Dedicated Dependency Diagnostic Script for Blocked Environments

- When a task depends on system tooling you cannot install in-sandbox, add a tiny diagnostic script that checks binary presence, runtime execution, and Python module import separately.
- This produces a stable pass/fail gate (`yt-dlp --version` plus `python3 -c "import yt_dlp"`) that can be rerun immediately after external repair.

---

## 2026-02-13: Add Runtime Fallback Path for Python CLI Tools

- Some distro-packaged CLI wrappers can point to a Python runtime that does not include the package module, causing import traceback errors even when the package exists on disk.
- For reliability, dependency preflight can try fallback invocations with a discovered `site-packages` path (for example `PYTHONPATH=... yt-dlp --version`) before failing hard.

---

## 2026-02-13: Surface Dependency Error Output in Preflight Checks

- Preflight checks should capture and print dependency command stderr/stdout (for example `yt-dlp --version 2>&1`) instead of only returning a pass/fail boolean.
- Including raw dependency failure details in user-facing errors shortens troubleshooting loops and prevents guesswork.

---

## 2026-02-12: Validate Dependency Runtime, Not Just Command Presence

- A PATH check (`which`/`where`) can produce false positives when an executable stub exists but its runtime is broken.
- For external tool dependencies, preflight checks should execute a lightweight command (for example `yt-dlp --version`) and require success.
- Fast-fail dependency checks improve feedback quality and prevent confusing failures later in the workflow.

---

## 2026-02-10: yt-dlp and YouTube Channel Structure

**YouTube Channel URL patterns:**
- Channel home: `https://www.youtube.com/@username`
- Live streams/recordings: `https://www.youtube.com/@username/streams`
- Playlists: `https://www.youtube.com/@username/playlists`

**yt-dlp useful flags:**
- `--playlist-items 1` - Download only the first (most recent) video
- `--write-info-json` - Save video metadata as JSON (useful for later processing)
- `--write-thumbnail` - Download video thumbnail
- `-o "%(title)s [%(id)s].%(ext)s"` - Output template with title and video ID

**Lua cross-platform patterns:**
- Detect OS via `package.config:sub(1,1)` - returns `\\` on Windows, `/` on Unix
- Use `os.execute()` return value carefully: returns `0` on older Lua, `true` on newer
- `io.popen()` for capturing command output

---
