function __pi_freeze_prompt --description 'While this tmux pane holds a frozen OMP session, show a resume prompt instead of a bare shell'
    functions -e __pi_freeze_watch
    functions -e __pi_redraw_frozen_splash
    function __pi_redraw_frozen_splash --on-signal WINCH
        if __pi_is_frozen
            command omp-resume-spinner --frozen
        end
    end


    while __pi_is_frozen
        if set -q TMUX_PANE
            tmux set-option -p -t "$TMUX_PANE" @pi_freeze_prompt_active "waiting:$fish_pid"
        end
        command omp-resume-spinner --frozen
        or break
        read -l -P '' -t 30 __pi_freeze_key
        set -l read_status $status
        if test $read_status -eq 124
            continue
        end
        if test $read_status -ne 0
            printf '\033[0m\033[?25h\033[?1049l'
            break
        end
        if test -z "$__pi_freeze_key"
            __omp_resume_once
            or begin
                printf '\033[0m\033[?25h\033[?1049l'
                break
            end
        end
    end
    functions -e __pi_redraw_frozen_splash

    if set -q TMUX_PANE
        tmux set-option -pu -t "$TMUX_PANE" @pi_freeze_prompt_active
    end
end
