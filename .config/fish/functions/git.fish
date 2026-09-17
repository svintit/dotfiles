function git --description 'Git wrapper with custom commands'
    if test "$argv[1]" = "log"
        command git log --pretty=format:'%C(yellow)%h%C(reset) | %an | %ar | %C(cyan)%s%C(reset)%d' --topo-order --graph --decorate
    else if test "$argv[1]" = "pull-master"
        set current_branch (command git symbolic-ref --short -q HEAD)
        command git checkout master
        and command git pull
        and command git checkout $current_branch
    else
        command git $argv
    end
end
