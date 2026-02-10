# Communication Log

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