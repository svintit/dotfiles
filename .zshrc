# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


export ZSH_DISABLE_COMPFIX="true"

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
# ZSH_THEME=""
ZSH_THEME="powerlevel10k/powerlevel10k"
# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME="spaceship"
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

plugins=(
  git battery
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
)

#export PROMPT_COMMAND='echo -ne "\033]0;${PWD##*/}\007"'
# source ~/.iterm2_shell_integration.`basename $SHELL`

# This creates the var currentDir to use later on
function iterm2_print_user_vars() {
  iterm2_set_user_var currentDir "${PWD##*/}"
}

source $ZSH/oh-my-zsh.sh

export EDITOR='vim'

alias watchh='watch -n 1 '
alias bp-dev='zellij --layout  ~/.config/zellij/bp-layout.kdl'
alias yarn='nocorrect yarn' 
alias c="clear"
alias vim="sudo vim"
alias e="exit"
alias tmk="tmux kill-session -a; tmux rename-session 1"
alias tmks="tmux kill-server"
alias telecom="ssh traian@pgc-32sx-1-z1"
alias tm="tmux new-session -A"
alias wd="ssh wdc4-tanker02"
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias full="redshift -b 1.0"
alias half="redshift -b 0.5"
alias project='cd ~/Dropbox/2019-ca400-svintit2'
alias tmux='TERM=screen-256color-bce tmux'
alias l='$(fc -ln -1)'
alias python='python3'
alias pip='pip3'
alias dotfiles='/usr/bin/git --git-dir=/home/traian/.dotfiles/ --work-tree=/home/traian'
alias whereis='geoiplookup'
alias vim='vim'
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

function cd {
    builtin cd "$@"
    # source pipenv-ify_pip-tools.sh
    # auto_pipenv_shell
    ls
}

..() { builtin cd .. && ls }

function ff {
    aerospace list-windows --all | fzf --bind 'enter:execute(bash -c "aerospace focus --window-id {1}")+abort'
}

function git {
    if [[ $@ == "log" ]]; then
        command git log --pretty=format:'%C(yellow)%h%C(reset) | %an | %ar | %C(cyan)%s%C(reset)%d' --topo-order --graph --decorate
    elif [ "$1" = "pull-master" ]; then
        current_branch=$(command git symbolic-ref --short -q HEAD)
        command git checkout master
        command git pull
        command git checkout $current_branch
    else
        command git "$@"
    fi
}

function git-squash {
    # Usage: git-squash

    CURRENT_BRANCH=$(git branch --show-current)

    if [[ -z $1 ]]; then
        printf "Please input target branch: "
        read TARGET_BRANCH
    else
        TARGET_BRANCH=$1
    fi
    [[ -z $TARGET_BRANCH ]] && TARGET_BRANCH='master'

    if [[ -z $2 ]]; then
        printf "Please input commit message (Press ENTER to open $EDITOR)"
        read PAUSE
        MESSAGE=""
        CONTENTFILE=/tmp/input
        $EDITOR $CONTENTFILE
        MESSAGE=`cat $CONTENTFILE`
        cat /dev/null > $CONTENTFILE
    else
        MESSAGE=$1
    fi
    [[ -z $MESSAGE ]] && MESSAGE=$(git log master..$CURRENT_BRANCH --oneline | tail -1)

    git reset $(git merge-base $TARGET_BRANCH $CURRENT_BRANCH)
    git add -A
    git commit -m "$MESSAGE"
}

export TERM=xterm-color

unsetopt PROMPT_SP
fpath=($fpath "$HOME/.zfunctions")
fpath+=("$(brew --prefix)/share/zsh/site-functions")


# autoload -U promptinit; promptinit
# prompt pure


# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

# test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"


autoload -U +X bashcompinit && bashcompinit
# complete -o nospace -C /usr/local/bin/terraform terraform
# export PATH="/usr/local/opt/python@3.8/bin:$PATH"


[[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)

[ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh

unsetopt correct_all  
setopt correct
export PATH="/usr/local/opt/ruby/bin:$PATH"
# eval "$(rbenv init - zsh)"
export PATH="/usr/local/opt/openssl/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/openssl/lib"
export CPPFLAGS="-I/usr/local/opt/openssl/include"
export PKG_CONFIG_PATH="/usr/local/opt/openssl/lib/pkgconfig"
# PATH=$PATH:/Users/svintit/.rbenv/shims/colorls

[[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }
export PATH="/usr/local/opt/openssl/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/openssl/lib"
export CPPFLAGS="-I/usr/local/opt/openssl/include"
export PKG_CONFIG_PATH="/usr/local/opt/openssl/lib/pkgconfig"
#compdef gt
###-begin-gt-completions-###
#
# yargs command completion script
#
# Installation: gt completion >> ~/.zshrc
#    or gt completion >> ~/.zprofile on OSX.
#
_gt_yargs_completions()
{
  local reply
  local si=$IFS
  IFS=$'
' reply=($(COMP_CWORD="$((CURRENT-1))" COMP_LINE="$BUFFER" COMP_POINT="$CURSOR" gt --get-yargs-completions "${words[@]}"))
  IFS=$si
  _describe 'values' reply
}
compdef _gt_yargs_completions gt
###-end-gt-completions-###

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export LANG='en_US.UTF-8'
