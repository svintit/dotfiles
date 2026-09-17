function _tide_item_pwd
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
    set -l split_pwd

    if test -n "$git_root"
        set -l rel_path (string replace "$git_root/" "" -- $PWD)
        if test "$rel_path" = "$git_root"
            set rel_path (basename $git_root)
        end
        set split_pwd (string split / -- $rel_path)
    else
        set split_pwd (string replace -r "^$HOME" '~' -- $PWD | string split /)
    end

    set -l color_anchors (set_color -o $tide_pwd_color_anchors)
    set -l color_dirs (set_color normal -b $tide_pwd_bg_color; set_color $tide_pwd_color_dirs)

    set -l output
    for i in (seq (count $split_pwd))
        if test $i -eq (count $split_pwd)
            set output $output "$color_anchors$split_pwd[$i]"
        else
            set output $output "$color_dirs$split_pwd[$i]"
        end
    end

    string join / -- $output | string length -V | read -g _tide_pwd_len
    string join / -- $output
end
