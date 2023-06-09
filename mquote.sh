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

function _magic_quote()
{
    local -a locals=( locals \
                      major minor bash44 \
                      no_run use_declare use_printf verbose \
                      arr cmd opt pat sep iter \
                      i s )
    ###=1=###
    local ${locals[@]}

    use_printf=0 use_declare=0 no_run=0 verbose=0
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

    pat='^ *-([dnpv]+) *(.*)$'
    #                 ^^__ Here cannot use " +" or "mquote -v" would not work.
    while [[ $cmd =~ $pat ]]; do
        opt=${BASH_REMATCH[1]}
        cmd=${BASH_REMATCH[2]}
        [[ $opt == *d* ]] && use_declare=1
        [[ $opt == *n* ]] && no_run=1
        [[ $opt == *p* ]] && use_printf=1
        [[ $opt == *v* ]] && verbose=1
    done

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
    pat='^[{]([1-9])[}](.*)$'
    #        (1    )   (2 )
    for ((i = 0; i < ${#arr[@]}; ++i)); do
        s=${arr[i]}
        if (( i % 2 == 1 )); then
            if [[ $s =~ $pat ]]; then
                iter=${BASH_REMATCH[1]}
                s=${BASH_REMATCH[2]}
            else
                iter=1
            fi
            for (( ; iter; --iter)); do
                if (( use_printf )); then
                    s=$( printf '%q' "$s" )
                elif (( bash44 && ! use_declare )); then
                    s=${s@Q}
                else
                    s=$( declare -p s )
                    s=${s#*=}
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
