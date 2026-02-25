#!/usr/bin/env lua
--[[
    export_sermon_clip.lua

    Export a sermon-only clip from a source video using explicit start/end times.

    Usage:
      lua export_sermon_clip.lua <input_video> --start <time> --end <time> [--output <file>] [--copy] [--fade <seconds>]
      lua export_sermon_clip.lua <input_video> --start <time> --end <time> [--output <file>] [--copy] [--fade-in <seconds>] [--fade-out <seconds>]
      lua export_sermon_clip.lua <input_video> --start <time> --end <time> [--output <file>] [--copy] [--no-fade]

    Time format:
      - HH:MM:SS
      - HH:MM:SS.mmm
      - seconds (e.g. 1384.5)
--]]

local function usage()
    print("Usage: lua export_sermon_clip.lua <input_video> --start <time> --end <time> [--output <file>] [--copy] [--fade <seconds>] [--fade-in <seconds>] [--fade-out <seconds>] [--no-fade]")
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
local fade_in_seconds = 1.0
local fade_out_seconds = 1.0
local fade_user_provided = false

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
    elseif value == "--fade" then
        i = i + 1
        local parsed = tonumber(arg[i])
        if not parsed or parsed < 0 then
            print("ERROR: Invalid --fade value: " .. tostring(arg[i]))
            os.exit(1)
        end
        fade_in_seconds = parsed
        fade_out_seconds = parsed
        fade_user_provided = true
    elseif value == "--fade-in" then
        i = i + 1
        local parsed = tonumber(arg[i])
        if not parsed or parsed < 0 then
            print("ERROR: Invalid --fade-in value: " .. tostring(arg[i]))
            os.exit(1)
        end
        fade_in_seconds = parsed
        fade_user_provided = true
    elseif value == "--fade-out" then
        i = i + 1
        local parsed = tonumber(arg[i])
        if not parsed or parsed < 0 then
            print("ERROR: Invalid --fade-out value: " .. tostring(arg[i]))
            os.exit(1)
        end
        fade_out_seconds = parsed
        fade_user_provided = true
    elseif value == "--no-fade" then
        fade_in_seconds = 0
        fade_out_seconds = 0
        fade_user_provided = true
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

local duration_seconds = end_seconds - start_seconds
if use_copy and (fade_in_seconds > 0 or fade_out_seconds > 0) then
    if fade_user_provided then
        print("ERROR: Fade in/out requires re-encode mode. Remove --copy or pass --no-fade/--fade 0.")
        os.exit(1)
    end
    fade_in_seconds = 0
    fade_out_seconds = 0
end

if not use_copy and (fade_in_seconds > 0 or fade_out_seconds > 0) then
    if fade_in_seconds > duration_seconds or fade_out_seconds > duration_seconds then
        print("ERROR: Fade durations must be <= clip duration.")
        os.exit(1)
    end
    if (fade_in_seconds + fade_out_seconds) > duration_seconds then
        print("ERROR: Fade-in + fade-out cannot exceed clip duration.")
        os.exit(1)
    end
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
local duration_ff = format_time(duration_seconds)
local end_ff = format_time(end_seconds)

if not command_succeeds("ffmpeg -version >/dev/null 2>&1") then
    print("ERROR: ffmpeg is required but was not found in PATH.")
    os.exit(1)
end

local cmd_parts
local ffmpeg_base = "ffmpeg -hide_banner -loglevel error -nostats -y"
local vf = nil
local af = nil
if not use_copy and (fade_in_seconds > 0 or fade_out_seconds > 0) then
    local function fmt_filter_seconds(value)
        return string.format("%.3f", value)
    end

    local v_filters = {}
    local a_filters = {}
    if fade_in_seconds > 0 then
        table.insert(v_filters, "fade=t=in:st=0:d=" .. fmt_filter_seconds(fade_in_seconds))
        table.insert(a_filters, "afade=t=in:st=0:d=" .. fmt_filter_seconds(fade_in_seconds))
    end
    if fade_out_seconds > 0 then
        local fade_out_start = duration_seconds - fade_out_seconds
        table.insert(v_filters, "fade=t=out:st=" .. fmt_filter_seconds(fade_out_start) .. ":d=" .. fmt_filter_seconds(fade_out_seconds))
        table.insert(a_filters, "afade=t=out:st=" .. fmt_filter_seconds(fade_out_start) .. ":d=" .. fmt_filter_seconds(fade_out_seconds))
    end

    if #v_filters > 0 then
        vf = table.concat(v_filters, ",")
    end
    if #a_filters > 0 then
        af = table.concat(a_filters, ",")
    end
end

if use_copy then
    cmd_parts = {
        ffmpeg_base,
        "-ss " .. start_ff,
        "-i " .. shell_quote(input_path),
        "-t " .. duration_ff,
        "-c copy",
        shell_quote(output_path)
    }
else
    cmd_parts = {
        ffmpeg_base,
        "-ss " .. start_ff,
        "-i " .. shell_quote(input_path),
        "-t " .. duration_ff,
        vf and ("-vf " .. shell_quote(vf)) or nil,
        af and ("-af " .. shell_quote(af)) or nil,
        "-c:v libx264 -crf 18 -preset medium",
        "-c:a aac -b:a 192k",
        shell_quote(output_path)
    }
end
local compact_parts = {}
for _, part in ipairs(cmd_parts) do
    if part ~= nil then
        table.insert(compact_parts, part)
    end
end
local cmd = table.concat(compact_parts, " ")

print("Exporting sermon clip...")
print("Input:  " .. input_path)
print("Start:  " .. start_ff)
print("End:    " .. end_ff)
print("Output: " .. output_path)
print("Mode:   " .. (use_copy and "stream copy (fast, less precise)" or "re-encode (accurate boundaries)"))
if fade_in_seconds > 0 or fade_out_seconds > 0 then
    print(string.format("Fade:   in %.3fs, out %.3fs", fade_in_seconds, fade_out_seconds))
else
    print("Fade:   none")
end
print("")

if not command_succeeds(cmd) then
    print("ERROR: ffmpeg export failed.")
    os.exit(1)
end

print("Done.")
