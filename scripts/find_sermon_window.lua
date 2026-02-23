#!/usr/bin/env lua
--[[
    find_sermon_window.lua

    Detect sermon start/end from a WebVTT file by bracketing the sermon
    between an initial prayer and a closing prayer, then finding a sermon
    marker after the initial prayer.

    Usage:
      lua find_sermon_window.lua <vtt_file>
        [--start-markers "a|b|c"]
        [--prayer-start-markers "a|b|c"]
        [--prayer-end-markers "a|b|c"]
        [--case-sensitive]
        [--debug]
--]]

local function usage()
    print("Usage: lua find_sermon_window.lua <vtt_file> [--start-markers \"a|b|c\"] [--prayer-start-markers \"a|b|c\"] [--prayer-end-markers \"a|b|c\"] [--closing-prayer-min-ratio <0-1>] [--closing-prayer-max-gap-seconds <seconds>] [--music-marker-window-seconds <seconds>] [--secondary-prayer-max-gap-seconds <seconds>] [--min-sermon-seconds <seconds>] [--case-sensitive] [--debug]")
end

local function normalize_spaces(text)
    return (text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function strip_tags(text)
    return text:gsub("<[^>]+>", "")
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

local function parse_time(raw)
    local h, m, s, ms = raw:match("^(%d+):(%d%d):(%d%d)%.(%d%d%d)$")
    if h then
        return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) + tonumber(ms) / 1000
    end
    h, m, s = raw:match("^(%d+):(%d%d):(%d%d)$")
    if h then
        return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
    end
    return nil
end

local function format_time(seconds)
    local whole = math.floor(seconds)
    local ms = math.floor((seconds - whole) * 1000 + 0.5)
    if ms == 1000 then
        whole = whole + 1
        ms = 0
    end
    local h = math.floor(whole / 3600)
    local m = math.floor((whole % 3600) / 60)
    local s = whole % 60
    return string.format("%02d:%02d:%02d.%03d", h, m, s, ms)
end

local default_sermon_markers = {
    "sermon",
    "message",
    "open your bibles",
    "if you have your bibles",
    "turn with me",
    "turn to",
    "scripture",
    "chapter",
    "verse"
}

local bible_books = {
    "genesis", "exodus", "leviticus", "numbers", "deuteronomy",
    "joshua", "judges", "ruth", "1 samuel", "2 samuel",
    "1 kings", "2 kings", "1 chronicles", "2 chronicles", "ezra", "nehemiah",
    "esther", "psalm", "psalms", "proverbs", "ecclesiastes", "song of solomon",
    "isaiah", "jeremiah", "lamentations", "ezekiel", "daniel",
    "hosea", "joel", "amos", "obadiah", "jonah", "micah", "nahum", "habakkuk",
    "zephaniah", "haggai", "zechariah", "malachi",
    "matthew", "luke", "acts", "romans",
    "1 corinthians", "2 corinthians", "galatians", "ephesians", "philippians",
    "colossians", "1 thessalonians", "2 thessalonians", "1 timothy", "2 timothy",
    "titus", "philemon", "hebrews", "james", "1 peter", "2 peter",
    "1 john", "2 john", "3 john", "jude", "revelation"
}

local default_prayer_start_markers = {
    "let's pray",
    "let us pray",
    "please pray",
    "join me in prayer"
}

local default_prayer_end_markers = {
    "amen"
}

local case_sensitive = false
local debug = false
local closing_prayer_min_ratio = 0.7
local closing_prayer_max_gap_seconds = 300
local music_marker_window_seconds = 600
local secondary_prayer_max_gap_seconds = 180
local min_sermon_seconds = 600
local override_sermon_markers = nil
local override_prayer_start_markers = nil
local override_prayer_end_markers = nil
local vtt_path = nil

