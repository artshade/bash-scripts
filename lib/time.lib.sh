#! /usr/bin/env bash

set -eu;

# Initials
# ----------------------------------------------------------------

declare _Time_sourceFilepath; _Time_sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )"; readonly _Time_sourceFilepath;
declare _Time_sourceDirpath; _Time_sourceDirpath="$( dirname -- "$_Time_sourceFilepath" 2> '/dev/null'; )"; readonly _Time_sourceDirpath;

[[ ! -f "$_Time_sourceFilepath" || ! -d "$_Time_sourceDirpath" ]] && exit 99;

# Integrity
# ----------------------------------------------------------------

[[ "${SHELL_SELF_INTEGRITY-1}" == 0 ]] ||
(
    _verifyChecksum() {
        declare __filepath="$1";
        declare __dirpath="$2";
        shift 2;

        # ----------------

        [[ ! -f "$__filepath" ]] && return 2;

        declare checksumFilepath="${__filepath}.sha256sum";

        [[ ! -f "$checksumFilepath" ]] && {
            (( SHELL_STRICT_SELF_INTEGRITY )) && return 2;

            return 0;
        };

        [[ ! -d "$__dirpath" || ! -x "$__dirpath" ]] && return 2;

        declare checkStatus=0;
        pushd -- "$__dirpath" > '/dev/null' || return 1;
        sha256sum -c --strict --status -- "$checksumFilepath" > '/dev/null' || declare checkStatus=$?;
        popd > '/dev/null' || return 1;

        return "$checkStatus";
    }

    _verifyChecksum "$_Time_sourceFilepath" "$_Time_sourceDirpath";
) || {
    printf -- $'Failed to self-verify file integrity: \'%s\'.\n' "$_Time_sourceFilepath" >&2;

    exit 98;
}

# Libraries
# ----------------------------------------------------------------

for SHELL_LIBS_DIRPATH in \
    "${_Time_sourceDirpath}/../lib" \
    "${_Time_sourceDirpath}/lib" \
    "${SHELL_LIBS_DIRPATH:-$_Time_sourceDirpath}";
do
    [[ -d "$SHELL_LIBS_DIRPATH" ]] && break;
done

{
    # shellcheck disable=SC1091
    [[ -d "${SHELL_LIBS_DIRPATH-}" ]] && export SHELL_LIBS_DIRPATH &&
    { [[ -v SHELL_LIB_OPTIONS ]] || . "${SHELL_LIBS_DIRPATH}/options.lib.sh"; } &&
    { [[ -v SHELL_LIB_MISC ]] || . "${SHELL_LIBS_DIRPATH}/misc.lib.sh"; }
    [[
        "${SHELL_LIBS_INTEGRITY-1}" == 0 ||
        '4ae5b061799db1f2114c68071e8e0dc4da416976c282166efdc6c557f27a304e' == "${SHELL_LIB_OPTIONS%%\:*}" &&
        '280ebccb12f72aa800a1571bd2419185fc197b76565cfae5fae1acbc8bcd18a0' == "${SHELL_LIB_MISC%%\:*}"
    ]]
} || {
    printf -- $'Failed to source libraries to \'%s\' from directory \'%s\'.\n' \
        "$_Time_sourceFilepath" "$SHELL_LIBS_DIRPATH" 1>&2;

    exit 97;
}

# --------------------------------

declare SHELL_LIB_TIME; SHELL_LIB_TIME="$( sha256sum -b -- "$_Time_sourceFilepath" | cut -d ' ' -f 1; ):${_Time_sourceFilepath}";

# shellcheck disable=SC2034
readonly SHELL_LIB_TIME;

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Variables Private
# ----------------------------------------------------------------
# Arrays
# --------------------------------

declare -A _Time_timesStorage=();

# Functions
# ----------------------------------------------------------------

