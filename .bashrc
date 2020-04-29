#!/bin/env bash

# PureLine - A Pure Bash Powerline PS1 Command Prompt 

# -----------------------------------------------------------------------------
# returns a string with the powerline symbol for a section end
# arg: $1 is foreground color of the next section
# arg: $2 is background color of the next section
function section_end {
    if [ "$__last_color" == "$2" ]; then
        # Section colors are the same, use a foreground separator
        local end_char="${PL_SYMBOLS[soft_separator]}"
        local fg="$1"
    else
        # section colors are different, use a background separator
        local end_char="${PL_SYMBOLS[hard_separator]}"
        local fg="$__last_color"
    fi
    if [ -n "$__last_color" ]; then
        echo "${PL_COLORS[$fg]}${PL_COLORS[On_$2]}$end_char"
    fi
}

# -----------------------------------------------------------------------------
# returns a string with background and foreground colours set
# arg: $1 foreground color
# arg: $2 background color
# arg: $3 content
function section_content {
    echo "${PL_COLORS[$1]}${PL_COLORS[On_$2]}$3"
}

#------------------------------------------------------------------------------
# Helper function for User & ssh modules
function ip_address {
    echo "$(ip route get 1 | tr -s ' ' | cut -d' ' -f7)"
}

#------------------------------------------------------------------------------
# Helper function to return normal or super user prompt character
function prompt_char {
    [[ ${EUID} -eq 0 ]] && echo "#" || echo "$"
}

# -----------------------------------------------------------------------------
# append to prompt: current time
# arg: $1 foreground color
# arg: $2 background color
# optional variables;
#   PL_TIME_SHOW_SECONDS: true/false for hh:mm:ss / hh:mm
function time_module {
    local bg_color="$1"
    local fg_color="$2"
    if [ "$PL_TIME_SHOW_SECONDS" = true ]; then
        local content="\t"
    else
        local content="\A"
    fi
    PS1+="$(section_end $fg_color $bg_color)"
    PS1+="$(section_content $fg_color $bg_color " $content ")"
    __last_color="$bg_color"
}

#------------------------------------------------------------------------------
# append to prompt: user@host or user or root@host
# arg: $1 foreground color
# arg: $2 background color
# option variables;
#   PL_USER_SHOW_HOST: true/false to show host name/ip
#   PL_USER_USE_IP: true/false to show IP instead of hostname
function user_module {
    local bg_color="$1"
    local fg_color="$2"
    local content="\u"
    # Show host if true or when user is remote/root
    if [ "$PL_USER_SHOW_HOST" = true ]; then
        if [ "$PL_USER_USE_IP" = true ]; then
            content+="@$(ip_address)"
        else
            content+="@\h"
        fi
    fi
    PS1+="$(section_end $fg_color $bg_color)"
    PS1+="$(section_content $fg_color $bg_color " $content ")"
    __last_color="$bg_color"
}

# -----------------------------------------------------------------------------
# append to prompt: indicate if SSH session
# arg: $1 foreground color
# arg: $2 background color
# option variables;
#   PL_SSH_SHOW_HOST: true/false to show host name/ip
#   PL_SSH_USE_IP: true/false to show IP instead of hostname
function ssh_module {
    if [[ "${SSH_CLIENT}" || "${SSH_TTY}" ]]; then
        local bg_color="$1"
        local fg_color="$2"
        local content="${PL_SYMBOLS[ssh]}"
        if [ "$PL_SSH_SHOW_HOST" = true ]; then
            if [ "$PL_SSH_USE_IP" = true ]; then
                content+=" $(ip_address)"
            else
                content+=" \h"
            fi
        fi
        PS1+="$(section_end $fg_color $bg_color)"
        PS1+="$(section_content $fg_color $bg_color " $content ")"
        __last_color="$bg_color"
    fi
}

