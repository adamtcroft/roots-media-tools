#!/usr/bin/env lua
--[[
    export_sermon_clip.lua

    Export a sermon-only clip from a source video using explicit start/end times.

    Usage:
      lua export_sermon_clip.lua <input_video> --start <time> --end <time> [--output <file>] [--copy]

    Time format:
      - HH:MM:SS
      - HH:MM:SS.mmm
      - seconds (e.g. 1384.5)
--]]

local function usage()
    print("Usage: lua export_sermon_clip.lua <input_video> --start <time> --end <time> [--output <file>] [--copy]")
end

local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function shell_quote(value)
    local escaped = value:gsub('"', '\\"')
    return '"' .. escaped .. '"'
end

local function split_path(path)
    local dir, file = path:match("^(.*[/\\])(.-)$")
    if not dir then
        return "", path
    end
    return dir, file
end

local function split_ext(file)
    local stem, ext = file:match("^(.*)%.([^%.]+)$")
    if not stem then
        return file, ""
    end
    return stem, ext
end

local function parse_time(raw)
    if not raw then
        return nil
    end

    local h, m, s = raw:match("^(%d+):(%d%d):(%d%d%.?%d*)$")
    if h then
        local hour = tonumber(h)
        local min = tonumber(m)
        local sec = tonumber(s)
        if not hour or not min or not sec or min > 59 or sec >= 60 then
            return nil
        end
        return hour * 3600 + min * 60 + sec
    end

    local seconds_only = tonumber(raw)
    if seconds_only and seconds_only >= 0 then
        return seconds_only
    end

    return nil
end

local function format_time(seconds)
    local millis = math.floor((seconds - math.floor(seconds)) * 1000 + 0.5)
    local whole = math.floor(seconds)
    if millis == 1000 then
        whole = whole + 1
        millis = 0
    end

    local h = math.floor(whole / 3600)
    local m = math.floor((whole % 3600) / 60)
    local s = whole % 60
    return string.format("%02d:%02d:%02d.%03d", h, m, s, millis)
end

local function command_succeeds(cmd)
    local result = os.execute(cmd)
    return result == true or result == 0
end

local input_path = nil
local start_raw = nil
local ending_raw = nil
local output_path = nil
local use_copy = false

local i = 1
while i <= #arg do
    local value = arg[i]
    if value == "--start" then
        i = i + 1
        start_raw = arg[i]
    elseif value == "--end" then
        i = i + 1
        ending_raw = arg[i]
    elseif value == "--output" then
        i = i + 1
        output_path = arg[i]
    elseif value == "--copy" then
        use_copy = true
    elseif not input_path then
        input_path = value
    else
        print("ERROR: Unexpected argument: " .. tostring(value))
        usage()
        os.exit(1)
    end
    i = i + 1
end

if not input_path or not start_raw or not ending_raw then
    usage()
    os.exit(1)
end

local start_seconds = parse_time(trim(start_raw))
local end_seconds = parse_time(trim(ending_raw))

if not start_seconds then
    print("ERROR: Invalid --start time: " .. tostring(start_raw))
    os.exit(1)
end

if not end_seconds then
    print("ERROR: Invalid --end time: " .. tostring(ending_raw))
    os.exit(1)
end

if end_seconds <= start_seconds then
    print("ERROR: --end must be greater than --start.")
    os.exit(1)
end

local source_check = io.open(input_path, "rb")
if not source_check then
    print("ERROR: Input video not found: " .. input_path)
    os.exit(1)
end
source_check:close()

if not output_path then
    local dir, file = split_path(input_path)
    local stem, ext = split_ext(file)
    local suffix = ext ~= "" and ("." .. ext) or ""
    output_path = dir .. stem .. " - Sermon" .. suffix
end

local start_ff = format_time(start_seconds)
local duration_ff = format_time(end_seconds - start_seconds)
local end_ff = format_time(end_seconds)

if not command_succeeds("ffmpeg -version >/dev/null 2>&1") then
    print("ERROR: ffmpeg is required but was not found in PATH.")
    os.exit(1)
end

local cmd_parts
if use_copy then
    cmd_parts = {
        "ffmpeg -y",
        "-ss " .. start_ff,
        "-i " .. shell_quote(input_path),
        "-t " .. duration_ff,
        "-c copy",
        shell_quote(output_path)
    }
else
    cmd_parts = {
        "ffmpeg -y",
        "-ss " .. start_ff,
        "-i " .. shell_quote(input_path),
        "-t " .. duration_ff,
        "-c:v libx264 -crf 18 -preset medium",
        "-c:a aac -b:a 192k",
        shell_quote(output_path)
    }
end
local cmd = table.concat(cmd_parts, " ")

print("Exporting sermon clip...")
print("Input:  " .. input_path)
print("Start:  " .. start_ff)
print("End:    " .. end_ff)
print("Output: " .. output_path)
print("Mode:   " .. (use_copy and "stream copy (fast, less precise)" or "re-encode (accurate boundaries)"))
print("")
print("Command: " .. cmd)
print("")

if not command_succeeds(cmd) then
    print("ERROR: ffmpeg export failed.")
    os.exit(1)
end

print("Done.")
