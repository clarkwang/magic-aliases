#!/bin/bash
# vi:set ts=8 sw=4 et:
#
# Author: Clark Wang <dearvoid at gmail.com>

# _uplevel [-u "var1 var2 ..."] "cmd .." [args ..]
function _uplevel()
{
    if [[ $1 == '-u' ]]; then
        unset -v -- $2 || return
        shift 2
    fi

    eval "shift; $1"
}

function _quote()
{
    local str i ch ch2 ret
    local safe_pat='@([-+=%@:,./[:word:]])'
    local dq_pat='@([\\"`$])'
    local left_quote=''

    str="$2"

    printf -v ret '%q' "$str"
    if [[ $ret == "$str" || $ret == "\$'"* ]]; then
        local "$1" && _uplevel -u "$1" "$1="'"$1"' "$ret"
        return
    fi

    ret=''
    for ((i = 0; i < ${#str}; ++i)); do
        ch=${str:i:1}
        ch2=${str:i+1:1}

        # '..
        if [[ $left_quote == \' ]]; then

            # '.. + '
            if [[ $ch == \' ]]; then
                ret+="'\\'"
                left_quote=''

                # '.. + x
            else
                ret+="$ch"
            fi

            # "''..
        elif [[ $left_quote == \" ]]; then
            # "''.. + $
            if [[ $ch == $dq_pat ]]; then
                # All attempts to optimize this have failed. DO NOT TRY!
                ret+="\\$ch"

                # "''.. + !
            elif [[ $ch == '!' ]]; then
                ret+='"\!'
                left_quote=''

                # "''.. + {x,'}
            else
                ret+="$ch"
            fi
        elif [[ $ch == \' ]]; then
            # .. + ''
            if [[ $ch2 == \' ]]; then
                ret+="\"'"
                left_quote='"'

                # .. + 'x
            else
                ret+="\\'"
            fi

            # .. + x
        elif [[ $ch == $safe_pat ]]; then
            ret+="$ch"

            # .. + $$
        elif [[ -n $ch2 && $ch2 != \' && $ch2 != $safe_pat ]]; then
            ret+="'$ch"
            left_quote="'"

            # .. + <space>
        elif [[ $ch == ' ' && -z $ch2 ]]; then
            # We don't want the final result to be end with <space> which
            # is not copy-n-paste friendly.
            ret+="' '"

            # .. + $x
        else
            ret+="\\$ch"
        fi
    done

    if [[ -n $left_quote ]]; then
        ret+="$left_quote"
    fi
    if [[ -z $ret ]]; then
        ret="''"
    fi

    local "$1" && _uplevel -u "$1" "$1="'"$1"' "$ret"
}

function _magic_quote()
{
    local -a locals=( locals \
                      major minor bash44 \
                      no_run use_declare use_printf use_Q verbose \
                      arr cmd opt pat sep iter \
                      i s )
    ###=1=###
    local ${locals[@]}

    use_printf=0 use_declare=0 use_Q=0 no_run=0 verbose=0
    bash44=0
    sep='``'
    arr=()

    major=${BASH_VERSINFO[0]}
    minor=${BASH_VERSINFO[1]}
    if (( (major == 4 && minor >= 4) || major > 4 )); then
        bash44=1
    fi

    cmd=$( history 1 )
    if [[ $cmd == *$'\n'* ]]; then
        printf '!!! does not support multi-lined command\n' >&2
        return 1
    fi

    pat='^ *[0-9]+ +([^ ]+)( +([^ ]|[^ ].*[^ ]))? *$'
    #               (1    )(2 (3              ))
    if [[ $cmd =~ $pat ]]; then
        if [[ ${BASH_REMATCH[1]} != mquote ]]; then
            printf '!!! mquote must be the first word in the command\n' >&2
            return 1
        fi
        cmd=${BASH_REMATCH[3]}
    else
        printf '!!! invalid history entry: %s\n' "$cmd" >&2
        return 1
    fi

    pat='^ *-([dnpQv]+) *(.*)$'
    #                  ^^__ Here cannot use " +" or "mquote -v" would not work.
    while [[ $cmd =~ $pat ]]; do
        opt=${BASH_REMATCH[1]}
        cmd=${BASH_REMATCH[2]}
        [[ $opt == *d* ]] && use_declare=1
        [[ $opt == *n* ]] && no_run=1
        [[ $opt == *p* ]] && use_printf=1
        [[ $opt == *Q* ]] && use_Q=1
        [[ $opt == *v* ]] && verbose=1
    done

    if (( ! bash44 )); then
        use_Q=0
    fi

    if [[ $cmd != *"$sep"* ]]; then
        no_run=1
        cmd="$sep$cmd$sep"
    fi

    for ((i = 0; ; ++i)); do
        s=${cmd%%"$sep"*}
        arr[i]=$s

        if [[ $cmd != *"$sep"* ]]; then
            break
        else
            cmd=${cmd#*"$sep"}
        fi
    done
    if (( ${#arr[@]} % 2 != 1 )); then
        printf '!!! %s\n' "$sep .. $sep does not match" >&2
        return 1
    fi

    cmd=''
    pat='^[{]([0-9]+)[}](.*)$'
    #        (1     )   (2 )
    for ((i = 0; i < ${#arr[@]}; ++i)); do
        s=${arr[i]}
        if (( i % 2 == 1 )); then
            if [[ $s =~ $pat ]]; then
                iter=${BASH_REMATCH[1]}
                s=${BASH_REMATCH[2]}
            else
                iter=1
            fi
            if (( iter > 9 )); then
                printf "!!! %s\n" "n must be < 10 for $sep{n}..$sep" >&2
                return 1
            fi
            for (( ; iter; --iter)); do
                if (( use_printf )); then
                    #s=$( printf '%q' "$s" )
                    printf -v s '%q' "$s"
                elif (( use_Q )); then
                    s=${s@Q}
                elif (( use_declare )); then
                    s=$( declare -p s )
                    s=${s#*=}
                else
                    # use my own quoting
                    _quote s "$s"
                fi
            done
        fi
        cmd="$cmd$s"
    done

    if (( verbose || no_run )); then
        printf '>>> %s\n' "$cmd" >&2
    fi
    if (( ! no_run )); then
        _uplevel -u "${locals[*]}" "$cmd"
    fi
}

alias mquote='_magic_quote #'
