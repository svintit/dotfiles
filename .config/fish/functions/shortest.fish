function shortest -d "Return the shortest path from a list"
    set -l shortest_path ""
    set -l shortest_length 0

    for path in $argv
        if test -z "$path"
            continue
        end

        set -l current_length (string length $path)

        if test -z "$shortest_path"
            set shortest_path $path
            set shortest_length $current_length
        else if test $current_length -lt $shortest_length
            set shortest_path $path
            set shortest_length $current_length
        end
    end

    echo -n $shortest_path
end
