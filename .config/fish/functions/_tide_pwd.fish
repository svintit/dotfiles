set_color -o $tide_pwd_color_anchors | read -l color_anchors
set_color $tide_pwd_color_truncated_dirs | read -l color_truncated
set -l reset_to_color_dirs (set_color normal -b $tide_pwd_bg_color; set_color $tide_pwd_color_dirs)

set -l unwritable_icon $tide_pwd_icon_unwritable' '
set -l home_icon $tide_pwd_icon_home' '
set -l pwd_icon $tide_pwd_icon' '

eval "function _tide_pwd
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)

    if test -n \"\$git_root\"
        set -l dir_name (basename \$PWD)
        echo -ns \"$reset_to_color_dirs$pwd_icon $color_anchors\$dir_name\"
        string length -V -- \"$pwd_icon \$dir_name\" | read -g _tide_pwd_len
    else
        set -l path_to_display (string replace -r '^$HOME' '~' -- \$PWD)

        if set -l split_pwd (string split / -- \$path_to_display)
            test -w . && set -f split_output \"$pwd_icon\$split_pwd[1]\" \$split_pwd[2..] ||
                set -f split_output \"$unwritable_icon\$split_pwd[1]\" \$split_pwd[2..]
            set split_output[-1] \"$color_anchors\$split_output[-1]$reset_to_color_dirs\"
        else
            set -f split_output \"$home_icon$color_anchors~\"
        end

        string join / -- \$split_output | string length -V | read -g _tide_pwd_len

        i=1 for dir_section in \$split_pwd[2..-2]
            string join -- / \$split_pwd[..\$i] | string replace '~' $HOME | read -l parent_dir

            math \$i+1 | read i

            if path is \$parent_dir/\$dir_section/\$tide_pwd_markers
                set split_output[\$i] \"$color_anchors\$dir_section$reset_to_color_dirs\"
            else if test \$_tide_pwd_len -gt \$dist_btwn_sides
                string match -qr \"(?<trunc>\..|.)\" \$dir_section

                set -l glob \$parent_dir/\$trunc*/
                set -e glob[(contains -i \$parent_dir/\$dir_section/ \$glob)]

                while string match -qr \"^\$parent_dir/\$(string escape --style=regex \$trunc)\" \$glob &&
                        string match -qr \"(?<trunc>\$(string escape --style=regex \$trunc).)\" \$dir_section
                end
                test -n \"\$trunc\" && set split_output[\$i] \"$color_truncated\$trunc$reset_to_color_dirs\" &&
                    string join / \$split_output | string length -V | read _tide_pwd_len
            end
        end

        string join -- / \"$reset_to_color_dirs\$split_output[1]\" \$split_output[2..]
    end
end"
