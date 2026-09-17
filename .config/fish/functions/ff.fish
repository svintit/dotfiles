function ff --description 'Focus aerospace window using fzf'
    aerospace list-windows --all | fzf --bind 'enter:execute(bash -c "aerospace focus --window-id {1}")+abort'
end