local i = 1
while i <= #arg do
    local value = arg[i]
    if value == "--case-sensitive" then
        case_sensitive = true
    elseif value == "--debug" then
        debug = true
    elseif value == "--closing-prayer-min-ratio" then
        i = i + 1
        local ratio = tonumber(arg[i])
        if not ratio or ratio <= 0 or ratio >= 1 then
            print("ERROR: --closing-prayer-min-ratio must be between 0 and 1.")
            usage()
            os.exit(1)
        end
        closing_prayer_min_ratio = ratio
    elseif value == "--closing-prayer-max-gap-seconds" then
        i = i + 1
        local gap = tonumber(arg[i])
        if not gap or gap <= 0 then
            print("ERROR: --closing-prayer-max-gap-seconds must be greater than 0.")
            usage()
            os.exit(1)
        end
        closing_prayer_max_gap_seconds = gap
    elseif value == "--music-marker-window-seconds" then
        i = i + 1
        local window = tonumber(arg[i])
        if not window or window <= 0 then
            print("ERROR: --music-marker-window-seconds must be greater than 0.")
            usage()
            os.exit(1)
        end
        music_marker_window_seconds = window
    elseif value == "--secondary-prayer-max-gap-seconds" then
        i = i + 1
        local window = tonumber(arg[i])
        if not window or window <= 0 then
            print("ERROR: --secondary-prayer-max-gap-seconds must be greater than 0.")
            usage()
            os.exit(1)
        end
        secondary_prayer_max_gap_seconds = window
    elseif value == "--min-sermon-seconds" then
        i = i + 1
        local window = tonumber(arg[i])
        if not window or window <= 0 then
            print("ERROR: --min-sermon-seconds must be greater than 0.")
            usage()
            os.exit(1)
        end
        min_sermon_seconds = window
    elseif value == "--start-markers" then
        i = i + 1
        if not arg[i] then
            print("ERROR: --start-markers requires a value.")
            usage()
            os.exit(1)
        end
        override_sermon_markers = arg[i]
    elseif value == "--prayer-start-markers" then
        i = i + 1
        if not arg[i] then
            print("ERROR: --prayer-start-markers requires a value.")
            usage()
            os.exit(1)
        end
        override_prayer_start_markers = arg[i]
    elseif value == "--prayer-end-markers" then
        i = i + 1
        if not arg[i] then
            print("ERROR: --prayer-end-markers requires a value.")
            usage()
            os.exit(1)
        end
        override_prayer_end_markers = arg[i]
    elseif not vtt_path then
        vtt_path = value
    else
        print("ERROR: Unexpected argument: " .. tostring(value))
        usage()
        os.exit(1)
    end
    i = i + 1
end

if not vtt_path then
    usage()
    os.exit(1)
end

local sermon_markers = {}
if override_sermon_markers then
    sermon_markers = split_markers(override_sermon_markers)
else
    for _, marker in ipairs(default_sermon_markers) do
        table.insert(sermon_markers, marker)
    end
    for _, book in ipairs(bible_books) do
        table.insert(sermon_markers, book)
    end
end

local prayer_start_markers = override_prayer_start_markers and split_markers(override_prayer_start_markers) or default_prayer_start_markers
local prayer_end_markers = override_prayer_end_markers and split_markers(override_prayer_end_markers) or default_prayer_end_markers

local function normalize_markers(markers)
    if case_sensitive then
        return markers
    end
    local lowered = {}
    for _, marker in ipairs(markers) do
        table.insert(lowered, marker:lower())
    end
    return lowered
end

local lowered_sermon_markers = normalize_markers(sermon_markers)
local lowered_prayer_start_markers = normalize_markers(prayer_start_markers)
local lowered_prayer_end_markers = normalize_markers(prayer_end_markers)
local sermon_patterns = {
    "john%s+%d",
    "mark%s+%d",
    "job%s+%d"
}
local secondary_prayer_start_markers = normalize_markers({
    "would you pray",
    "pray with me",
    "as we pray"
})

local greeting_markers = normalize_markers({
    "good morning",
    "good afternoon",
    "good evening",
    "welcome"
})

local music_markers = normalize_markers({
    "let's stand",
    "please stand",
    "stand and",
    "let's sing",
    "sing together",
    "we're going to sing",
    "worship",
    "song",
    "[music]"
})

local broad_prayer_markers = normalize_markers({
    "father",
    "lord",
    "heavenly father",
    "god",
    "we pray"
})

local end_transition_markers = normalize_markers({
    "let's stand",
    "please stand",
    "let's sing",
    "sing together",
    "time of response",
    "time to respond",
    "respond in worship",
    "respond in this time",
    "would you just respond"
})

local strong_end_transition_markers = normalize_markers({
    "let's stand",
    "please stand",
    "let's sing",
    "sing together",
    "time of response",
    "time to respond",
    "respond in worship",
    "respond in this time",
    "would you just respond"
})

local function text_has_marker(text, markers)
    for _, marker in ipairs(markers) do
        if marker:find("%s") then
            if text:find(marker, 1, true) then
                return true
            end
        else
            local pattern = "%f[%a]" .. marker:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1") .. "%f[%A]"
            if text:find(pattern) then
                return true
            end
        end
    end
    return false
