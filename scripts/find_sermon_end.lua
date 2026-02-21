#!/usr/bin/env lua
--[[
    find_sermon_end.lua

    Scan a WebVTT file and print the last cue end time that matches
    sermon end markers (manual or auto).

    Usage:
        lua find_sermon_end.lua <vtt_file> [--markers "a|b|c"] [--auto] [--case-sensitive] [--all]
--]]

local function usage()
    print("Usage: lua find_sermon_end.lua <vtt_file> [--markers \"a|b|c\"] [--auto] [--case-sensitive] [--all]")
end

local function normalize_spaces(text)
    return (text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split_markers(raw)
    local markers = {}
    for piece in raw:gmatch("[^|]+") do
        local trimmed = piece:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" then
            table.insert(markers, trimmed)
        end
    end
    return markers
end

local default_markers = {
    "[sermon end]",
    "sermon end",
    "sermon ends",
    "end of sermon",
    "closing prayer",
    "benediction"
}

local auto_markers = {
    "amen",
    "let's pray",
    "let us pray",
    "please stand",
    "we are dismissed",
    "we're dismissed",
    "go in peace"
}

local case_sensitive = false
local include_auto = false
local print_all = false
local override_markers = nil
local vtt_path = nil

local i = 1
while i <= #arg do
    local value = arg[i]
    if value == "--case-sensitive" then
        case_sensitive = true
    elseif value == "--auto" then
        include_auto = true
    elseif value == "--all" then
        print_all = true
    elseif value == "--markers" then
        i = i + 1
        if not arg[i] then
            print("ERROR: --markers requires a value.")
            usage()
            os.exit(1)
        end
        override_markers = arg[i]
    elseif not vtt_path then
        vtt_path = value
    else
        print("ERROR: Unexpected argument: " .. value)
        usage()
        os.exit(1)
    end
    i = i + 1
end

if not vtt_path then
    usage()
    os.exit(1)
end

local markers = {}
if override_markers then
    markers = split_markers(override_markers)
else
    for _, marker in ipairs(default_markers) do
        table.insert(markers, marker)
    end
    if include_auto then
        for _, marker in ipairs(auto_markers) do
            table.insert(markers, marker)
        end
    end
end

if #markers == 0 then
    print("ERROR: No markers configured.")
    os.exit(1)
end

local file, err = io.open(vtt_path, "r")
if not file then
    print("ERROR: Unable to open file: " .. tostring(err))
    os.exit(1)
end

local lowered_markers = {}
if not case_sensitive then
    for _, marker in ipairs(markers) do
        table.insert(lowered_markers, marker:lower())
    end
else
    lowered_markers = markers
end

local cue_end = nil
local cue_text = {}
local matches = 0
local last_match_end = nil
local last_match_text = nil

local function cue_matches(text)
    for _, marker in ipairs(lowered_markers) do
        if text:find(marker, 1, true) then
            return true
        end
    end
    return false
end

local function flush_cue()
    if cue_end and #cue_text > 0 then
        local text = normalize_spaces(table.concat(cue_text, " "))
        local haystack = case_sensitive and text or text:lower()
        if cue_matches(haystack) then
            matches = matches + 1
            last_match_end = cue_end
            last_match_text = text
            if print_all then
                print(cue_end .. "  " .. text)
            end
        end
    end
    cue_end = nil
    cue_text = {}
end

for line in file:lines() do
    if line == "" then
        flush_cue()
    else
        local end_time = line:match("^%d%d:%d%d:%d%d%.%d%d%d%s+-->%s+(%d%d:%d%d:%d%d%.%d%d%d)")
            or line:match("^%d%d:%d%d:%d%d%s+-->%s+(%d%d:%d%d:%d%d)")
        if end_time then
            flush_cue()
            cue_end = end_time
        elseif cue_end then
            table.insert(cue_text, line)
        end
    end
end

flush_cue()
file:close()

if matches == 0 then
    print("NOT FOUND")
    os.exit(2)
end

if not print_all then
    print(last_match_end .. "  " .. last_match_text)
end
