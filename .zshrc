# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
export GOPATH=$HOME/go/bin
export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH="${GOPATH}:$PATH"

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

LANG="en_US.UTF-8"; export LANG
LC_ALL="en_US.UTF-8"; export LC_ALL

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
# ZSH_THEME="spaceship"
ZSH_THEME=""
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

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git battery
  git
  zsh-syntax-highlighting
  command-time
  zsh-autosuggestions
  git extract web-search yum git-extras docker vagrant
  kubectl
  cp
)

source $ZSH/oh-my-zsh.sh

# User configuration
ZSH_COMMAND_TIME_COLOR="cyan"
ZSH_COMMAND_TIME_MSG="Execution time: %s sec"

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

alias c="clear"
alias vim="sudo vim"
alias e="exit"
alias rm="trash"
alias tmk="tmux kill-session -a; tmux rename-session 1"
alias tmks="tmux kill-server"
alias telecom="ssh traian@pgc-32sx-1-z1"
alias tm="tmux new-session -A"
alias wd="ssh wdc4-tanker02"
alias ls="colorls --gs --group-directories-first"
alias ll="colorls -l --gs --group-directories-first"
alias full="redshift -b 1.0"
alias half="redshift -b 0.5"
alias project='cd ~/Dropbox/2019-ca400-svintit2'
alias tmux='TERM=screen-256color-bce tmux'
alias l='$(fc -ln -1)'
alias python='python3'
# alias pip='pip3'
alias dotfiles='/usr/bin/git --git-dir=/home/traian/.dotfiles/ --work-tree=/home/traian'
alias whereis='geoiplookup'
alias vim='vim'
alias code='intellij-idea-community'
alias d='deactivate'
alias dps='docker ps'
alias show-spotify='wmctrl -i -a $(wmctrl -lx | grep spotify | cut "-d " -f1)'
alias xonotic="open /Applications/Xonotic/Xonotic.app --args -basedir /Applications/Xonotic"
alias ks="kubectl"
alias mk="minikube"
alias dc="docker-compose"

# tmux new-session -A
# if [ -z "$TMUX" ]; then
#	TERM=screen-256color-bce tmux attach || TERM=screen-256color-bce tmux
# xcfi

# stty intr ^z

function book-gym {
    CURRENT_DIR=$pwd
    builtin cd ~/Dev/Repos/my-repos/auto-booking-system
    python3 -m auto_booking_system.__init__ &
    cd $CURRENT_DIR
}

up() {
        local d=""
        limit=$1
        for ((i=1 ; i <= limit ; i++))
            do
                d=$d/..
            done
        d=$(echo $d | sed 's/^\///')
        if [ -z "$d" ]; then
            d=..
        fi
        cd $d
}

function auto_pipenv_shell {
    if [[ "$VIRTUAL_ENV" == "" ]]; then
        if [ -f "Pipfile" ] ; then
            source "$(pipenv --venv)/bin/activate"
            source ~/.zshrc
        fi
    fi
}

function cd {
    builtin cd "$@"
    # source pipenv-ify_pip-tools.sh
    # auto_pipenv_shell
    ls
}

..() { builtin cd .. && ls }


dip () {
    docker_output_format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}  {{.Name}}  -> {{range $p, $conf := .Config.ExposedPorts}} {{$p}} {{end}}'
    if [[ -n "$1" ]]; then
        docker inspect --format="$docker_output_format" "$1"
    else
        docker ps -q --no-trunc | xargs docker inspect --format="$docker_output_format" | sort
    fi
}

git () {
    if [[ $@ == "log" ]]; then
        command git log --pretty=format:'%C(yellow)%h%C(reset) | %an | %ar | %C(cyan)%s%C(reset)%d' --topo-order --graph --decorate
    else
        command git "$@"
    fi

}

npm-login () {
    rm ~/.npmrc
    # aws codeartifact login --tool npm --domain <> --repository vespr
    # sed -i.old '1s;^;@<>:;' ~/.npmrc
    TOKEN=$(aws codeartifact get-authorization-token \
        --region eu-west-1 \
        --domain <> \
        --domain-owner 841996891963 \
        --query authorizationToken \
        --output text)
    DEV_ENDPOINT="https://<>-841996891963.d.codeartifact.eu-west-1.amazonaws.com/npm/dev-vespr/"
    npm config set @<>:registry $DEV_ENDPOINT
    npm config set ${DEV_ENDPOINT/https:/}:always-auth true
    npm config set ${DEV_ENDPOINT/https:/}:_authToken=${TOKEN}
    echo "Successfully logged in to dev-vespr npm registry"
}

get_pod_name() {
    kubectl get pods | grep "$1" | awk '{print $1}'
}

export ECR_REGISTRY=841996891963.dkr.ecr.eu-west-1.amazonaws.com

git-squash () {
    BRANCH=$(git branch --show-current)
    [[ -z $1 ]] && 1="insert message here"

    git reset $(git merge-base master $BRANCH)
    git add -A
    git commit -m "$1"
}

export ACCOUNT_MGMT_REGION=eu-west-1

get_aws_secret() {
  local secret_id=${1}
  aws secretsmanager get-secret-value \
      --region ${ACCOUNT_MGMT_REGION} \
      --secret-id ${secret_id} \
      --query SecretString \
      --output text \
      | jq -r 'to_entries | .[] | .key + "=" + .value'
    if [ ${pipestatus[1]} -ne 0 ]; then
        die "Could not fetch secret '${secret_id}' from AWS Secrets Manager in AWS account ${AWS_ACCOUNT_ID}, region ${ACCOUNT_MGMT_REGION}"
    fi
}

# source ~/aws_code_artifact_login pipenv >/dev/null 2>&1

# precmd() { print "" }

# neofetch --off
# fortune | cowsay -e -- -T \U\\ | sed -e 's/^/\t/' | lolcat
# echo ""
# echo "---------------------------------------------------------" | lolcat
# fortune | lolcat
# echo "---------------------------------------------------------" | lolcat
# echo ""

export TERM=xterm-color

unsetopt PROMPT_SP
fpath=($fpath "$HOME/.zfunctions")

eval "$(starship init zsh)"
# autoload -U promptinit; promptinit
# prompt spaceship


# added by travis gem
[ ! -s /Users/traian/.travis/travis.sh ] || source /Users/traian/.travis/travis.sh

export HELM_EXPERIMENTAL_OCI=1

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
