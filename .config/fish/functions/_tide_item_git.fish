function _tide_item_git
    git rev-parse --git-dir >/dev/null 2>&1 || return

    set -l branch (git symbolic-ref --short HEAD 2>/dev/null)
    or set branch (git rev-parse --short HEAD 2>/dev/null)
    or return

    if test -n "$branch"
        set -l pwd_len (string length -- (basename $PWD))
        set -l branch_len (string length -- $branch)
        set -l estimated_width (math "$pwd_len + $branch_len + 43")

        if test $estimated_width -gt $COLUMNS
            set -l overflow (math "$estimated_width - $COLUMNS")

            if test $overflow -gt 70
                return
            else
                set -l max_branch (math "max(30, $branch_len - $overflow + 20)")
                set branch (string shorten -m$max_branch -- $branch)
            end
        end

        set -g tide_git_bg_color $tide_git_bg_color_unstable
        set -l git_display (set_color $tide_git_color_branch; echo -ns $tide_git_icon'  '$branch)
        _tide_print_item git $git_display
    end
end