end

local function text_has_pattern(text, patterns)
    for _, pattern in ipairs(patterns) do
        if text:find(pattern) then
            return true
        end
    end
    return false
end

local file, err = io.open(vtt_path, "r")
if not file then
    print("ERROR: Unable to open file: " .. tostring(err))
    os.exit(1)
end

local cues = {}
local cue_start = nil
local cue_end = nil
local cue_text = {}

local function flush_cue()
    if cue_start and cue_end and #cue_text > 0 then
        local raw_text = normalize_spaces(strip_tags(table.concat(cue_text, " ")))
        if raw_text ~= "" then
            local haystack = case_sensitive and raw_text or raw_text:lower()
            table.insert(cues, {
                start = cue_start,
                ["end"] = cue_end,
                text = raw_text,
                haystack = haystack
            })
        end
    end
    cue_start = nil
    cue_end = nil
    cue_text = {}
end

for line in file:lines() do
    if line == "" then
        flush_cue()
    else
        local start_raw, end_raw = line:match("^(%d%d:%d%d:%d%d%.%d%d%d)%s+-->%s+(%d%d:%d%d:%d%d%.%d%d%d)")
        if not start_raw then
            start_raw, end_raw = line:match("^(%d%d:%d%d:%d%d)%s+-->%s+(%d%d:%d%d:%d%d)")
        end
        if start_raw and end_raw then
            flush_cue()
            cue_start = parse_time(start_raw)
            cue_end = parse_time(end_raw)
        elseif cue_start then
            table.insert(cue_text, line)
        end
    end
end

flush_cue()
file:close()

if #cues == 0 then
    print("ERROR: No cues found in VTT.")
    os.exit(2)
end

local function last_marker_before(index, markers, max_gap_seconds)
    local ref_time = cues[index].start
    for j = index - 1, 1, -1 do
        if max_gap_seconds and (ref_time - cues[j].start) > max_gap_seconds then
            break
        end
        if text_has_marker(cues[j].haystack, markers) then
            return j
        end
    end
    return nil
end

local function has_marker(text, markers)
    return text_has_marker(text, markers)
end

