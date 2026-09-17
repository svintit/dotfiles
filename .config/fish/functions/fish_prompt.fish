functions -e _add_newline 2>/dev/null
set -g __fish_prompt_needs_newline 1
function __fish_prompt_mark_newline --on-event fish_preexec
    set -g __fish_prompt_needs_newline 1
end
function fish_prompt
    if set -q __fish_prompt_needs_newline
        echo
        set -e __fish_prompt_needs_newline
    end
    # Colors
    set -l user_color 'ff5c8d'    # coral/red (same as chev1)
    set -l path_color 'ffcc66'    # yellow (same as chev2)
    set -l chev1_color 'ff5c8d'   # coral/red (color1)
    set -l chev2_color 'ffcc66'   # yellow (color3)
    set -l chev3_color '5ed47a'   # green (color10)

    # Repo name (only if in git repo)
    set -l branch (git symbolic-ref --short HEAD 2>/dev/null)
    if test -n "$branch"
        set -l remote_url (git remote get-url origin 2>/dev/null)
        set -l repo_name (string replace -r '.*[:/]([^/]+?)(?:\.git)?$' '$1' -- "$remote_url" | string replace -r '\.git$' '')
        # Fallback to directory name if no origin remote
        if test -z "$repo_name"
            set repo_name (basename (git rev-parse --show-toplevel 2>/dev/null) | string replace -r '\.git$' '')
        end
        if test -n "$repo_name"
            set_color $user_color
            echo -n $repo_name
            # Separator
            set_color 'c792ea'  # vibrant purple
            echo -n ' :: '
        end
    end

    # Path display
    set_color $path_color
    set -l dir_name
    if test "$PWD" = "$HOME"
        set dir_name '~'
    else
        set dir_name (string replace "$HOME" '~' -- $PWD)
    end
    echo -n $dir_name

    # Space
    set_color normal
    echo -n ' '

    # Gradient chevrons
    set_color $chev1_color
    echo -n '⟩'
    set_color $chev2_color
    echo -n '⟩'
    set_color $chev3_color
    echo -n '⟩'

    # Reset and trailing space
    set_color normal
    echo -n ' '
end

function fish_right_prompt
    set -l branch (git symbolic-ref --short HEAD 2>/dev/null)
    if test -n "$branch"
        set_color 'c792ea'  # vibrant purple
        echo -n '  '
        echo -n \uf418' '
        set_color 'ffffff'  # branch name in white
        echo -n $branch
        set_color normal
    end
end
