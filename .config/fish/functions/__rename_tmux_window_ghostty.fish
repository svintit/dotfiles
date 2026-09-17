function __rename_tmux_window_ghostty --description 'Rename current Ghostty tmux window'
    if not set -q GHOSTTY_TMUX_PARITY; or not set -q TMUX
        return
    end

    set -l window_id (tmux display-message -p '#{window_id}' 2>/dev/null)
    set -l current_name (tmux display-message -p '#{window_name}' 2>/dev/null)
    if test -z "$window_id"
        return
    end

    set -l next_name ($HOME/.local/bin/tmux-window-name-ghostty "$window_id" "$current_name" 2>/dev/null)
    if test -n "$next_name"; and test "$next_name" != "$current_name"
        tmux rename-window -t "$window_id" "$next_name" 2>/dev/null
    end
end
