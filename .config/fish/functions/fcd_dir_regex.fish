function fcd_dir_regex -d "Construct regex from multiple directory arguments"
    set -l regex ""
    for arg in $argv
        set -l part (printf '%s' $arg | sed -E 's/(.)/\1[^\/]*/g')
        if test -z "$regex"
            set regex "$part"
        else
            set regex "$regex/.*$part"
        end
    end
    echo $regex
end