# shellcheck disable=SC2120
Time_DateTime()
{
    # Options
    # --------------------------------

    declare args; _options args \
        '/0/^[0-9]$' \
        '?-t;?-T;?-F;-l' \
        "$@" \
    || return $?;

    declare __dateTimeType="${args[0]}";
    declare __dateTimeCustom="${args[1]}";
    declare __dateTimeFormat="${args[2]}";
    declare __dateTimeLocal="${args[3]}";
    unset args;

    # Main
    # --------------------------------

    declare dateArgs=();

    if (( __dateTimeLocal == 0 ));
    then
        declare dateArgs+=( '-u' ); # UTC
    fi

    if [[ "$__dateTimeCustom" != '' ]];
    then
        dateArgs+=( '-d' "@${__dateTimeCustom}" );
    fi

    if [[ "$__dateTimeFormat" != '' ]];
    then
        date "${dateArgs[@]}" "+${__dateTimeFormat}" 2>> '/dev/null';

        return $?;
    fi

    case "$__dateTimeType" in
        1)
            date "${dateArgs[@]}" '+%s%N' 2>> '/dev/null';

            return $?;
        ;;
        2)
            date "${dateArgs[@]}" -Ins 2>> '/dev/null';

            return $?;
        ;;
        3)
            date "${dateArgs[@]}" -Iseconds 2>> '/dev/null';

            return $?;
        ;;
        4)
            date "${dateArgs[@]}" '+%s' 2>> '/dev/null';

            return $?;
        ;;
        5)
            date "${dateArgs[@]}" '+%F %T' 2>> '/dev/null';

            return $?;
        ;;
        6)
            date "${dateArgs[@]}" '+%F_%T' 2>> '/dev/null';

            return $?;
        ;;
        7)
            date "${dateArgs[@]}" '+%+4Y-%m-%d_%H-%M-%S' 2>> '/dev/null';

            return $?;
        ;;
        8)
            date "${dateArgs[@]}" '+%T' 2>> '/dev/null';

            return $?;
        ;;
        9)
            date "${dateArgs[@]}" '+%F' 2>> '/dev/null';

            return $?;
        ;;
    esac

    date "${dateArgs[@]}" '+%s.%N' 2>> '/dev/null';
}

