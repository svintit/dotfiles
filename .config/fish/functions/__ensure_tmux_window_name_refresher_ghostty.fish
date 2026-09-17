function __ensure_tmux_window_name_refresher_ghostty --description 'Ensure Ghostty tmux window-name refresher is running'
    if not set -q GHOSTTY_TMUX_PARITY; or not set -q TMUX
        return
    end

    set -l sock ghostty-main
    set -l script $HOME/.local/bin/tmux-refresh-window-names-ghostty

    if test -x $script
        fish -c "$script $sock >/dev/null 2>&1" &
        disown
    end
end