# -----------------------------------------------------------------------------
# append to prompt: current directory
# arg: $1 foreground color
# arg; $2 background color
# option variables;
#   PL_PATH_TRIM: 0—fullpath, 1—current dir, [x]—trim to x number of dir
function path_module {
    local bg_color="$1"
    local fg_color="$2"
    local content="\w"
    if [ "$PL_PATH_TRIM" -eq 1 ]; then
        local content="\W"
    elif [ "$PL_PATH_TRIM" -gt 1 ]; then
        PROMPT_DIRTRIM="$PL_PATH_TRIM"
    fi
    PS1+="$(section_end $fg_color $bg_color)"
    PS1+="$(section_content $fg_color $bg_color " $content ")"
    __last_color="$bg_color"
}

# -----------------------------------------------------------------------------
# append to prompt: the number of background jobs running
# arg: $1 foreground color
# arg; $2 background color
function background_jobs_module {
    local bg_color="$1"
    local fg_color="$2"
    local number_jobs=$(jobs -p | wc -l | tr -d [:space:])
    if [ ! "$number_jobs" -eq 0 ]; then
        PS1+="$(section_end $fg_color $bg_color)"
        PS1+="$(section_content $fg_color $bg_color " ${PL_SYMBOLS[background_jobs]} $number_jobs ")"
        __last_color="$bg_color"
    fi
}

# -----------------------------------------------------------------------------
# append to prompt: indicator is the current directory is ready-only
# arg: $1 foreground color
# arg; $2 background color
function read_only_module {
    local bg_color="$1"
    local fg_color="$2"
    if [ ! -w "$PWD" ]; then
        PS1+="$(section_end $fg_color $bg_color)"
        PS1+="$(section_content $fg_color $bg_color " ${PL_SYMBOLS[read_only]} ")"
        __last_color="$bg_color"
    fi
}

# -----------------------------------------------------------------------------
# append to prompt: git branch with indictors for;
#     number of; modified files, staged files and conflicts
# arg: $1 foreground color
# arg; $2 background color
# option variables;
#   PL_GIT_STASH: true/false
#   PL_GIT_AHEAD: true/false
#   PL_GIT_STAGED: true/false
#   PL_GIT_CONFLICTS: true/false
#   PL_GIT_MODIFIED: true/false
#   PL_GIT_UNTRACKED: true/false
function git_module {
    local git_branch=$(git rev-parse --abbrev-ref HEAD 2> /dev/null)
    if [ -n "$git_branch" ]; then
        local bg_color="$1"
        local fg_color="$2"
        local content="${PL_SYMBOLS[git_branch]} $git_branch"

        local number_stash="$(git stash list 2>/dev/null | fgrep -v 'fatal:' | wc -l | tr -d [:space:])"
          if [ ! "$number_stash" -eq 0 ]; then
              content+="${PL_SYMBOLS[git_stash]}$number_stash"
          fi

          local number_behind_ahead="$(git rev-list --count --left-right '@{upstream}...HEAD' 2>/dev/null)"
          local number_ahead="${number_behind_ahead#*	}"
          local number_behind="${number_behind_ahead%	*}"
          if [ ! "0$number_ahead" -eq 0 -o ! "0$number_behind" -eq 0 ]; then
              if [ ! "$number_ahead" -eq 0 ]; then
                  content+="${PL_SYMBOLS[git_ahead]}$number_ahead"
              fi
              if [ ! "$number_behind" -eq 0 ]; then
                  content+="${PL_SYMBOLS[git_behind]}$number_behind"
              fi
          fi

          local number_staged="$(git diff --staged --name-only --diff-filter=AM 2> /dev/null | wc -l | tr -d [:space:])"
          if [ ! "$number_staged" -eq "0" ]; then
              content+=" ${PL_SYMBOLS[soft_separator]} ${PL_SYMBOLS[git_staged]}$number_staged"
          fi

          local number_conflicts="$(git diff --name-only --diff-filter=U 2> /dev/null | wc -l | tr -d [:space:])"
          if [ ! "$number_conflicts" -eq "0" ]; then
              content+=" ${PL_SYMBOLS[soft_separator]} ${PL_SYMBOLS[git_conflicts]}$number_conflicts"
          fi

          local number_modified="$(git diff --name-only --diff-filter=M 2> /dev/null | wc -l | tr -d [:space:])"
          if [ ! "$number_modified" -eq "0" ]; then
              content+=" ${PL_SYMBOLS[soft_separator]} ${PL_SYMBOLS[git_modified]}$number_modified"
          fi

          local number_untracked="$(git ls-files --other --exclude-standard 2> /dev/null | wc -l | tr -d [:space:])"
          if [ ! "$number_untracked" -eq "0" ]; then
              content+=" ${PL_SYMBOLS[soft_separator]} ${PL_SYMBOLS[git_untracked]}$number_untracked"
          fi

      if [ -n "$(git status --porcelain 2> /dev/null)" ]; then
          if [ -n "$PL_GIT_DIRTY_FG" ]; then
              fg_color="$PL_GIT_DIRTY_FG"
          fi
          if [ -n "$PL_GIT_DIRTY_BG" ]; then
              bg_color="$PL_GIT_DIRTY_BG"
          fi
      fi

      PS1+="$(section_end $fg_color $bg_color)"
      PS1+="$(section_content $fg_color $bg_color " $content ")"
      __last_color="$bg_color"
  fi
}

