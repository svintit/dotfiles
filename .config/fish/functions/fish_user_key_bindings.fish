function fish_user_key_bindings --description 'Custom key bindings (word movement compatibility)'
    # Keep default bindings first
    fish_default_key_bindings

    # Meta-b / Meta-f word movement
    bind \eb backward-word
    bind \ef forward-word

    # Common Option+Arrow escape sequences from terminals
    bind \e\[1\;3D backward-word
    bind \e\[1\;3C forward-word
    bind \e\[5D backward-word
    bind \e\[5C forward-word

    # In tmux popup sessions, Cmd-w may arrive as raw Ghostty user-key bytes.
    if set -q TMUX_POPUP
        bind \e\[5\;30013~ exit
    end
end
