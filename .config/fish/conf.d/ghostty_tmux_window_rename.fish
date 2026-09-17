if status is-interactive
    function __ghostty_tmux_window_rename_on_prompt --on-event fish_prompt
        __rename_tmux_window_ghostty
    end
end
