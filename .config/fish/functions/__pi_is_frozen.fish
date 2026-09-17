function __pi_is_frozen --description 'True if the current tmux pane holds a frozen pi/omp session'
    status is-interactive; or return 1
    set -q TMUX_PANE; or return 1
    test "$(tmux show-option -pqv -t $TMUX_PANE @pi_freeze_state)" = frozen
end
