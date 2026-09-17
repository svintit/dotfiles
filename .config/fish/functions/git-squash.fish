function git-squash --description 'Squash all commits since diverging from target branch'
    set CURRENT_BRANCH (git branch --show-current)

    if test (count $argv) -ge 1
        set TARGET_BRANCH $argv[1]
    else
        read -P "Please input target branch: " TARGET_BRANCH
    end

    if test -z "$TARGET_BRANCH"
        set TARGET_BRANCH master
    end

    if test (count $argv) -ge 2
        set MESSAGE $argv[2]
    else
        read -P "Please input commit message (Press ENTER to open $EDITOR): " PAUSE
        set CONTENTFILE /tmp/input
        eval $EDITOR $CONTENTFILE
        set MESSAGE (cat $CONTENTFILE)
        echo -n "" > $CONTENTFILE
    end

    if test -z "$MESSAGE"
        set MESSAGE (git log master..$CURRENT_BRANCH --oneline | tail -1)
    end

    git reset (git merge-base $TARGET_BRANCH $CURRENT_BRANCH)
    and git add -A
    and git commit -m "$MESSAGE"
end
