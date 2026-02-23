# Communication Log

## 2026-02-23: Improved Sermon Window Detection For 2⧸8 Livestream

**What I changed:**
- Updated `scripts/find_sermon_window.lua` to prefer a sermon marker that follows
  the opening prayer (prayer start/end) and a nearby worship segment, instead of
  always picking the first marker in the transcript.
- Added score penalties for markers that occur too early or too late in the
  service to avoid prelude or closing material.

**Result (2⧸8 captions):**
- Start: `00:23:07.750`
- End: `00:49:18.720`

**Sermon export:**
- Output: `media/Roots Community Church Livestream 2⧸8⧸26 [zPzG6gRlke8] - Sermon.mkv`

## 2026-02-23: Quieted ffmpeg Output For Sermon Exports

**What I changed:**
- Updated `scripts/export_sermon_clip.lua` to invoke ffmpeg with:
  - `-hide_banner -loglevel error -nostats`
- Removed the printed ffmpeg command to keep runs quiet by default.

**Result:**
- Export runs now emit only the script’s short status lines unless ffmpeg hits an error.

## 2026-02-23: Added Sermon Window Detector With Prayer/Response Heuristics

**What I changed:**
- Added `scripts/find_sermon_window.lua` to detect sermon start/end from VTT by:
  - Skipping the opening prayer (uses the last `amen` before the sermon marker).
  - Ending at the first response/transition cue (e.g., "would you just respond").
  - Falling back to music/prayer heuristics if response cues aren’t present.
- Tightened sermon marker matching to avoid false positives from Bible book names
  like “Job/Mark/John” unless followed by chapter numbers.

**How to use:**
```bash
lua scripts/find_sermon_window.lua media/<captions>.vtt
lua scripts/find_sermon_window.lua media/<captions>.vtt --debug
```

**Current result (2⧸15 livestream captions):**
- Start: `00:22:27.840`
- End: `00:52:13.520`

## 2026-02-23: Latest Livestream Downloaded, Sermon Window Found, Clip Exported (Fast Mode)

**What I changed:**
- Cleaned `media/` by archiving prior files into `media/_archive_2026-02-23/`.
- Downloaded the most recent livestream and auto-captions:
  - `media/Roots Community Church Livestream Sunday 2⧸15 [Weg3jKN5Vl4].mkv`
  - `media/Roots Community Church Livestream Sunday 2⧸15 [Weg3jKN5Vl4].en.vtt`
- Sermon window (from captions):
  - Start: `00:24:24.159` (phrase match on "sermon series")
  - End: `01:13:43.189` (auto end marker, closing prayer/amen)
- Exported sermon clip using stream copy for speed:
  - `media/Roots Community Church Livestream Sunday 2⧸15 [Weg3jKN5Vl4] - Sermon.mkv`

**Notes:**
- A re-encode version (more exact boundaries) was started but stopped due to expected long runtime; the partial file was moved to:
  - `media/_archive_2026-02-23/Roots Community Church Livestream Sunday 2⧸15 [Weg3jKN5Vl4] - Sermon.partial.mkv`
- If you want exact frame-accurate cuts, run the same export without `--copy` and let it complete.

## 2026-02-22: Task 1 Complete - Added Sermon Clip Export Script

**What I changed:**
- Added `scripts/export_sermon_clip.lua` to export a sermon-only video from a 
  source file using explicit `--start` and `--end` times.
- Default mode uses re-encode for more accurate cut boundaries; `--copy` is 
  available for faster stream copy.
- Script auto-builds an output name when `--output` is not provided.

**Usage:**
```bash
lua scripts/export_sermon_clip.lua media/<video>.mkv --start 00:23:04 --end 
00:50:19
lua scripts/export_sermon_clip.lua media/<video>.mkv --start 00:23:04 --end 
00:50:19 --output media/sermon.mkv
lua scripts/export_sermon_clip.lua media/<video>.mkv --start 00:23:04 --end 
00:50:19 --copy
```