Time_Diff()
{
    # Options
    # --------------------------------

    declare args; _options args \
        '?-o;?--format;-s;-d;-k;-p;-f;-r;-F;--forget-all' \
        "$@" \
    || return $?;

    declare __referenceOut="${args[0]}";
    declare __format="${args[1]}";
    declare __store="${args[2]}";
    declare __diff="${args[3]}";
    declare __printKeys="${args[4]}";
    declare __printTimes="${args[5]}";
    declare __forget="${args[6]}";
    declare __random="${args[7]}";
    declare __force="${args[8]}";
    declare __forgetAll="${args[9]}";
    declare __keys=( "${args[@]:10}" );
    unset args;

    # ----------------

    if [[ "$__referenceOut" != '' ]];
    then
        if [[ "$__referenceOut" == 'Time_Diff_referenceOut' ]];
        then
            Misc_PrintF -n -- '[Time_Diff] Output variable reference interference';

            return 100;
        fi

        unset Time_Diff_referenceOut;
        declare -n Time_Diff_referenceOut="$__referenceOut";
        Time_Diff_referenceOut=();
    fi

    if [[ "$__format" == '' ]];
    then
        declare __format='%s';
    fi

    # Main
    # --------------------------------

    if (( __forgetAll > 0 ));
    then
        _Time_timesStorage=();

        return 0;
    fi

    # If print keys and/or times
    # ----------------

    if [[ "$__printKeys" != 0 || "$__printTimes" != 0 ]];
    then
        if [[ ${#_Time_timesStorage[@]} = 0 ]];
        then
            return 1;
        fi

        declare key;

        for key in "${!_Time_timesStorage[@]}";
        do
            if [[ "$__printKeys" != 0 ]];
            then
                if [[ "$__referenceOut" != '' ]];
                then
                    Time_Diff_referenceOut+=( "$key" );
                else
                    printf -- '%s:' "$key";
                fi
            fi

            if [[ "$__printTimes" != 0 ]];
            then
                if [[ "$__referenceOut" != '' ]];
                then
                    Time_Diff_referenceOut+=( "${_Time_timesStorage["$key"]}" );
                else
                    printf -- '%s' "${_Time_timesStorage["$key"]}";
                fi
            fi

            if [[ "$__referenceOut" == '' ]];
            then
                printf $'\n';
            fi
        done

        return 0;
    fi

    # If store in random key
    # ----------------

    if [[ "$__random" != 0 ]];
    then
        if [[ "$__referenceOut" == '' ]];
        then
            return 2;
        fi

        declare key; key="$( Misc_RandomString -l 10; )";

        while [[ -v "_Time_timesStorage[${key}]" ]];
        do
            declare key; key="$( Misc_RandomString -l 10; )";
        done

        declare timeValue; timeValue="$( Time_DateTime; )";
        _Time_timesStorage["$key"]="$timeValue";
        Time_Diff_referenceOut=( "$key" );

        return 0;
    fi

    # Process times
    # ----------------

    declare keys=( "${__keys[@]}" );

    if [[ ${#keys[@]} == 0 ]];
    then
        keys=( 0 );
    fi

    # If only print certain stored times
    if [[ "$__diff" == 0 && "$__forget" == 0 && "$__store" == 0 ]];
    then
        declare keyIndex;

        for (( keyIndex = 0; keyIndex < ${#keys[@]}; keyIndex++ ));
        do
            declare key="${keys[$keyIndex]}";

            if [[ ! -v "_Time_timesStorage[${key}]" ]];
            then
                printf -- $'Could not print stored time values (no such key exists): \'%s\'\n' "$key";

                return 1;
            fi

            if [[ "$__referenceOut" != '' ]];
            then
                Time_Diff_referenceOut+=( "$( printf -- '%s:%s\n' "$key" "${_Time_timesStorage["$key"]}"; )" );
            else
                printf -- '%s:%s\n' "$key" "${_Time_timesStorage["$key"]}";
            fi
        done

        return 0;
    fi

    # Print diff of stored and/or forget stored and/or store previous/current

    declare keyIndex;

    for (( keyIndex = 0; keyIndex < ${#keys[@]}; keyIndex++ ));
    do
        declare key="${keys[$keyIndex]}";

        if [[ "$key" == '' ]];
        then
            printf -- $'Could not process time values (empty key)\n';

            return 1;
        fi

        if [[ "$__diff" != 0 ]];
        then
            if [[ ! -v "_Time_timesStorage[${key}]" ]];
            then
                printf -- $'Could not print diff of stored time value (no such key exists): \'%s\'\n' "$key";

                return 1;
            fi

            declare timeValueStored="${_Time_timesStorage["$key"]}";
            declare timeValue; timeValue="$( Time_DateTime; )";

            if [[ "$__referenceOut" != '' ]];
            then
                # shellcheck disable=SC2059
                Time_Diff_referenceOut+=( "$( printf "$__format" "$(( ( "${timeValue//./}" - "${timeValueStored//./}" ) / 1000000 ))"; )" );
            else
                # shellcheck disable=SC2059
                printf "$__format" "$(( ( "${timeValue//./}" - "${timeValueStored//./}" ) / 1000000 ))";
            fi
        fi

        if [[ "$__forget" != 0 ]];
        then
            if [[ ! -v "_Time_timesStorage[${key}]" ]];
            then
                printf -- $'Could not forget stored time value (no such key exists): \'%s\'\n' "$key";

                return 1;
            fi

            unset '_Time_timesStorage["$key"]';

            continue;
        fi

        if [[ "$__store" != 0 ]];
        then
            if [[ -v "_Time_timesStorage[${key}]" && "$__force" == 0 ]];
            then
                printf -- $'Could not store time value (key already exists): \'%s\'\n' "$key";

                return 1;
            fi

            declare timeValue; timeValue="$( Time_DateTime; )";
            _Time_timesStorage["$key"]="$timeValue";
        fi
    done

    return 0;
}
