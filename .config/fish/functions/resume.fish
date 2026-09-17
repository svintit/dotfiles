function resume --description 'Resume the last OMP session in this tmux pane'
    __omp_resume_once; or return $status
    __pi_freeze_prompt
end
