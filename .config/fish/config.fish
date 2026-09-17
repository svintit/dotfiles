# Environment Variables
set -gx EDITOR vim
set -gx LANG en_US.UTF-8

# Agent detection - only activate minimal mode for actual agents
if set -q npm_config_yes; or set -q CI; or not status is-interactive
    set -gx AGENT_MODE true
else
    set -gx AGENT_MODE false
end

# Homebrew (optimized - set paths directly instead of running brew shellenv)
if test -x /opt/homebrew/bin/brew
    set -gx HOMEBREW_PREFIX "/opt/homebrew"
    set -gx HOMEBREW_CELLAR "/opt/homebrew/Cellar"
    set -gx HOMEBREW_REPOSITORY "/opt/homebrew"
    # No --move: a dev-env subshell may already have homebrew
    # in PATH behind a zone toolchain; --move would jump it ahead and
    # break native gems.
    fish_add_path --global --path "/opt/homebrew/bin" "/opt/homebrew/sbin"
    if test -n "$MANPATH[1]"
        set -gx MANPATH "" $MANPATH
    end
    if not contains "/opt/homebrew/share/info" $INFOPATH
        set -gx INFOPATH "/opt/homebrew/share/info" $INFOPATH
    end
end

# PATH modifications
fish_add_path /usr/local/opt/ruby/bin
fish_add_path /usr/local/opt/openssl/bin
fish_add_path $HOME/.rvm/bin

# OpenSSL flags
set -gx LDFLAGS "-L/usr/local/opt/openssl/lib"
set -gx CPPFLAGS "-I/usr/local/opt/openssl/include"
set -gx PKG_CONFIG_PATH "/usr/local/opt/openssl/lib/pkgconfig"

# Aliases
alias watchh='watch -n 1 '
alias c="clear"
alias vim='nvim'
alias tmk="tmux kill-session -a; tmux rename-session 1"
alias tmks="tmux kill-server"
alias tm="tmux-zellij"
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias full="redshift -b 1.0"
alias half="redshift -b 0.5"
alias project='cd ~/Dropbox/2019-ca400-svintit2'
alias python='python3'
alias pip='pip3'
alias whereis='geoiplookup'
alias d='deactivate'
alias dps='docker ps'
alias show-spotify='wmctrl -i -a $(wmctrl -lx | grep spotify | cut "-d " -f1)'
alias xonotic="open /Applications/Xonotic/Xonotic.app --args -basedir /Applications/Xonotic"
alias ks="kubectl"
alias terraform="/usr/local/Cellar/tfenv/2.2.2/versions/0.14.11/terraform"
alias tf="terraform"
alias mk="minikube"
alias dc="docker-compose"
alias watch='watch -n 1 '

# Agent-friendly aliases when in agent mode
if test "$AGENT_MODE" = "true"
    alias rm='rm -f'
    alias cp='cp -f'
    alias mv='mv -f'
    alias npm='npm --no-fund --no-audit'
    alias yarn='yarn --non-interactive'
    alias pip='pip --quiet'
    alias git='git -c advice.detachedHead=false'
end

# Disable fish greeting
set fish_greeting

# Zoxide directory tracking for sesh project sessions.
if status is-interactive; and command -q zoxide
    zoxide init fish | source
end

# Make autosuggestions brighter (more visible)
set -g fish_color_autosuggestion 777

# Tide prompt customization
set -g tide_direnv_item_display never
set -g tide_context_always_display false
set -g tide_gcloud_item_display never
set -g tide_kubectl_item_display never
set -g tide_distrobox_item_display never
set -g tide_toolbox_item_display never
set -g tide_right_prompt_items status cmd_duration jobs node python rustc java php pulumi ruby go terraform aws nix_shell crystal elixir zig

# Async prompt configuration for Tide compatibility
set -g async_prompt_inherit_variables CMD_DURATION fish_bind_mode pipestatus SHLVL status _tide_side _tide_pad prev_bg_color

# Auto-start tmux (skip if already inside tmux or mux is suppressed)
# Set NO_AUTO_MUX=1 in child shells (e.g. tmux popups) to prevent nested auto-start.
if status is-interactive; and not set -q NO_AUTO_MUX; and not set -q TMUX
    exec $HOME/.local/bin/tmux-zellij
end

fish_add_path $HOME/.local/bin

# Ensure custom OMF key bindings (Alt+word navigation, etc.) are applied
if status is-interactive
    fish_user_key_bindings
end

# Inside tmux popup: bind Alt-f and Cmd-w escape to exit (so § / Cmd-w toggles closed)
if status is-interactive; and set -q TMUX_POPUP
    bind \ef exit
    bind \e\[5\;30013~ exit
end

# Clean up Tide's per-session universal prompt cache var on exit (prevents unbounded accumulation)
if status is-interactive
    function __tide_cleanup_on_exit --on-event fish_exit
        set -Ue _tide_prompt_$fish_pid 2>/dev/null
    end
end

# Sesh: double Tab opens the tmux session picker.
# First Tab is held briefly. If a second Tab does not arrive before timeout,
# fish runs normal completion.
set -g __sesh_double_tab_timeout 0.35

function __sesh_double_tab --description 'Open sesh in tmux on double Tab; keep single Tab completion'
    if not set -q TMUX
        commandline -f complete
        return
    end

    set -l timeout $__sesh_double_tab_timeout
    set -l key (command bash -c 'IFS= read -rsn1 -t "$1" k && printf "%s" "$k"' -- "$timeout")
    set -l read_status $status
    set -l tab (printf '\t')

    if test $read_status -eq 0; and string match -q -- "$tab" "$key"
        commandline -f repaint
        tmux run-shell "TMUX_TARGET_CLIENT='#{client_tty}' TMUX_TARGET_PATH='#{pane_current_path}' $HOME/.local/bin/tmux-open-sesh-popup"
        return
    end

    commandline -f complete

    if test $read_status -eq 0; and test -n "$key"
        commandline -i "$key"
    end
end

# tmux handles double Tab now so Pi and shell get the same picker.
# Keep fish's normal Tab binding; tmux replays single Tab after timeout.

# === Local overlay: load machine-specific config when it exists ===
set -l __fish_local "$HOME/.config/fish-local"
if test -d "$__fish_local"
    if not contains "$__fish_local/functions" $fish_function_path
        set -g fish_function_path "$__fish_local/functions" $fish_function_path
    end
    if test -d "$__fish_local/conf.d"
        for __f in "$__fish_local/conf.d"/*.fish
            test -f "$__f"; and source "$__f"
        end
    end
    test -f "$__fish_local/config.local.fish"; and source "$__fish_local/config.local.fish"
end
