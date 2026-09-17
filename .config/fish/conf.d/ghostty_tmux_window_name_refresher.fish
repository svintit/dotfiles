if status is-interactive
    function __ghostty_tmux_window_name_refresher_on_prompt --on-event fish_prompt
        __ensure_tmux_window_name_refresher_ghostty
    end
end
