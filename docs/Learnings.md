# Learnings

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