function v --description "Launch vim with assistant sidebar toggled"
    if set -q GHOSTTY_TMUX_PARITY; and set -q TMUX
        $HOME/.local/bin/tmux-toggle-assistant-pane-ghostty claude 35 3 >/dev/null 2>&1
        nvim $argv
        $HOME/.local/bin/tmux-toggle-assistant-pane-ghostty claude 35 3 >/dev/null 2>&1
        return
    end

    nvim $argv
end
