#! /usr/bin/env bash

set -eu;

# Initials
# ----------------------------------------------------------------

declare _Git_sourceFilepath; _Git_sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )"; readonly _Git_sourceFilepath;
declare _Git_sourceDirpath; _Git_sourceDirpath="$( dirname -- "$_Git_sourceFilepath" 2> '/dev/null'; )"; readonly _Git_sourceDirpath;

[[ ! -f "$_Git_sourceFilepath" || ! -d "$_Git_sourceDirpath" ]] && exit 99;

# Libraries
# ----------------------------------------------------------------

export SHELL_LIBS_DIRPATH="$_Git_sourceDirpath"; [[ -d "$SHELL_LIBS_DIRPATH" ]] || exit 98;

# shellcheck disable=SC1091
[[ "${SHELL_LIB_OPTIONS:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/options.lib.sh" && [[ "${SHELL_LIB_OPTIONS:+s}" != '' ]] || exit 97; };

# shellcheck disable=SC2034
declare -r SHELL_LIB_GIT="$_Git_sourceFilepath";

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Functions
# ----------------------------------------------------------------

Git_PrintBranch()
{
    # Options
    # --------------------------------

    declare args; _options args \
        '/0/^(?:0|[1-9][0-9]*)$' \
        '?-t;?-r' \
        "$@" \
    || return $?;

    declare __type="${args[0]}";
    declare __gitRevision="${args[1]}";

    # ----------------

    if [[ "$__gitRevision" == '' ]];
    then
        declare __gitRevision='HEAD';
    fi

    if [[ "$__type" == '' ]];
    then
        declare __type=0;
    fi

    # Main
    # --------------------------------

    case "$__type" in
        '0')
            git rev-parse --abbrev-ref "$__gitRevision";

            return;
        ;;

        '1')
            git rev-parse "$__gitRevision";

            return;
        ;;
    esac

    return 1;
}

Git_PrintDiff()
{
    # Options
    # --------------------------------

    declare args; _options args \
        '?-d;?-s;-n;-r' \
        "$@" \
    || return $?;

    declare __destination="${args[0]}";
    declare __source="${args[1]}";
    declare __filenames="${args[2]}";
    declare __reverse="${args[3]}";

    # Main
    # --------------------------------

    declare gitDiffItemsString="$__source";

    if [[ "$__destination" != '' ]];
    then
        if (( __reverse > 0 ));
        then
            declare gitDiffItemsString="${__destination}..${gitDiffItemsString}";
        else
            declare gitDiffItemsString+="..${__destination}";
        fi
    fi

    declare argsTemp=();

    if (( __filenames > 0 ));
    then
        argsTemp+=( '--name-only' );
    fi

    declare argsTempPlain=();

    if [[ "${#gitDiffItemsString}" != 0 ]];
    then
        argsTempPlain+=( "$gitDiffItemsString" );
    fi

    git diff "${argsTemp[@]}" "${argsTempPlain[@]}";
}