# -----------------------------------------------------------------------------
# append to prompt: python virtual environment name
# arg: $1 foreground color
# arg; $2 background color
function virtual_env_module {
    if [ -n "$VIRTUAL_ENV" ]; then
        local venv="${VIRTUAL_ENV##*/}"
        local bg_color="$1"
        local fg_color="$2"
        local content=" ${PL_SYMBOLS[python]} $venv"
        PS1+="$(section_end $fg_color $bg_color)"
        PS1+="$(section_content $fg_color $bg_color "$content ")"
        __last_color="$bg_color"
    fi
}

# -----------------------------------------------------------------------------
# append to prompt: indicator for battery level
# arg: $1 foreground color
# arg; $2 background color
function battery_module {
    local bg_color="$1"
    local fg_color="$2"
    local batt_dir
    local content
    local batt_dir="/sys/class/power_supply/BAT"
    if [ -d $batt_dir"0" ]; then
        batt_dir=$batt_dir"0"
    elif [ -d $batt_dir"1" ]; then
        batt_dir=$batt_dir"1"
    else
        return 1
    fi
    local cap="$(<"$batt_dir/capacity")"
    local status="$(<"$batt_dir/status")"

    if [ "$status" == "Discharging" ]; then
        content="${PL_SYMBOLS[battery_discharging]} "
    else
        content="${PL_SYMBOLS[battery_charging]}"
    fi
    content="$content$cap%"

    PS1+="$(section_end $fg_color $bg_color)"
    PS1+="$(section_content $fg_color $bg_color " $content ")"
    __last_color="$bg_color"
}

# -----------------------------------------------------------------------------
# append to prompt: append a '$' prompt with optional return code for previous command
# arg: $1 foreground color
# arg; $2 background color
function prompt_module {
    local bg_color="$1"
    local fg_color="$2"
    local content=" $(prompt_char) "
    if [ ${EUID} -eq 0 ]; then
        if [ -n "$PL_PROMPT_ROOT_FG" ]; then
            fg_color="$PL_PROMPT_ROOT_FG"
        fi
        if [ -n "$PL_PROMPT_ROOT_BG" ]; then
            bg_color="$PL_PROMPT_ROOT_BG"
        fi
    fi
    PS1+="$(section_end $fg_color $bg_color)"
    PS1+="$(section_content $fg_color $bg_color "$content")"
    __last_color="$bg_color"
}

# -----------------------------------------------------------------------------
# append to prompt: append a '$' prompt with optional return code for previous command
# arg: $1 foreground color
# arg; $2 background color
function return_code_module {
    if [ ! "$__return_code" -eq 0 ]; then
        local bg_color="$1"
        local fg_color="$2"
        local content=" ${PL_SYMBOLS[return_code]} $__return_code "
        PS1+="$(section_end $fg_color $bg_color)"
        PS1+="$(section_content $fg_color $bg_color "$content")"
        __last_color="$bg_color"
    fi
}

# -----------------------------------------------------------------------------
# append to prompt: end the current promptline and start a newline
function newline_module {
    if [ -n "$__last_color" ]; then
        PS1+="$(section_end $__last_color 'Default')"
    fi
    PS1+="\n"
    unset __last_color
}

