function set_wallpaper --description "Replace Apple video wallpaper with custom video"
    set -l source_file ~/Movies/wallpaper.mov
    set -l wallpaper_dir ~/Library/Application\ Support/com.apple.wallpaper/aerials/videos
    set -l target_file "$wallpaper_dir/44166C39-8566-4ECA-BD16-43159429B52F.mov"

    # Check if source file exists
    if not test -f "$source_file"
        echo "Error: Source file not found: $source_file"
        return 1
    end

    # Check if wallpaper directory exists
    if not test -d "$wallpaper_dir"
        echo "Error: Wallpaper directory not found: $wallpaper_dir"
        return 1
    end

    # Backup original if it exists and no backup exists yet
    if test -f "$target_file"; and not test -f "$target_file.backup"
        echo "Creating backup of original New York Night wallpaper..."
        cp "$target_file" "$target_file.backup"
    end

    # Copy and replace the wallpaper
    echo "Replacing New York Night wallpaper with custom video..."
    cp "$source_file" "$target_file"

    if test $status -eq 0
        echo "Success! Wallpaper replaced."

        # Kill wallpaper processes to clear cache
        echo "Restarting wallpaper services..."
        killall WallpaperAerialsExtension 2>/dev/null
        killall WallpaperAgent 2>/dev/null

        echo "Done! Reselect New York Night in System Settings to see your custom wallpaper. 🌃"
    else
        echo "Error: Failed to copy wallpaper file"
        return 1
    end
end