**Verification run:**
- Command:
  - `lua scripts/export_sermon_clip.lua "media/Roots Community Church Livestream 
    2⧸8⧸26 [zPzG6gRlke8].mkv" --start 00:00:10 --end 00:00:20 --output 
    "media/test-sermon-clip-accurate.mkv"`
- Probe result:
  - `ffprobe` reported `duration=10.021000` for the test output clip.

## 2026-02-21: Added Sermon End Finder for VTT Captions

**What I changed:**
- Added `scripts/find_sermon_end.lua` to scan a `.vtt` transcript and print the
  last cue end time that matches sermon end markers.
- Defaults to explicit manual markers; optional `--auto` adds common closing
  phrases to widen the net.

**Usage:**
```bash
lua scripts/find_sermon_end.lua media/<captions>.vtt
lua scripts/find_sermon_end.lua media/<captions>.vtt --auto
lua scripts/find_sermon_end.lua media/<captions>.vtt --markers "sermon 
end|benediction"
```

**Why this helps:**
- Provides a quick sermon end timestamp from captions without a full manual 
  scrub.

## 2026-02-20: Added Sermon Start Finder for VTT Captions

**What I changed:**
- Added `scripts/find_sermon_start.lua` to scan a `.vtt` transcript and print 
  the
  first cue start time that matches sermon start markers.
- Defaults to explicit manual markers (`[sermon]`, `sermon start`, `message 
  begins`);
  optional `--auto` adds a few common spoken phrases.

**Usage:**
```bash
lua scripts/find_sermon_start.lua media/<captions>.vtt
lua scripts/find_sermon_start.lua media/<captions>.vtt --auto
lua scripts/find_sermon_start.lua media/<captions>.vtt --markers "sermon 
start|message begins"
```

**Why this helps:**
- Gives you a fast first-pass sermon start timestamp from captions without
  manually scrubbing the entire video.

## 2026-02-19: Added VTT Phrase Scanner For Sermon Marker Discovery

**What I changed:**
- Added `scripts/find_vtt_phrase.lua` to scan a `.vtt` transcript and print cue
  start times where a phrase appears (case-insensitive by default).

**Usage:**
```bash
lua scripts/find_vtt_phrase.lua media/<captions>.vtt "acts 2"
lua scripts/find_vtt_phrase.lua media/<captions>.vtt "let's pray" 
--case-sensitive
```

**Why this helps:**
- Gives you a fast, low-effort way to locate likely sermon start/end cues from
  captions before hard-coding or automating the exact time window.

## 2026-02-16: Task 1 Complete - Downloader Limited to Video + Captions, Sermon 
Window Identified

**What I changed:**
- Updated `scripts/download_latest_live.lua` to download only:
  - Video
  - Auto-captions (`en.*` in `.vtt`)
- Removed metadata side-output flags (`--write-info-json`, `--write-thumbnail`) 
  from the downloader command.

**Run result:**
- Executed: `lua scripts/download_latest_live.lua`
- Most recent item returned by `@rootscommunitychurch2868/streams` at run time 
  was:
  - `Roots Community Church Livestream 2⧸8⧸26 [zPzG6gRlke8]`
- Captions downloaded successfully:
  - `media/Roots Community Church Livestream 2⧸8⧸26 [zPzG6gRlke8].en.vtt`

**Sermon timestamps (from caption cues):**
- Sermon start (full speaking start after pre-sermon prayer): `00:23:04`
- Sermon end (transition into response/music): `00:50:19`
- Tighter scripture-anchored start option: `00:24:33` (`"as we jump back into 
  Acts..."`)

---

## 2026-02-16: Task 2 Complete - Sermon Detection Concepts from 2026-02-08 
Livestream

**Video reviewed:**
- `media/Roots Community Church Livestream 2⧸8⧸26 [zPzG6gRlke8].mkv` (duration 
  ~1:07:59)
- Matching metadata indicates auto-captions are available and description 
  references `Acts 2:42-47`.

