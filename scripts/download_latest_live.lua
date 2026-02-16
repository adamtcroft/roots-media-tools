#!/usr/bin/env lua
--[[
    download_latest_live.lua
    
    Downloads the most recent "Live" video from Roots Community Church YouTube channel.
    
    Dependencies:
        - yt-dlp (https://github.com/yt-dlp/yt-dlp)
    
    Usage:
        lua download_latest_live.lua [output_directory]
    
    Cross-platform: Works on Windows, Mac, and Linux
--]]

-- Configuration
local CHANNEL_URL = "https://www.youtube.com/@rootscommunitychurch2868"
local LIVE_PLAYLIST_URL = CHANNEL_URL .. "/streams"
local DEFAULT_OUTPUT_DIR = "media"

-- Detect operating system
local function get_os()
    local sep = package.config:sub(1, 1)
    if sep == "\\" then
        return "windows"
    else
        return "unix"  -- Linux or Mac
    end
end

-- Build the path separator for the current OS
local function path_join(...)
    local sep = get_os() == "windows" and "\\" or "/"
    local parts = {...}
    return table.concat(parts, sep)
end

local execute_command
local ytdlp_command_prefix = "yt-dlp"

local function normalize_output(output)
    return output:gsub("^%s+", ""):gsub("%s+$", "")
end

local function is_ytdlp_output_failure(output)
    return output:match("not found")
        or output:match("is not recognized")
        or output:match("Traceback")
        or output:match("ModuleNotFoundError")
end

local function get_site_package_paths()
    local paths = {}
    if get_os() ~= "unix" then
        return paths
    end

    local handle = io.popen('ls -d /usr/lib/python*/site-packages/yt_dlp 2>/dev/null')
    if not handle then
        return paths
    end

    for line in handle:lines() do
        local site_packages = line:match("^(.*)/yt_dlp$")
        if site_packages then
            table.insert(paths, site_packages)
        end
    end
    handle:close()
    return paths
end

local function build_ytdlp_candidates()
    local candidates = {"yt-dlp"}
    for _, site_packages in ipairs(get_site_package_paths()) do
        table.insert(
            candidates,
            ('PYTHONPATH="%s${PYTHONPATH:+:$PYTHONPATH}" yt-dlp'):format(site_packages)
        )
    end
    return candidates
end

-- Check if yt-dlp is available and runnable, including fallback for Python path mismatch.
local function check_ytdlp()
    for _, candidate in ipairs(build_ytdlp_candidates()) do
        local output = execute_command(candidate .. " --version 2>&1")
        if output then
            output = normalize_output(output)
            if output ~= "" and not is_ytdlp_output_failure(output) then
                return true, output, candidate
            end
        end
    end

    local output = execute_command("yt-dlp --version 2>&1")
    if not output then
        return false, "Unable to execute yt-dlp"
    end

    output = normalize_output(output)
    if output == "" then
        return false, "yt-dlp returned no output"
    end

    if is_ytdlp_output_failure(output) then
        return false, output
    end

    return true, output, "yt-dlp"
end

-- Execute a command and return stdout
execute_command = function(cmd)
    local handle = io.popen(cmd)
    if not handle then
        return nil, "Failed to execute command"
    end
    local result = handle:read("*a")
    handle:close()
    return result
end

-- Get the script's directory
local function get_script_dir()
    local info = debug.getinfo(1, "S")
    local script_path = info.source:match("@(.*)") or "."
    local dir = script_path:match("(.*/)" ) or script_path:match("(.*\\)") or "."
    return dir:sub(1, -2)  -- Remove trailing separator
end

-- Main function
local function main()
    print("=== Roots Community Church - Live Video Downloader ===\n")
    
    -- Check for yt-dlp
    local ytdlp_ok, ytdlp_details, detected_command = check_ytdlp()
    if not ytdlp_ok then
        print("ERROR: yt-dlp is not installed correctly, not in PATH, or failed to run")
        if ytdlp_details and ytdlp_details ~= "" then
            print("Details: " .. ytdlp_details)
        end
        print("")
        print("Please install yt-dlp:")
        print("  - Arch Linux: sudo pacman -S yt-dlp")
        print("  - Ubuntu/Debian: sudo apt install yt-dlp")
        print("  - macOS: brew install yt-dlp")
        print("  - Windows: winget install yt-dlp")
        print("  - Or via pip: pip install yt-dlp")
        print("")
        print("After install, verify with: yt-dlp --version")
        os.exit(1)
    end
    ytdlp_command_prefix = detected_command
    
    -- Determine output directory
    local output_dir = arg[1] or DEFAULT_OUTPUT_DIR
    local script_dir = get_script_dir()
    
    -- If output_dir is relative, make it relative to parent of script dir (repo root)
    if not output_dir:match("^[/\\]") and not output_dir:match("^%a:") then
        local repo_root = script_dir:match("(.+)[/\\]scripts$") or script_dir:match("(.+)[/\\]scripts") or "."
        output_dir = path_join(repo_root, output_dir)
    end
    
    print("Output directory: " .. output_dir)
    print("Channel: " .. CHANNEL_URL)
    print("")
    
    -- Create output directory if it doesn't exist
    local mkdir_cmd = get_os() == "windows" 
        and ('if not exist "%s" mkdir "%s"'):format(output_dir, output_dir)
        or ('mkdir -p "%s"'):format(output_dir)
    os.execute(mkdir_cmd)
    
    -- Build yt-dlp command to download the most recent live stream
    -- --playlist-items 1 gets only the most recent video
    -- -o specifies output template
    local output_template = path_join(output_dir, "%(title)s [%(id)s].%(ext)s")
    
    local ytdlp_cmd = string.format(
        '%s --playlist-items 1 -o "%s" --write-info-json --write-thumbnail "%s"',
        ytdlp_command_prefix,
        output_template,
        LIVE_PLAYLIST_URL
    )
    
    print("Downloading most recent live video...")
    print("Command: " .. ytdlp_cmd)
    print("")
    
    local result = os.execute(ytdlp_cmd)
    
    if result == 0 or result == true then
        print("")
        print("Download complete!")
        print("Check the '" .. output_dir .. "' folder for the video.")
    else
        print("")
        print("Download failed. Please check the error messages above.")
        os.exit(1)
    end
end

-- Run main
main()
