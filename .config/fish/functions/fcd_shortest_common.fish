function fcd_shortest_common -d "Find shortest common path from array"
    set -l paths $argv
    if test (count $paths) -eq 0
        return
    end

    set -l shortest ""
    set -l shortest_len 0

    for path in $paths
        set -l len (string length $path)
        if test -z "$shortest"; or test $len -lt $shortest_len
            set shortest $path
            set shortest_len $len
        end
    end

    echo $shortest
end
