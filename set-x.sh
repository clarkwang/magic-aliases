#!/bin/bash
# vi:set ts=8 sw=4 et:
#
# Author: Clark Wang <dearvoid at gmail.com>

function _set_x()
{
    set '^ *[0-9]+ +([^ ]+)( +([^ ]|[^ ].*[^ ]))? *$' "$( history 1 )"
    #               (1    )(2 (3              ))

    if [[ $2 =~ $1 ]]; then
        set -- "${BASH_REMATCH[3]}"
    else
        printf '!!! invalid history entry: %s\n' "$2" >&2
        return 1
    fi

    set -x
    eval "$1"
    set $?
    set +x
    return $1
}

alias set-x='_set_x #'
