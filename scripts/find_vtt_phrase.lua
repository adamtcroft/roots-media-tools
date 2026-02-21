#!/usr/bin/env lua
--[[
    find_vtt_phrase.lua

    Scan a WebVTT file and print cue start times where a phrase appears.

    Usage:
        lua find_vtt_phrase.lua <vtt_file> <phrase> [--case-sensitive]
--]]

local function usage()
    print("Usage: lua find_vtt_phrase.lua <vtt_file> <phrase> [--case-sensitive]")
end

local function normalize_spaces(text)
    return (text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local case_sensitive = false
local args = {}

for _, value in ipairs(arg) do
    if value == "--case-sensitive" then
        case_sensitive = true
    else
        table.insert(args, value)
    end
end

local vtt_path = args[1]
local phrase = table.concat(args, " ", 2)

if not vtt_path or phrase == "" then
    usage()
    os.exit(1)
end

local file, err = io.open(vtt_path, "r")
if not file then
    print("ERROR: Unable to open file: " .. tostring(err))
    os.exit(1)
end

local needle = case_sensitive and phrase or phrase:lower()
local cue_start = nil
local cue_text = {}

local function flush_cue()
    if cue_start and #cue_text > 0 then
        local text = normalize_spaces(table.concat(cue_text, " "))
        local haystack = case_sensitive and text or text:lower()
        if haystack:find(needle, 1, true) then
            print(cue_start .. "  " .. text)
        end
    end
    cue_start = nil
    cue_text = {}
end

for line in file:lines() do
    if line == "" then
        flush_cue()
    else
        local start_time = line:match("^(%d%d:%d%d:%d%d%.%d%d%d)%s+-->")
            or line:match("^(%d%d:%d%d:%d%d)%s+-->")
        if start_time then
            flush_cue()
            cue_start = start_time
        elseif cue_start then
            table.insert(cue_text, line)
        end
    end
end

flush_cue()
file:close()
