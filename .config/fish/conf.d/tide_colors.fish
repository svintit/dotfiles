# Tide color configuration for Bearded Theme
# Powerline style with good contrast and readability

# Prompt style
set -U tide_prompt_icon_connection ' '
set -U tide_prompt_add_newline_before false
set -U tide_prompt_pad_items true

# Allow prompt to show even in narrow terminals (hide right items first)
if not set -q tide_prompt_min_cols; or test "$tide_prompt_min_cols" != "1"
    set -U tide_prompt_min_cols 1
end

# Character
set -U tide_character_color 47ff5c
set -U tide_character_color_failure ff052e
set -U tide_character_icon '❯'

# PWD/Directory - Dark text on pink/magenta (matching OS logo)
set -U tide_pwd_color_anchors 001315
set -U tide_pwd_color_dirs 001315
set -U tide_pwd_color_truncated_dirs 001315
set -U tide_pwd_bg_color f75f94

# Show full path from git root when in a git repository
# tide_pwd_markers includes .git by default, which anchors the path display

# Git - Different colors for different states (bold)
set -U tide_git_color_branch -o 001315
set -U tide_git_color_operation -o ff5792
set -U tide_git_color_staged -o 001315
set -U tide_git_color_unstaged -o 001315
set -U tide_git_color_conflicted -o ffffff
set -U tide_git_color_dirty -o 001315
set -U tide_git_color_upstream -o 001315
set -U tide_git_color_stash -o 001315
set -U tide_git_color_untracked -o 001315
set -U tide_git_bg_color 47ff5c
set -U tide_git_bg_color_unstable ffe15a
set -U tide_git_bg_color_urgent ff052e

# Git branch - dynamic truncation handled in _tide_item_git function
# Set to 0 as default (function will override based on terminal width)
if not set -q tide_git_truncation_length; or test "$tide_git_truncation_length" != "0"
    set -U tide_git_truncation_length 0
end

# Status - Green/Red based on success
set -U tide_status_color 001315
set -U tide_status_color_failure ffffff
set -U tide_status_bg_color 47ff5c
set -U tide_status_bg_color_failure ff052e

# Command duration - Yellow
set -U tide_cmd_duration_color 001315
set -U tide_cmd_duration_bg_color ffe15a

# Time - Magenta
set -U tide_time_color 001315
set -U tide_time_bg_color f75f94

# Jobs - Cyan
set -U tide_jobs_color 001315
set -U tide_jobs_bg_color 81f0fe

# Context (user@host)
set -U tide_context_color_default 001315
set -U tide_context_color_root ffffff
set -U tide_context_color_ssh 001315
set -U tide_context_bg_color 81f0fe

# OS icon - Pink (bold)
set -U tide_os_color -o 001315
set -U tide_os_bg_color f75f94

# Node - Green
set -U tide_node_bg_color 47ff5c
set -U tide_node_color 000000

# Ruby - Red
set -U tide_ruby_bg_color ff052e
set -U tide_ruby_color 000000

# Nix shell - Yellow
set -U tide_nix_shell_bg_color ffe15a
set -U tide_nix_shell_color 000000

# Direnv - Yellow
set -U tide_direnv_bg_color ffe15a
set -U tide_direnv_color 000000
