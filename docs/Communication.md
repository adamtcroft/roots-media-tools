# Communication Log

## 2026-02-16: Task 1 Complete - Downloader Limited to Video + Captions, Sermon Window Identified

**What I changed:**
- Updated `scripts/download_latest_live.lua` to download only:
  - Video
  - Auto-captions (`en.*` in `.vtt`)
- Removed metadata side-output flags (`--write-info-json`, `--write-thumbnail`) from the downloader command.

**Run result:**
- Executed: `lua scripts/download_latest_live.lua`
- Most recent item returned by `@rootscommunitychurch2868/streams` at run time was:
  - `Roots Community Church Livestream 2⧸8⧸26 [zPzG6gRlke8]`
- Captions downloaded successfully:
  - `media/Roots Community Church Livestream 2⧸8⧸26 [zPzG6gRlke8].en.vtt`

**Sermon timestamps (from caption cues):**
- Sermon start (full speaking start after pre-sermon prayer): `00:23:04`
- Sermon end (transition into response/music): `00:50:19`
- Tighter scripture-anchored start option: `00:24:33` (`"as we jump back into Acts..."`)

---

## 2026-02-16: Task 2 Complete - Sermon Detection Concepts from 2026-02-08 Livestream

**Video reviewed:**
- `media/Roots Community Church Livestream 2⧸8⧸26 [zPzG6gRlke8].mkv` (duration ~1:07:59)
- Matching metadata indicates auto-captions are available and description references `Acts 2:42-47`.

**Concept 1 (preferred): transcript + scripture trigger**
- Pull auto-captions (`en`) and scan for sermon-start phrases like scripture references (`Acts 2`, `verse`, `turn to`) plus sustained single-speaker cadence.
- Start sermon at first strong scripture trigger after opening worship/announcements.
- End sermon at first closing phrase cluster (`let's pray`, `amen`) before dismissal/song.

**Concept 2: audio-structure segmentation fallback**
- Segment by audio profile: songs have sustained music energy and wider pitch 
  variation; sermon has lower spectral flux and continuous speech.
- Select the longest continuous speech-dominant segment in the middle/back half 
  as sermon candidate.
- Keep a short human trim pass (start/end +/- 30-90 seconds) before final 
  export.

---

## 2026-02-15: Task 1 Micro-Progress - Added User-Level Repair Helper

**What I accomplished:**
- Added `scripts/repair_ytdlp.lua` to attempt non-root repair steps for broken shell `yt-dlp` installs.
- Ran the helper and then re-ran `lua scripts/diagnose_ytdlp.lua`.
- Confirmed this environment remains blocked at system level:
  - `yt-dlp --version` still fails with `ModuleNotFoundError: No module named 'yt_dlp'`
  - `python3 -m pip` is unavailable
  - `python3 -m ensurepip --user` is blocked by externally managed environment policy (PEP 668 path)

**Why this helps:**
- Task 1 now has a repeatable first-line repair attempt (`lua scripts/repair_ytdlp.lua`) before manual package-manager repair.

**Remaining blocker:**
- Shell-level `yt-dlp` still requires system/user environment repair outside this sandbox.

---

## 2026-02-14: Task 1 Micro-Progress - Added Shell Diagnostic Script

**What I accomplished:**
- Added `scripts/diagnose_ytdlp.lua` to run a focused shell/runtime check for task 1.
- Verified current environment state:
  - `yt-dlp` executable exists (`/usr/bin/yt-dlp`)
  - `yt-dlp --version` fails with `ModuleNotFoundError: No module named 'yt_dlp'`
  - `python3 -c "import yt_dlp"` fails for the same reason
  - `python3 -m pip` is unavailable in this sandbox (`No module named pip`)

**Why this helps:**
- We now have a repeatable one-command diagnostic to prove whether task 1 is fixed after system-level repair.

**Next blocker:**
- Completing task 1 still requires installing a working `yt-dlp` runtime at the system/user level outside this sandbox.

---

## 2026-02-13: Task 1 Micro-Progress - Added yt-dlp Runtime Fallback in Downloader

**What I accomplished:**
- Updated `scripts/download_latest_live.lua` to auto-detect `yt_dlp` 
  site-packages paths and retry `yt-dlp` with a `PYTHONPATH` prefix when the 
  system stub fails with module import errors.
- Verified by running `lua scripts/download_latest_live.lua 
  /tmp/roots-media-test`; the script now gets past preflight and executes 
  `yt-dlp` successfully.
- Confirmed the current failure is now network/DNS in this sandbox (`Failed to 
  resolve 'www.youtube.com'`), not a `yt-dlp` traceback.

**Current blocker:**
- Shell-level `yt-dlp --version` (without fallback env) is still broken in this 
  environment because global executable/runtime paths can’t be modified from 
  this sandbox.

---

## 2026-02-13: Task 1 Micro-Progress - Improved yt-dlp Failure Diagnostics

**What I accomplished:**
- Ran `lua scripts/download_latest_live.lua` for task 1 verification.
- Confirmed the current blocker is a broken local `yt-dlp` runtime, not a missing command (`/usr/bin/yt-dlp` exists but fails with `ModuleNotFoundError: No module named 'yt_dlp'`).
- Updated `scripts/download_latest_live.lua` so preflight now captures and prints `yt-dlp --version` error details directly.

**Current blocker:**
- End-to-end download verification still depends on repairing local `yt-dlp` so `yt-dlp --version` succeeds.

---

## 2026-02-12: Task 1 Micro-Progress - Hardened yt-dlp Preflight Check

**What I accomplished:**
- Updated `scripts/download_latest_live.lua` to validate `yt-dlp` by running `yt-dlp --version` instead of only checking whether a command path exists.
- Improved the error output to explicitly indicate broken installs and added a verification step (`yt-dlp --version`).
- Re-ran the script to verify behavior; it now fails early with a clear install/fix message instead of failing mid-download.

**Current blocker:**
- Local `yt-dlp` command is present but broken in this environment (`ModuleNotFoundError: No module named 'yt_dlp'`), so actual download verification still depends on repairing the install.

---

## 2026-02-10: Task 1 Progress - Download Script Created

**What I accomplished:**
- Updated `.gitignore` to exclude video/audio files (*.mp4, *.webm, *.mkv, *.mp3, etc.) and media folders
- Created `scripts/download_latest_live.lua` - a cross-platform Lua script to download the most recent live video
- Created `media/` directory for downloaded content

**What's needed to complete Task 1:**
- Install `yt-dlp` on your system:
  - Arch Linux: `sudo pacman -S yt-dlp`
  - Ubuntu/Debian: `sudo apt install yt-dlp`
  - macOS: `brew install yt-dlp`
  - Windows: `winget install yt-dlp`

**To test the script:**
```bash
cd roots-media-tools
lua scripts/download_latest_live.lua
```

**Note:** I couldn't install yt-dlp myself (no sudo access, pip not available). Once you install it, the script should work immediately. The script downloads to `media/` by default and includes the video's JSON metadata and thumbnail.

---