# -----------------------------------------------------------------------------
function pureline_ps1 {
    __return_code=$?    # save the return code
    local TITLEBAR='\[\e]2; \u@\h: \w \a';  # set console title
    					    # example: {USERNAME}@{HOSTNAME}:{PWD}
    PS1=""              # reset the command prompt

    # load the modules
    for module in "${!PL_MODULES[@]}"; do
        ${PL_MODULES[$module]}
    done

    # final end point
    if [ -n "$__last_color" ]; then
        PS1+="$(section_end $__last_color 'Default')"
    else
        # No modules loaded, set a basic prompt
        PS1="PL | No Modules Loaded: $(prompt_char)"
    fi

    # cleanup
    PS1+="${PL_COLORS[Color_Off]}"
    if [ "$PL_ERASE_TO_EOL" = true ]; then
        PS1+="\[\e[K\]"
    fi
    PS1+=" ${TITLEBAR}" # set titlebar
    unset __last_color
    unset __return_code
}

# -----------------------------------------------------------------------------

# define the basic color set
declare -A PL_COLORS=(
[Color_Off]='\[\e[0m\]'       # Text Reset
# Foreground
[Default]='\[\e[0;39m\]'      # Default
[Black]='\[\e[0;30m\]'        # Black
[Red]='\[\e[0;31m\]'          # Red
[Green]='\[\e[0;32m\]'        # Green
[Yellow]='\[\e[0;33m\]'       # Yellow
[Blue]='\[\e[0;34m\]'         # Blue
[Purple]='\[\e[0;35m\]'       # Purple
[Cyan]='\[\e[0;36m\]'         # Cyan
[White]='\[\e[0;37m\]'        # White
# Background
[On_Default]='\[\e[49m\]'     # Default
[On_Black]='\[\e[40m\]'       # Black
[On_Red]='\[\e[41m\]'         # Red
[On_Green]='\[\e[42m\]'       # Green
[On_Yellow]='\[\e[43m\]'      # Yellow
[On_Blue]='\[\e[44m\]'        # Blue
[On_Purple]='\[\e[45m\]'      # Purple
[On_Cyan]='\[\e[46m\]'        # Cyan
[On_White]='\[\e[47m\]'       # White
)

# default symbols are intended for 'out-ofthe-box' compatibility.
# symbols from code page 437: character set of the original IBM PC
declare -A PL_SYMBOLS=(
[hard_separator]=""
[soft_separator]="│"

[git_branch]="╬"
[git_untracked]="?"
[git_stash]="§"
[git_ahead]="↑"
[git_behind]="↓"
[git_modified]="+"
[git_staged]="•"
[git_conflicts]="*"

[ssh]="╤"
[read_only]="Θ"
[return_code]="x"
[background_jobs]="↨"
[background_jobs]="↔"
[python]="π"

[battery_charging]="■ "
[battery_discharging]="▬ "
)
# check if an argument has been given for a config file
if [ -f "$1" ]; then
    source "$1"
fi
# ensure some modules have been defined
if [ -z "$PL_MODULES" ]; then
    # define default modules to load
    declare -a PL_MODULES=(
    'user_module             Yellow      Black'
    'path_module             White       Black'
    'git_module              Blue        Black'
    'return_code_module      Cyan        White'
    'ssh_module              Purple      Black'
    'background_jobs_module  Green       Yellow'
    'read_only_module        Red         White'
    )
    PL_USER_SHOW_HOST=true
    PL_PATH_TRIM=1
    # don't clobber readline mode indicator
    [[ $(bind -v) =~ "set show-mode-in-prompt on" ]] && PL_ERASE_TO_EOL=true
fi

# grab a snapshot of the systems PROMPT_COMMAND. this can then be
# appended to pureline when sourced without continually appending
# pureline to itself.
if [ -z "$__PROMPT_COMMAND" ]; then 
    __PROMPT_COMMAND="$PROMPT_COMMAND"
fi

# dynamically set the  PS1
[[ ! ${PROMPT_COMMAND} =~ 'pureline_ps1;' ]] &&  PROMPT_COMMAND="pureline_ps1; $PROMPT_COMMAND" || true

export STARDICT_DATA_DIR=$XDG_DATA_HOME

set -o vi