local function choose_sermon_marker()
    local candidates = {}
    for idx, cue in ipairs(cues) do
        if text_has_marker(cue.haystack, lowered_sermon_markers) or text_has_pattern(cue.haystack, sermon_patterns) then
            table.insert(candidates, idx)
        end
    end

    if #candidates == 0 then
        return nil
    end

    local total_duration = cues[#cues]["end"]
    local min_ratio = 0.12
    local hard_min_ratio = 0.08
    local max_ratio = 0.85
    local strong_sermon_markers = normalize_markers({"sermon", "message"})

    local function find_opening_prayer_end()
        local max_opening_ratio = 0.6
        local max_prayer_length_seconds = 240
        local max_music_gap_seconds = 1200
        local early_ratio = 0.25

        for idx = 1, #cues do
            if cues[idx].start > total_duration * max_opening_ratio then
                break
            end
            if text_has_marker(cues[idx].haystack, lowered_prayer_start_markers) then
                local last_music = last_marker_before(idx, music_markers, max_music_gap_seconds)
                if last_music or (cues[idx].start / total_duration) < early_ratio then
                    for j = idx + 1, #cues do
                        if (cues[j].start - cues[idx].start) > max_prayer_length_seconds then
                            break
                        end
                        if text_has_marker(cues[j].haystack, lowered_prayer_end_markers) then
                            return j
                        end
                    end
                end
            end
        end
        return nil
    end

    local opening_prayer_end = find_opening_prayer_end()
    if opening_prayer_end then
        local max_gap_seconds = 600
        for _, idx in ipairs(candidates) do
            if idx > opening_prayer_end then
                local gap = cues[idx].start - cues[opening_prayer_end].start
                local ratio = cues[idx].start / total_duration
                if gap <= max_gap_seconds and ratio <= max_ratio then
                    if debug then
                        print("DEBUG opening_prayer_end_index=" .. opening_prayer_end .. " text=" .. cues[opening_prayer_end].text)
                    end
                    return idx
                end
            end
        end
    end

    local best_index = nil
    local best_score = -9999
    for _, idx in ipairs(candidates) do
        local cue = cues[idx]
        local score = 0
        local ratio = cue.start / total_duration

        if ratio < hard_min_ratio then
            score = score - 6
        elseif ratio < min_ratio then
            score = score - 3
        else
            score = score + 1
        end

        if ratio > 0.9 then
            score = score - 4
        elseif ratio > max_ratio then
            score = score - 2
        end

        local last_prayer_end = last_marker_before(idx, lowered_prayer_end_markers, 300)
        if last_prayer_end then
            score = score + 3
        end

        local last_prayer_start = last_marker_before(idx, lowered_prayer_start_markers, 600)
        if last_prayer_start then
            score = score + 2
        end

        local last_music = last_marker_before(idx, music_markers, 1200)
        if last_music then
            score = score + 1
        end

        if has_marker(cue.haystack, strong_sermon_markers) then
            score = score + 2
        end

        if score > best_score or (score == best_score and (not best_index or cues[idx].start > cues[best_index].start)) then
            best_score = score
            best_index = idx
        end
    end

    if debug and best_index then
        print("DEBUG best_sermon_score=" .. best_score .. " candidate_count=" .. #candidates)
    end

    return best_index
end

local sermon_marker_index = choose_sermon_marker()

if not sermon_marker_index then
    print("ERROR: No sermon markers found.")
    os.exit(3)
end

local prayer_start_index = nil
for idx = sermon_marker_index, 1, -1 do
    if text_has_marker(cues[idx].haystack, lowered_prayer_start_markers) then
        prayer_start_index = idx
        break
    end
end

local prayer_end_index = nil
if prayer_start_index then
    for idx = prayer_start_index + 1, sermon_marker_index do
        if text_has_marker(cues[idx].haystack, lowered_prayer_end_markers) then
            prayer_end_index = idx
            break
        end
    end
else
    for idx = sermon_marker_index, 1, -1 do
        if text_has_marker(cues[idx].haystack, lowered_prayer_end_markers) then
            prayer_end_index = idx
            break
        end
    end
end

local function strip_leading_filler(text)
    local cleaned = text:gsub("^%s+", "")
    cleaned = cleaned:gsub("^>+%s*", "")
    cleaned = cleaned:gsub("^%p+%s*", "")

    local filler_patterns = {
        "^(um)%s+",
        "^(uh)%s+",
        "^(well)%s+",
        "^(alright)%s+",
        "^(all%s+right)%s+",
        "^(okay)%s+",
        "^(ok)%s+",
        "^(so)%s+"
    }

    for _ = 1, 3 do
        local before = cleaned
        for _, pattern in ipairs(filler_patterns) do
            cleaned = cleaned:gsub(pattern, "")
        end
        cleaned = cleaned:gsub("^%p+%s*", "")
        if cleaned == before then
            break
        end
    end
    return cleaned
end

local function cue_starts_with_greeting(haystack)
    local cleaned = strip_leading_filler(haystack)
    for _, marker in ipairs(greeting_markers) do
        if cleaned:find(marker, 1, true) == 1 then
            return true
        end
    end
    return false
end

local function adjust_start_to_greeting(base_index)
    local base_time = cues[base_index].start
    local max_greeting_gap_seconds = 180

    local max_index = math.min(#cues, base_index + 250)
    local greeting_index = nil

    for idx = base_index, max_index do
        if (cues[idx].start - base_time) > max_greeting_gap_seconds then
            break
        end
        if cue_starts_with_greeting(cues[idx].haystack) then
            greeting_index = idx
            break
        end
    end

    if not greeting_index then
        for idx = base_index, max_index do
            if (cues[idx].start - base_time) > max_greeting_gap_seconds then
                break
            end
            if text_has_marker(cues[idx].haystack, greeting_markers) then
                greeting_index = idx
                break
            end
        end
    end

    if greeting_index and greeting_index ~= base_index then
        if debug then
            print("DEBUG greeting_start_index=" .. greeting_index .. " text=" .. cues[greeting_index].text)
        end
        return greeting_index
    end

    return base_index
end

local sermon_start_index = nil
if prayer_end_index then
    local base_index = math.min(prayer_end_index + 1, #cues)
    sermon_start_index = adjust_start_to_greeting(base_index)
else
    sermon_start_index = sermon_marker_index
end

local sermon_start_time = cues[sermon_start_index].start
local closing_prayer_index = nil
local total_duration = cues[#cues]["end"]
local closing_prayer_min_time = total_duration * closing_prayer_min_ratio
local min_end_time = sermon_start_time + min_sermon_seconds
for idx = sermon_start_index, #cues do
    if cues[idx].start >= min_end_time
        and text_has_marker(cues[idx].haystack, end_transition_markers) then
        if cues[idx].start < closing_prayer_min_time
            and text_has_marker(cues[idx].haystack, {"music"})
            and not text_has_marker(cues[idx].haystack, strong_end_transition_markers) then
            goto continue_end_transition
        end
        closing_prayer_index = idx
        break
    end
    ::continue_end_transition::
end
local first_music_index = nil
if not closing_prayer_index then
    for idx = sermon_start_index, #cues do
        if text_has_marker(cues[idx].haystack, music_markers) then
            first_music_index = idx
            break
        end
    end
end

if first_music_index and not closing_prayer_index then
    local min_prayer_time = cues[first_music_index].start - music_marker_window_seconds
    for idx = first_music_index, sermon_start_index, -1 do
        if cues[idx].start < min_prayer_time then
            break
        end
        if text_has_marker(cues[idx].haystack, lowered_prayer_start_markers)
            or text_has_marker(cues[idx].haystack, secondary_prayer_start_markers) then
            closing_prayer_index = idx
            break
        end
    end
end

local last_prayer_end_index = nil
if not closing_prayer_index then
    local amen_with_music_index = nil
    for idx = sermon_start_index, #cues do
        if text_has_marker(cues[idx].haystack, lowered_prayer_end_markers) then
            local window_end = cues[idx].start + music_marker_window_seconds
            for j = idx + 1, #cues do
                if cues[j].start > window_end then
                    break
                end
                if text_has_marker(cues[j].haystack, music_markers) then
                    amen_with_music_index = idx
                    break
                end
            end
            if amen_with_music_index then
                break
            end
        end
    end

    if amen_with_music_index then
        local min_start_time = cues[amen_with_music_index].start - closing_prayer_max_gap_seconds
        for idx = amen_with_music_index, sermon_start_index, -1 do
            if cues[idx].start < min_start_time then
                break
            end
            if text_has_marker(cues[idx].haystack, lowered_prayer_start_markers)
                or text_has_marker(cues[idx].haystack, secondary_prayer_start_markers)
                or text_has_marker(cues[idx].haystack, broad_prayer_markers) then
                closing_prayer_index = idx
                break
            end
        end
        if not closing_prayer_index then
            closing_prayer_index = amen_with_music_index
        end
    end

    for idx = #cues, sermon_start_index, -1 do
        if cues[idx].start >= closing_prayer_min_time
            and text_has_marker(cues[idx].haystack, lowered_prayer_end_markers) then
            last_prayer_end_index = idx
            break
        end
    end

    if last_prayer_end_index then
        local min_start_time = cues[last_prayer_end_index].start - closing_prayer_max_gap_seconds
        for idx = last_prayer_end_index, sermon_start_index, -1 do
            if cues[idx].start < min_start_time then
                break
            end
            if text_has_marker(cues[idx].haystack, lowered_prayer_start_markers) then
                closing_prayer_index = idx
                break
            end
        end
        if not closing_prayer_index then
            for idx = last_prayer_end_index, sermon_start_index, -1 do
                if cues[idx].start < min_start_time
                    or (cues[last_prayer_end_index].start - cues[idx].start) > secondary_prayer_max_gap_seconds then
                    break
                end
                if text_has_marker(cues[idx].haystack, secondary_prayer_start_markers) then
                    closing_prayer_index = idx
                    break
                end
            end
        end
        if not closing_prayer_index then
            closing_prayer_index = last_prayer_end_index
        end
    else
        for idx = #cues, sermon_start_index, -1 do
            if cues[idx].start >= closing_prayer_min_time
                and text_has_marker(cues[idx].haystack, lowered_prayer_start_markers) then
                closing_prayer_index = idx
                break
            end
        end
    end
end

local sermon_end_time = nil

if closing_prayer_index and closing_prayer_index > sermon_start_index then
    sermon_end_time = cues[closing_prayer_index].start
else
    sermon_end_time = cues[#cues]["end"]
end

if debug then
    print("DEBUG sermon_marker_index=" .. sermon_marker_index .. " text=" .. cues[sermon_marker_index].text)
    if prayer_start_index then
        print("DEBUG prayer_start_index=" .. prayer_start_index .. " text=" .. cues[prayer_start_index].text)
    end
    if prayer_end_index then
        print("DEBUG prayer_end_index=" .. prayer_end_index .. " text=" .. cues[prayer_end_index].text)
    end
    if closing_prayer_index then
        print("DEBUG closing_prayer_index=" .. closing_prayer_index .. " text=" .. cues[closing_prayer_index].text)
    end
end

print("START " .. format_time(sermon_start_time))
print("END " .. format_time(sermon_end_time))