**Concept 1 (preferred): transcript + scripture trigger**
- Pull auto-captions (`en`) and scan for sermon-start phrases like scripture 
  references (`Acts 2`, `verse`, `turn to`) plus sustained single-speaker 
  cadence.
- Start sermon at first strong scripture trigger after opening 
  worship/announcements.
- End sermon at first closing phrase cluster (`let's pray`, `amen`) before 
  dismissal/song.

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
- Added `scripts/repair_ytdlp.lua` to attempt non-root repair steps for broken 
  shell `yt-dlp` installs.
- Ran the helper and then re-ran `lua scripts/diagnose_ytdlp.lua`.
- Confirmed this environment remains blocked at system level:
  - `yt-dlp --version` still fails with `ModuleNotFoundError: No module named 
    'yt_dlp'`
  - `python3 -m pip` is unavailable
  - `python3 -m ensurepip --user` is blocked by externally managed environment 
    policy (PEP 668 path)

**Why this helps:**
- Task 1 now has a repeatable first-line repair attempt (`lua 
  scripts/repair_ytdlp.lua`) before manual package-manager repair.

**Remaining blocker:**
- Shell-level `yt-dlp` still requires system/user environment repair outside 
  this sandbox.

---

## 2026-02-14: Task 1 Micro-Progress - Added Shell Diagnostic Script

**What I accomplished:**
- Added `scripts/diagnose_ytdlp.lua` to run a focused shell/runtime check for 
  task 1.
- Verified current environment state:
  - `yt-dlp` executable exists (`/usr/bin/yt-dlp`)
  - `yt-dlp --version` fails with `ModuleNotFoundError: No module named 
    'yt_dlp'`
  - `python3 -c "import yt_dlp"` fails for the same reason
  - `python3 -m pip` is unavailable in this sandbox (`No module named pip`)

**Why this helps:**
- We now have a repeatable one-command diagnostic to prove whether task 1 is 
  fixed after system-level repair.

**Next blocker:**
- Completing task 1 still requires installing a working `yt-dlp` runtime at the 
  system/user level outside this sandbox.

---

## 2026-02-13: Task 1 Micro-Progress - Added yt-dlp Runtime Fallback in 
Downloader

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
- Confirmed the current blocker is a broken local `yt-dlp` runtime, not a 
  missing command (`/usr/bin/yt-dlp` exists but fails with `ModuleNotFoundError: 
  No module named 'yt_dlp'`).
- Updated `scripts/download_latest_live.lua` so preflight now captures and 
  prints `yt-dlp --version` error details directly.

**Current blocker:**
- End-to-end download verification still depends on repairing local `yt-dlp` so 
  `yt-dlp --version` succeeds.

---

## 2026-02-12: Task 1 Micro-Progress - Hardened yt-dlp Preflight Check

**What I accomplished:**
- Updated `scripts/download_latest_live.lua` to validate `yt-dlp` by running 
  `yt-dlp --version` instead of only checking whether a command path exists.
- Improved the error output to explicitly indicate broken installs and added a 
  verification step (`yt-dlp --version`).
- Re-ran the script to verify behavior; it now fails early with a clear 
  install/fix message instead of failing mid-download.

**Current blocker:**
- Local `yt-dlp` command is present but broken in this environment 
  (`ModuleNotFoundError: No module named 'yt_dlp'`), so actual download 
  verification still depends on repairing the install.

---

## 2026-02-10: Task 1 Progress - Download Script Created

**What I accomplished:**
- Updated `.gitignore` to exclude video/audio files (*.mp4, *.webm, *.mkv, 
  *.mp3, etc.) and media folders
- Created `scripts/download_latest_live.lua` - a cross-platform Lua script to 
  download the most recent live video
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

**Note:** I couldn't install yt-dlp myself (no sudo access, pip not available). 
Once you install it, the script should work immediately. The script downloads to 
`media/` by default and includes the video's JSON metadata and thumbnail.

---
