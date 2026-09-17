function __omp_resume_once --description 'Resume the saved OMP session once'
    if not set -q TMUX_PANE
        echo 'resume: this shell is not inside tmux' >&2
        return 1
    end

    set -l session_id (tmux show-option -pqv -t "$TMUX_PANE" @pi_freeze_resume_id)
    if test -z "$session_id"
        echo 'resume: no OMP session is saved for this tmux pane' >&2
        return 1
    end

    tmux set-option -p -t "$TMUX_PANE" @pi_freeze_state resuming
    tmux set-option -p -t "$TMUX_PANE" @pi_freeze_resume_started (math (date +%s) \* 1000)

    command omp-resume-spinner &
    set -l spinner_pid $last_pid
    disown $spinner_pid

    set -l freeze_cwd (tmux show-option -pqv -t "$TMUX_PANE" @pi_freeze_cwd)
    if test -n "$freeze_cwd"
        command omp --cwd "$freeze_cwd" --resume "$session_id"
    else
        command omp --resume "$session_id"
    end
    set -l resume_status $status

    kill $spinner_pid 2>/dev/null
    printf '\r\033[2K'
    return $resume_status
end
