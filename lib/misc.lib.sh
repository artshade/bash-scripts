#! /usr/bin/env bash

# Copyright 2019-2023 Artfaith

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

set -eu;

# Initials
# ----------------------------------------------------------------

declare _Misc_sourceFilepath; _Misc_sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )"; readonly _Misc_sourceFilepath;
declare _Misc_sourceDirpath; _Misc_sourceDirpath="$( dirname -- "$_Misc_sourceFilepath" 2> '/dev/null'; )"; readonly _Misc_sourceDirpath;

[[ ! -f "$_Misc_sourceFilepath" || ! -d "$_Misc_sourceDirpath" ]] && exit 99;

# Integrity
# ----------------------------------------------------------------

(
    _verifyChecksum() {
        declare __filepath="$1";
        declare __dirpath="$2";
        shift 2;

        # ----------------

        [[ ! -f "$__filepath" ]] && return 2;

        declare checksumFilepath="${__filepath}.sha256sum";

        [[ ! -f "$checksumFilepath" ]] && return "${STRICT_INTEGRITY:-0}";
        [[ ! -d "$__dirpath" || ! -x "$__dirpath" ]] && return 2;

        declare checkStatus=0;
        pushd -- "$__dirpath" > '/dev/null' || return 1;
        sha256sum -c --strict --status -- "$checksumFilepath" > '/dev/null' || declare checkStatus=$?;
        popd > '/dev/null' || return 1;

        return "$checkStatus";
    }

    _verifyChecksum "$_Misc_sourceFilepath" "$_Misc_sourceDirpath";
) || {
    printf -- $'Failed to self-verify file integrity: \'%s\'.\n' "$_Misc_sourceFilepath" >&2;

    exit 98;
}

# Libraries
# ----------------------------------------------------------------

for SHELL_LIBS_DIRPATH in \
    "${_Misc_sourceDirpath}/../lib" \
    "${_Misc_sourceDirpath}/lib" \
    "${SHELL_LIBS_DIRPATH-$_Misc_sourceDirpath}";
do
    [[ -d "$SHELL_LIBS_DIRPATH" ]] && break;
done

{
    [[ -d "${SHELL_LIBS_DIRPATH-}" ]] && export SHELL_LIBS_DIRPATH &&
    { [[ -v SHELL_LIB_OPTIONS ]] || . "${SHELL_LIBS_DIRPATH}/options.lib.sh"; } &&
        [[ "${SHELL_LIB_OPTIONS%%\:*}" == '40ee3c20078019e5308f03ad5451af724b66a5185e802c5c74dce08a0c07966d' ]]
} || {
    printf -- $'Failed to source libraries to \'%s\' from \'%s\'.\n' \
        "$_Misc_sourceFilepath" "$SHELL_LIBS_DIRPATH" 1>&2;

    exit 97;
}

# --------------------------------

declare SHELL_LIB_MISC; SHELL_LIB_MISC="$( sha256sum -b -- "$_Misc_sourceFilepath" | cut -d ' ' -f 1; ):${_Misc_sourceFilepath}";

# shellcheck disable=SC2034
readonly SHELL_LIB_MISC;

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Constants
# ----------------------------------------------------------------
# Primitives
# --------------------------------

declare -r Misc_RandomInteger_maxDefault=100;
declare -r Misc_RandomInteger_minDefault=0;
declare -r Misc_RandomString_lengthDefault=8;
declare -r Misc_RandomString_characterSetDefault='A-Za-z0-9';

# Functions
# ----------------------------------------------------------------
# Arrays
# --------------------------------

Misc_IsVarReference()
{
    declare varAttrs; varAttrs="$( declare -p "$1" 2> '/dev/null' || :; )";
    declare refVarRegex='^declare -n [^=]+=\"([^\"]+)\"$';

    [[ "$varAttrs" =~ $refVarRegex ]];
}

# Get variable type name if available.
# Recursively iterates over variable references until found any actual or unset.
# @see https://stackoverflow.com/a/42877229/5113030
Misc_VarType() {
    declare varAttrs; varAttrs="$( declare -p "$1" 2> '/dev/null' || :; )";
    declare refVarRegex='^declare -n [^=]+=\"([^\"]+)\"$';
    declare finalVarAttrs="$varAttrs";

    while [[ "$finalVarAttrs" =~ $refVarRegex ]];
    do
        declare finalVarAttrs; finalVarAttrs="$( declare -p "${BASH_REMATCH[1]}" || :; )";
    done

    case "${finalVarAttrs#declare -}"
    in
        'a '*)
            # Indexed array (e.g. '( [0]=1 [3]=2 )')
            printf -- 'array';
        ;;

        'A '*)
            # Associative array (e.g. '( [b]=2 ['A']=1 )')
            # i.e. "hash" as of Bash v5.
            printf -- 'assoc_array';
        ;;

        'i '*)
            printf -- 'integer';
        ;;

        'x '*)
            printf -- 'export';
        ;;

        # If anything else but not empty
        ?*)
            printf -- 'other';
        ;;

        # If empty
        *)
            return 1;
        ;;
    esac

    return 0;
}

Misc_IsVarOfType()
{
    if [[ "$#" != 2 ]];
    then
        return 2;
    fi

    declare typeName="$1";
    shift;
    declare varType; varType="$( Misc_VarType "$1" || :; )";
    shift;

    if [[ "$varType" == "$typeName" ]];
    then
        return 0;
    fi

    return 1;
}

Misc_ArrayExtrema()
{
    if [[ $# == 0 ]];
    then
        return 1;
    fi

    declare extremumMin="$1";
    declare extremumMax="$extremumMin";
    declare itemIndex;

    for (( itemIndex = 2; itemIndex <= $#; itemIndex++ ));
    do
        declare item="${!itemIndex}";

        if [[ ! "$item" =~ ^(0|[1-9][0-9]*)$ ]];
        then
            return 2;
        fi

        if (( item < extremumMin ));
        then
            declare extremumMin="$item";

            continue;
        fi

        if (( item > extremumMax ));
        then
            declare extremumMax="$item";
        fi
    done

    printf '%s\n' "$extremumMin" "$extremumMax";

    return 0;
}

Misc_ArrayItemsLengths()
{
    if [[ $# == 0 ]];
    then
        return 1;
    fi

    declare itemIndex;

    for (( itemIndex = 1; itemIndex <= $#; itemIndex++ ));
    do
        declare item="${!itemIndex}";

        printf '%s\n' "${#item}";
    done

    return 0;
}

Misc_ArrayItemsCount()
{
    declare item="${1-}";
    shift;
    declare count=0;
    declare itemIndex;

    for (( itemIndex = 1; itemIndex <= $#; itemIndex++ ));
    do
        if [[ "$item" == "${!itemIndex}" ]];
        then
            count=$((count + 1));
        fi
    done

    printf '%s' "$count";

    return 0;
}

# @todo Replace tith the version from "Options" library
# @todo Add support for assoc arrays if possible (JSON? Purpose?)
Misc_ArrayP()
{
    # Options
    # --------------------------------

    declare args argsC; Options args '11' \
        '?-d;?-f;-k;-e' \
        "$@" \
    || return $?;

    declare __delimiter="${args[0]}";
    declare __format="${args[1]}";
    declare __printKeys="${args[2]}";
    declare __printExtended="${args[3]}";
    declare __items=( "${args[@]:4}" );
    unset args;

    # Defaults
    # ----------------

    if [[ "${argsC[0]}" == 0 ]];
    then
        declare __delimiter=', ';
    fi

    if [[ "$__format" == '' ]];
    then
        declare __format=$'\'%s\'';
    fi

    unset argsC;

    # Main
    # --------------------------------

    declare itemCount="${#__items[@]}";

    if (( __printExtended > 0 ));
    then
        printf -- '[\n';
    fi

    declare itemIndex;

    for (( itemIndex = 0; itemIndex < ${#__items[@]}; itemIndex++ ));
    do
        if (( __printExtended > 0 ));
        then
            printf -- '    ';
        fi

        if (( __printKeys > 0 ));
        then
            printf -- "[%${#itemCount}s]=" "$itemIndex";
        fi

        printf -- "$__format" "${__items[$itemIndex]}";

        if (( itemIndex + 1 < ${#__items[@]} ));
        then
            printf '%s' "$__delimiter";
        fi

        if (( __printExtended > 0 ));
        then
            printf -- '\n';
        fi
    done

    if (( __printExtended > 0 ));
    then
        printf -- ']\n';
    fi

    return 0;
}

Misc_PrintArray()
{
    # Options
    # --------------------------------

    declare args argsC; Options args '11' \
        '/0/^[A-Za-z_][0-9A-Za-z_]*$' \
        '/4/^.$' \
        '//1?' ', ' \
        '//3?' '  ' \
        '//5?' $'\'' \
        '//6?' $'\'' \
        '?-a:--array;?-d;?-f;?-m;?-c;?-p;?-P;-k;-e;-n' \
        "$@" \
    || return $?;

    declare __referenceName="${args[0]}"; # ?-a:--array
    declare __delimiter="${args[1]}"; # ?-d
    declare __format="${args[2]}"; # ?-f
    declare __margin="${args[3]}"; # ?-m
    declare __paddingChar="${args[4]}"; # ?-c
    declare __prefix="${args[5]}"; # ?-p
    declare __postfix="${args[6]}"; # ?-P
    declare __printKeys="${args[7]}"; # -k
    declare __printExtended="${args[8]}"; # -e
    declare __newLine="${args[9]}"; # -n
    declare __items=( "${args[@]:10}" );
    unset args;

    # ----------------

    declare Misc_PrintArray_reference; # To tie with the local scope "permanently"
    unset Misc_PrintArray_reference;

    if [[ "$__referenceName" != '' ]];
    then
        if [[ "$__referenceName" == 'Misc_PrintArray_reference' ]];
        then
            Misc_PrintF -n -- '[Misc_PrintArray] Variable reference interference';

            return 100;
        fi

        declare -n Misc_PrintArray_reference="$__referenceName";

        # If reference is valid
        if
            ! Misc_IsVarOfType 'assoc_array' Misc_PrintArray_reference &&
            ! Misc_IsVarOfType 'array' Misc_PrintArray_reference;
        then
            Misc_PrintF -n -- 'Invalid reference type. Expected: indexed array or associative array.';

            return 100;
        fi
    fi

    # Main
    # --------------------------------

    # If associative array reference
    if Misc_IsVarOfType 'assoc_array' Misc_PrintArray_reference;
    then
        # If both reference and plain values are found
        if (( "${#__items[@]}" > 0 ));
        then
            return 2;
        fi

        declare itemCount="${#Misc_PrintArray_reference[@]}";
        declare maxKeyLength=0;

        if [[ "$__paddingChar" != '' ]] && (( __printExtended > 0 ));
        then
            declare itemKey;

            for itemKey in "${!Misc_PrintArray_reference[@]}";
            do
                declare keyLength="${#itemKey}";

                if (( keyLength > maxKeyLength ));
                then
                    declare maxKeyLength="$keyLength";
                fi
            done
        fi

        if [[ "${format+s}" != 's' ]];
        then
            if (( __printKeys > 0 ));
            then
                declare format="%s[%s]%s%s";
            else
                declare format='%s';
            fi
        fi

        if (( __printExtended > 0 ));
        then
            printf -- '[\n';
        fi

        declare itemIndex=0;
        declare itemKey;

        for itemKey in "${!Misc_PrintArray_reference[@]}";
        do
            declare item="${Misc_PrintArray_reference[$itemKey]}";

            if (( __printExtended > 0 ));
            then
                printf -- '%s' "$__margin";
            fi

            declare padding='';

            if (( maxKeyLength > 0 ));
            then
                declare padding; padding="$(
                    declare i;
                    for (( i = 0; i < (maxKeyLength - ${#itemKey}); i++ )); do printf '%s' "$__paddingChar"; done;
                )";
            fi

            if (( __printKeys > 0 ));
            then
                # shellcheck disable=SC2059
                printf -- "$format" "$padding" "'${itemKey}'" "$( (( __printExtended == 0 )) && printf '=' || printf ' '; )" \
                    "${__prefix}${item}${__postfix}";
            else
                # shellcheck disable=SC2059
                printf -- "$format" "${__prefix}${item}${__postfix}";
            fi

            if (( __printExtended > 0 ));
            then
                printf -- '\n';
            else
                if (( itemIndex + 1 < itemCount ));
                then
                    printf '%s' "$__delimiter";
                fi
            fi

            declare itemIndex="$(( itemIndex + 1 ))";
        done

        if (( __printExtended > 0 ));
        then
            printf -- ']';
        fi

        declare newLineIndex;

        for (( newLineIndex = 0; newLineIndex < __newLine; newLineIndex++ ));
        do
            printf -- '\n';
        done

        return 0;
    fi

    # Indexed array

    declare items=();

    # If array reference
    if Misc_IsVarOfType 'array' Misc_PrintArray_reference;
    then
        # If both reference and plain values are found
        if (( "${#__items[@]}" > 0 ));
        then
            return 2;
        fi

        declare items=( "${Misc_PrintArray_reference[@]}" );
    elif (( "${#__items[@]}" > 0 ));
    then
        declare items=( "${__items[@]}" );
    # else
    #     return 0;
    fi

    declare itemCount="${#items[@]}";

    if [[ "${format+s}" != 's' ]];
    then
        if (( __printKeys > 0 ));
        then
            declare format; format="[%s%s]%s%s";
        else
            declare format='%s';
        fi
    fi

    if (( __printExtended > 0 ));
    then
        printf -- '[\n';
    fi

    for (( itemIndex = 0; itemIndex < itemCount; itemIndex++ ));
    do
        if (( __printExtended > 0 ));
        then
            printf -- '%s' "$__margin";
        fi

        declare padding='';

        if [[ "$__paddingChar" != '' ]];
        then
            declare padding; padding="$(
                declare z="$(( itemCount - 1 ))";
                declare i;
                for (( i = 0; i < (${#z} - ${#itemIndex}); i++ )); do printf '%s' "$__paddingChar"; done;
            )";
        fi

        if (( __printKeys > 0 ));
        then
            # shellcheck disable=SC2059
            printf -- "$format" "$padding" "$itemIndex" "$( (( __printExtended == 0 )) && printf '=' || printf ' '; )" \
                "${__prefix}${items[itemIndex]}${__postfix}";
        else
            # shellcheck disable=SC2059
            printf -- "$format" "${__prefix}${items[itemIndex]}${__postfix}";
        fi

        if (( __printExtended > 0 ));
        then
            printf -- '\n';
        else
            if (( itemIndex + 1 < itemCount ));
            then
                printf '%s' "$__delimiter";
            fi
        fi
    done

    if (( __printExtended > 0 ));
    then
        printf -- ']';
    fi

    declare newLineIndex;

    for (( newLineIndex = 0; newLineIndex < __newLine; newLineIndex++ ));
    do
        printf -- '\n';
    done

    return 0;
}

# Random
# --------------------------------

Misc_RandomInteger()
{
    # Options
    # --------------------------------

    declare args argsC; Options args '11' \
        '/0/^(?:0|[1-9][0-9]*)\-?(?:0|[1-9][0-9]*)?$' \
        '/1/^(?:0|[1-9][0-9]*)$' \
        '?--range:-m:-r:-n;?-c;?-d;?-f' \
        "$@" \
    || return $?;

    declare __range="${args[0]}";
    declare __count="${args[1]}";
    declare __delimiter="${args[2]}";
    declare __format="${args[3]}";
    unset args;

    # ----------------

    if [[ "$__count" == '' ]];
    then
        declare __count=1;
    fi

    if [[ "${argsC[3]}" == 0 ]];
    then
        declare __delimiter=$'\n';
    fi

    if [[ "$__format" == '' ]];
    then
        declare __format='%s';
    fi

    unset argsC;

    # Main
    # --------------------------------

    declare __min="$Misc_RandomInteger_minDefault";
    declare __max="$Misc_RandomInteger_maxDefault";

    if [ "$__range" != '' ];
    then
        if [[ "$__range" =~ ^[0-9]+\-[0-9]+$ ]]; # If "min-max" - min and max
        then
            __min="${__range%\-*}";
            __max="${__range#*\-}";
        elif [[ "$__range" =~ ^[0-9]+\-$ ]]; # If "min-" - only min
        then
            __min="${__range%\-*}";
        elif [[ "$__range" =~ ^[0-9]+$ ]]; # If "max" - only max
        then
            __max="$__range";
        fi
    fi

    if (( __min > __max || __min == __max ));
    then
        return 1;
    fi

    declare iteration;

    for (( iteration = 0; iteration < __count; iteration++ ));
    do
        declare value; value="$( shuf --random-source='/dev/urandom' -i "${__min}-${__max}" -n 1 2>> '/dev/null'; )";

        if [[ $? != 0 ]];
        then
            return 2;
        fi

        printf -- "${__format}" "$value";

        if (( iteration + 1 < __count ));
        then
            printf '%s' "$__delimiter";
        fi
    done

    return 0;
}

Misc_RandomString()
{
    # Options
    # --------------------------------

    declare args argsC; Options args '11' \
        '/0/^(?:0|[1-9][0-9]*)$' \
        '/1/^(?:0|[1-9][0-9]*)$' \
        '?-l;?-c;?-d;?-f;?-s' \
        "$@" \
    || return $?;

    declare __length="${args[0]}";
    declare __count="${args[1]}";
    declare __delimiter="${args[2]}";
    declare __format="${args[3]}";
    declare __characterSet="${args[4]}";
    unset args;

    # ----------------

    if [[ "$__length" == '' ]];
    then
        declare __length="$Misc_RandomString_lengthDefault";
    fi

    if [[ "$__count" == '' ]];
    then
        declare __count=1;
    fi

    if [[ "${argsC[2]}" == 0 ]];
    then
        declare __delimiter=$'\n';
    fi

    if [[ "$__format" == '' ]];
    then
        declare __format='%s';
    fi

    if [[ "$__characterSet" == '' ]];
    then
        declare __characterSet="$Misc_RandomString_characterSetDefault";
    fi

    unset argsC;

    # Main
    # --------------------------------

    declare iteration;

    for (( iteration = 0; iteration < __count; iteration++ ));
    do
        declare value; value="$( head '/dev/urandom' | tr -dc "$__characterSet" | head -c "$__length" 2>> '/dev/null'; )";

        if [[ $? != 0 ]];
        then
            return 1;
        fi

        printf -- "${__format}" "$value";

        if (( iteration + 1 < __count ));
        then
            printf '%s' "$__delimiter";
        fi
    done

    return 0;
}

# Regex
# --------------------------------

Misc_IsRegexValid()
{
    for value in "$@";
    do
        if ! IFS=$' \t\n' printf '%s' "$value" | perl -ne 'eval { qr/$_/ }; die if $@;' &>> '/dev/null';
        then
            return 1;
        fi
    done

    return 0;
}

# @todo Add a regex function for files
Misc_Regex()
{
    # Options
    # --------------------------------

    declare args argsC; Options args '11' \
        '!?-s;?-r;-c;-t;-i' \
        "$@" \
    || return $?;

    declare __searchRegex="${args[0]}";
    declare __replacement="${args[1]}";
    declare __printMatchCount="${args[2]}";
    declare __printTotal="${args[3]}";
    declare __ignoreCount="${args[4]}";
    declare __items=( "${args[@]:5}" );
    unset args;

    # If no regex replace was provided
    if (( argsC[1] == 0 ));
    then
        unset __replacement;
    fi

    # Main
    # --------------------------------

    if ! Misc_RegexVerify "$__searchRegex";
    then
        return 2;
    fi

    declare outStream='/dev/stdout';
    declare errStream='/dev/stderr';
    declare itemCount="${#__items[@]}";
    declare itemMatchCount=0;

    # If no replacement is provided
    if [[ "${__replacement+s}" == '' ]];
    then
        # Search only

        declare itemIndex;

        for (( itemIndex = 0; itemIndex < itemCount; itemIndex++ ));
        do
            declare item="${__items[itemIndex]}";

            if
                IFS=$' \t\n' \
                ITEM="$item" \
                SEARCH_REGEX="$__searchRegex" \
                PRINT_COUNT="$__printMatchCount" \
                    perl -e $'
                        use strict;

                        my @matches = $ENV{ITEM} =~ /$ENV{SEARCH_REGEX}/g;
                        my $matchCount = scalar @matches;

                        if ($ENV{PRINT_COUNT} > 0) {
                            print "${matchCount}\n";
                        }

                        END {
                            exit 1 unless $matchCount > 0
                        }' \
                            > "$outStream" 2> "$errStream";
            then
                declare itemMatchCount="$(( itemMatchCount + 1 ))";
            fi
        done

        if (( __printTotal > 0 ));
        then
            printf -- $'%s\n' "$itemMatchCount";
        fi

        if (( itemMatchCount > 0 || __ignoreCount > 0 ));
        then
            return 0;
        fi

        return 1;
    fi

    # Search and replace

    declare itemIndex;

    for (( itemIndex = 0; itemIndex < itemCount; itemIndex++ ));
    do
        declare item="${__items[itemIndex]}";

        if
            IFS=$' \t\n' \
            ITEM="$item" \
            SEARCH_REGEX="$__searchRegex" \
            REPLACEMENT="$__replacement" \
            PRINT_COUNT="$__printMatchCount" \
                perl -e $'
                    use strict;

                    my $matchCount = 0;
                    my $line = "$ENV{ITEM}";

                    while ($line =~ s/$ENV{SEARCH_REGEX}/$ENV{REPLACEMENT}/) {
                        $matchCount++;
                    }

                    if ($ENV{PRINT_COUNT} > 0) {
                        print "${matchCount}\n";
                    }

                    print "${line}\n";

                    END {
                        exit 1 unless $matchCount > 0
                    }' \
                        > "$outStream" 2> "$errStream";
        then
            declare itemMatchCount="$(( itemMatchCount + 1 ))";
        fi
    done

    if (( __printTotal > 0 ));
    then
        printf -- $'%s\n' "$itemMatchCount";
    fi

    if (( itemMatchCount > 0 || __ignoreCount > 0 ));
    then
        return 0;
    fi

    return 1;
}

# Misc_Regex()
# {
#     # Options
#     # --------------------------------

#     declare args argsC; Options args '11' \
#         '!?-s;?-r;-f' \
#         "$@" \
#     || return $?;

#     declare __searchPattern="${args[0]}";
#     declare __replacePattern="${args[1]}";
#     declare __inFiles="${args[2]}";
#     declare __items=( "${args[@]}:3" );
#     unset args;

#     # # If no regex replace was provided
#     # if (( argsC[1] == 0 ));
#     # then
#     #     unset __replacePattern;
#     # fi

#     # Main
#     # --------------------------------

#     if ! Misc_RegexVerify "$__searchPattern";
#     then
#         printf -- $'Could not regex replace. Invalid search pattern: \'%s\'\n' "$__searchPattern";

#         return 2;
#     fi

#     if [[ "${patternReplace:+s}" != '' ]] && ! Misc_RegexVerify "$patternReplace";
#     then
#         printf -- $'Could not regex replace. Invalid replace pattern: \'%s\'\n' "$__searchPattern";

#         return 2;
#     fi

#     # TODO: Find a non-conflict alternative. A subshell?
#     if [[ "${patternSearchExported+s}" != '' || "${patternReplaceExported+s}" != '' ]];
#     then
#         printf -- $'Regex replace conflict\n';

#         return 2;
#     fi

#     export patternSearchExported="$patternSearch";
#     export patternReplaceExported="$patternReplace";
#     # declare perlReplaceBackupExtension='.backup';

#     # Reason of two declarations: Shellcheck SC2178 bug.
#     # @see https://www.shellcheck.net/wiki/SC2178
#     declare matches;
#     declare matches=0;

#     for filepath in "${filepaths[@]}";
#     do
#         if [ ! -f "$filepath" ];
#         then
#             printf -- $'No such file to regex replace: "%s"\n' "$filepath";
#         fi

#         if IFS=$' \t\n' perl -pi"${perlReplaceBackupExtension:-}" -e 's/$ENV{patternSearchExported}/$ENV{patternReplaceExported}/g && $MATCH++; END{exit 1 unless $MATCH > 0}' "$filepath";
#         then
#             # if [[ "${perlReplaceBackupExtension-}" != '' ]];
#             # then
#             #     rm "${filepath}.${perlReplaceBackupExtension}";
#             # fi

#             # Disable reason: Shellcheck SC2178 bug.
#             # shellcheck disable=SC2178
#             declare matches="$((matches + 1))";
#         # else
#         #     printf $'No regex match for \'%s\' to replace in \'%s\'\n' "$patternSearch" "$filepath";
#         fi
#     done

#     unset patternSearchExported;
#     unset patternReplaceExported;

#     [[ "$matches" != 0 ]];
# }

# Description: The [string] data regex
#
# Options:
#    -s (parameter) - Search RegEx pattern
#    -o (parameter) - Output variable reference
#    -r (parameter) - Replace RegEx pattern (rewrite files)
#    -R (multi-flag) - Remove empty lines from the file: 1 flag = only if left by replacement; 2 flags = remove every empty lines; 3 - every empty line including spaces.
#    -v (flag) - Verbose
#     * - Data
#
# Returns:
#    0 ~ Found any match or replaced any data
#    1 ~ No match found or no data replaced
#    2 ~ Invalid search RegEx pattern
#    3 ~ Invalid replace RegEx pattern
#    4 ~ Empty search RegEx pattern
#    100 ~ Output variable reference interference
#    101 ~ No data declared
#    200 ~ Invalid options
#
# Outputs:
#    1. Output variable reference
#        1.1. If only search for matches, then 5 arrays: {ref} (matches), {ref}Indexes, {ref}Lines, {ref}Positions, {ref}Offsets
#        1.2. If replace matches, then 8 arrays:
#            {ref} (processed),
#            {ref}Replaced,
#            {ref}Indexes, {ref}Lines, {ref}Positions, {ref}Offsets, {ref}SourcePositions, {ref}SourceOffsets
#
Misc_AdvancedRegex()
{
    # Options
    # --------------------------------

    declare args argsC; Options args '11' \
        '/3/^(?:[0-9]+)?(?:,)?(?:[0-9]+)?$' \
        '/4/^[0-1]$' \
        '/5/^[0-4]$' \
        '/6/^[0-1]$' \
        '!?-s;?-o;?-r;?-c;-S;-R' \
        "$@" \
    || return $?;

    declare patternSearch="${args[0]}";
    declare outputVariableReferenceName="${args[1]}";
    unset patternReplace;
    [ "${argsC[2]}" != 0 ] && declare patternReplace="${args[2]}";
    declare matchCountMinMax="${args[3]}";
    declare streamsOutput="${args[4]}";
    declare removeEmptyLines="${args[5]}";
    declare data=( "${args[@]:6}" );
    unset args argsC;

    # Defaults
    # ----------------

    if [ "$outputVariableReferenceName" != '' ];
    then
        # If the output reference matches the important variables.
        # Both the reference and temp must mismatch or else the first would cause a reference loop and the second (temp) would return an empty result
        if
            [ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReference' ] ||
            [ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceIndexes' ] ||
            [ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceLines' ] ||
            [ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceOffsets' ]
        then
            Misc_PrintF -v 1 -t 'f' -nf $'[Misc_Regex] Output variable reference interference: \'%s\'' -- \
                "$( Misc_ArrayJoin -- "$@" )";

            return 100;
        fi

        # Declare and set/clear referenced variables

        declare -n Misc_Regex_outputVariableReference="$outputVariableReferenceName";
        declare -n Misc_Regex_outputVariableReferenceIndexes="${outputVariableReferenceName}Indexes";
        declare -n Misc_Regex_outputVariableReferenceLines="${outputVariableReferenceName}Lines";
        declare -n Misc_Regex_outputVariableReferenceOffsets="${outputVariableReferenceName}Offsets";
        Misc_Regex_outputVariableReference=();
        Misc_Regex_outputVariableReferenceIndexes=();
        Misc_Regex_outputVariableReferenceLines=();
        Misc_Regex_outputVariableReferenceOffsets=();
    fi

    declare matchCountMin='';
    declare matchCountMax='';

    if [ "$matchCountMinMax" != '' ];
    then
        if [[ "$matchCountMinMax" =~ ^[0-9]+,[0-9]+$ ]]; # If "min,max" - min and max
        then
            matchCountMin="${matchCountMinMax%,*}";
            matchCountMax="${matchCountMinMax#*,}";
        elif [[ "$matchCountMinMax" =~ ^[0-9]+,$ ]]; # If "min," - only min
        then
            matchCountMin="${matchCountMinMax%,*}";
        elif [[ "$matchCountMinMax" =~ ^,[0-9]+$ ]]; # If ",max" - only max
        then
            matchCountMax="${matchCountMinMax#*,}";
        elif [[ "$matchCountMinMax" =~ ^[0-9]+$ ]]; # If just a number - min=max
        then
            matchCountMin="${matchCountMinMax%,*}";
            matchCountMax="$matchCountMin";
        fi
    fi

    ########
    # Main #
    ########

    # If no search regex pattern is provided
    if [ "${#patternSearch}" = 0 ];
    then
        # if [ "$verbose" != 0 ];
        # then
        #     Misc_PrintF -v 1 -t 'f' -nf $'Empty search pattern declared for regex %s\n\n' \
        #         "$( [[ "${patternReplace+s}" != '' ]] && printf 'replace' || printf 'search' )";
        # fi

        return 4;
    fi

    # If no data is declared
    if [ "${#data[@]}" = 0 ];
    then
        # if [ "$verbose" != 0 ];
        # then
        #     Misc_PrintF -v 1 -t 'f' -nf $'No data declared for regex %s\n' \
        #         "$(
        #             if [[ "${patternReplace+s}" != '' ]];
        #             then
        #                 printf $'replace: \'%s\' -> \'%s\'' "$patternSearch" "$patternReplace";
        #             else
        #                 printf $'search: \'%s\'' "$patternSearch";
        #             fi
        #         )";
        # fi

        return 101;
    fi

    if ! Misc_IsRegexValid "$patternSearch";
    then
        # if [ "$verbose" != 0 ];
        # then
        #     Misc_PrintF -v 1 -t 'f' -nf $'Invalid search pattern was declared for regex %s: \'%s\'\n\n' \
        #         "$( [ "${patternReplace+s}" != '' ] && printf 'replace' || printf 'search' )" \
        #         "$patternSearch";
        # fi

        return 2;
    fi

    # If a replace pattern is declared (even empty)
    if [ "${patternReplace+s}" != '' ];
    then
        # Search and replace
        # --------------------------------

        # If output reference variable is declared (requested to store results in referenced variables)
        if [ "$outputVariableReferenceName" != '' ];
        then
            if
                [ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceSkips' ] ||
                [ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceSourceStarts' ] ||
                [ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceSourceEnds' ] ||
                [ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceStarts' ] ||
                [ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceEnds' ] ||
                [ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceDifferences' ] ||
                [ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferenceMatches' ]
            then
                Misc_PrintF -v 1 -t 'f' -nf $'[Misc_Regex] Output variable reference interference: \'%s\'' -- \
                    "$( Misc_ArrayJoin -- "$@" )";

                return 100;
            fi

            # Declare and set/clear referenced variables
            declare -n Misc_Regex_outputVariableReferenceSkips="${outputVariableReferenceName}Skips";
            declare -n Misc_Regex_outputVariableReferenceSourceStarts="${outputVariableReferenceName}SourceStarts";
            declare -n Misc_Regex_outputVariableReferenceSourceEnds="${outputVariableReferenceName}SourceEnds";
            declare -n Misc_Regex_outputVariableReferenceStarts="${outputVariableReferenceName}Starts";
            declare -n Misc_Regex_outputVariableReferenceEnds="${outputVariableReferenceName}Ends";
            declare -n Misc_Regex_outputVariableReferenceDifferences="${outputVariableReferenceName}Differences";
            declare -n Misc_Regex_outputVariableReferenceMatches="${outputVariableReferenceName}Matches";

            Misc_Regex_outputVariableReferenceSkips=();
            Misc_Regex_outputVariableReferenceSourceStarts=();
            Misc_Regex_outputVariableReferenceSourceEnds=();
            Misc_Regex_outputVariableReferenceStarts=();
            Misc_Regex_outputVariableReferenceEnds=();
            Misc_Regex_outputVariableReferenceDifferences=();
            Misc_Regex_outputVariableReferenceMatches=();
        fi

        export patternSearchExported="$patternSearch";
        export patternReplaceExported="$patternReplace";
        export removeEmptyLinesExported="$removeEmptyLines";
        declare replaceOffsets=();
        declare replaceSkips=();
        declare replaces=();
        declare replaceMetas=();
        declare dataIndex;

        for (( dataIndex = 0; dataIndex < ${#data[@]}; dataIndex++ ));
        do
            declare dataElement="${data[$dataIndex]}";

            if [ "$dataElement" = '' ];
            then
                # if [ "$verbose" != 0 ];
                # then
                #     Misc_PrintF -v 3 -t 'w' -nf $'Empty data declared for regex replace at %s argument' -- "$dataIndex";
                # fi

                continue;
            fi

            declare replaceRaw;
            declare replaceIndex=0;

            # Process the regex operation and loop through every replace
            while IFS= read -r replaceRaw; # L:Ss:Se:Rs:Re:D:{match}
            do
                # If it's a line byte offset
                if [ "${replaceRaw:0:1}" = '#' ];
                then
                    declare replaceOffsets+=( "${replaceRaw:1}" );

                    continue;
                fi

                # If it's a line byte offset
                if [ "${replaceRaw:0:1}" = '!' ];
                then
                    declare replaceSkips+=( "${replaceRaw:1}" );

                    continue;
                fi

                # If it's a replaced element
                if [ "${replaceRaw:0:1}" = '@' ];
                then
                    declare replaces+=( "${replaceRaw:1}" );

                    continue;
                fi

                # Add the match to the array
                replaceMetas+=( "${dataIndex}:${replaceRaw}" );

                # if (( verbose > 1 )) && Misc_Verbosity 5;
                # then
                #     declare replaceMeta=""; # For: L:Ss:Se:Rs:Re:D:{match} ~> L:Ss:Se:Rs:Re:D
                #     declare replaceMatch="$replaceRaw"; # For: L:Ss:Se:Rs:Re:D:{match} ~> {match}

                #     for (( i = 0; i < 6; i++ ));
                #     do
                #         declare replaceMeta="${replaceMeta}${replaceMatch%%\:*},";
                #         declare replaceMatch="${replaceMatch#*\:}";
                #     done

                #     declare replaceLine="${replaceMeta%%\:*}"; # L:Ss:Se:Rs:Re:D ~> L
                #     declare replaceOffset=0;

                #     if [ "${replaceOffsets[$replaceLine]+s}" != '' ];
                #     then
                #         declare replaceOffset="${replaceOffsets[$replaceLine]+s}";
                #     fi

                #     Misc_PrintF -v 5 -t 'd' -f $'Replaced %s match at [%s;%s] in %s/%s element using regex \'%s\' -> \'%s\': \'%s\'%s\n' -- \
                #         "$(( replaceIndex + 1 ))" \
                #         "$replaceMeta" \
                #         "$replaceOffset" \
                #         "$(( dataIndex + 1 ))" \
                #         "${#data[@]}" \
                #         "$patternSearch" \
                #         "$patternReplace" \
                #         "${replaceMatch:0:20}" \
                #         "$( (( "${#replaceMatch}" > 20 )) && printf '...' )";
                # fi

                declare replaceIndex=$(( replaceIndex + 1 ));
            done \
            < <(
                # i.e. L:Ss:Se:Rs:Re:D:{match}; #offset; !skipped; @processed; or:
                # 0:1:2:3:4:5:6 -
                #     0 - Line number
                #     1 - Source match start position (relative to processed)
                #     2 - Source match end position (relative to processed)
                #     3 - Replace start position (relative to processed)
                #     4 - Replace end position (relative to processed)
                #     5 - Replace length difference
                #     6 - Match
                # # - Line byte offeset
                # ! - Skipped line
                # @ - Processed line
                printf '%s' "$dataElement" | perl -ne $'
                    use strict;

                    # From package "Data::Munge" (v0.097; line 122)
                    sub submatches {
                        no strict \'refs\';
                        map $$_, 1 .. $#+
                    }

                    # From package "Data::Munge" (v0.097; line 96)
                    sub replace {
                        my ($str, $re, $x, $g) = @_;

                        my $f = ref $x ? $x : sub {
                            my $r = $x;

                            $r =~ s{\$([\$&`\'0-9]|\{([0-9]+)\})}{
                                $+ eq \'$\' ? \'$\' :
                                $+ eq \'&\' ? $_[0] :
                                $+ eq \'`\' ? substr($_[-1], 0, $_[-2]) :
                                $+ eq "\'" ? substr($_[-1], $_[-2] + length $_[0]) :
                                $_[$+]
                            }eg;

                            $r
                        };

                        if ($g) {
                            $str =~ s{$re}{ $f->(substr($str, $-[0], $+[0] - $-[0]), submatches(), $-[0], $str) }eg;
                        } else {
                            $str =~ s{$re}{ $f->(substr($str, $-[0], $+[0] - $-[0]), submatches(), $-[0], $str) }e;
                        }

                        $str
                    }

                    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

                    $processed = $_; # Get the source line
                    $processed =~ s/\n+$//; # Remove last trailing new line characters # or is "perl -nle" better?
                    $result = "";
                    $matchEndPrevious = 0;
                    $replacedDiffPrevious = 0;

                    # While any match exists
                    while ($processed =~ /$ENV{patternSearchExported}/ && length $processed)
                    {
                        $match = substr($processed, $-[0], $+[0] - $-[0]);
                        $replaced = replace($processed, $ENV{patternSearchExported}, $ENV{patternReplaceExported}); # Replace the match
                        $replacedDiff = ((length $replaced) - (length $processed)); # Get the length difference between the source and replaced
                        $result = $result . substr($replaced, 0, $+[0] + $replacedDiff); # Append data from source start to replace end
                        $processed = substr($processed, $+[0]); # Remove data from the start to the match end (so to not match the same in the loop)

                        print (
                            join (
                                ":",
                                $., # Line number (0)
                                ($matchEndPrevious + $-[0]), # Source match start position (1) (relative to processed)
                                ($matchEndPrevious + $+[0]), # Source match end position (2) (relative to processed)
                                ($matchEndPrevious + $-[0] + $replacedDiffPrevious), # Replace start position (3) (relative to processed)
                                ($matchEndPrevious + $+[0] + $replacedDiffPrevious + $replacedDiff), # Replace end position (4) (relative to processed)
                                $replacedDiff, # Replace length difference (5)
                                $match # Match (6)
                            ) . "\n"
                        );

                        $matchEndPrevious += $+[0]; # Preserve the match end position
                        $replacedDiffPrevious += $replacedDiff; # Preserve the replace difference
                    }

                    print "#" . tell . "\n"; # Print the line byte offset

                    $result = $result . $processed; # Append the source leftover

                    # If whitespace:
                    #     "1" - If source is not empty but result;
                    #     "2" - If source is not empty but result is empty or contains only space characters;
                    #     "3" - If result is empty;
                    #     "4" - If result is empty or contains only space characters.
                    if (
                        $ENV{removeEmptyLinesExported} == 1 && length $_ && $result =~ /^$/ ||
                        $ENV{removeEmptyLinesExported} == 2 && length $_ && $result =~ /^\s*$/ ||
                        $ENV{removeEmptyLinesExported} == 3 && $result =~ /^$/ ||
                        $ENV{removeEmptyLinesExported} == 4 && $result =~ /^\s*$/
                    ) {
                        print "\!" . $. . "\n"; # Print the skipped line number
                        next; # Skip the line
                    }

                    print "\@" . $result . "\n"; # Print the processed line (either replaced or not)
                ';
            );

            # if [ "$verbose" != 0 ];
            # then
            #     Misc_PrintF -v 4 -t 's' -f $'Replaced %s matches in total using regex pattern (\'%s\' -> \'%s\') in %s/%s element\n' -- \
            #         "${#replaceMetas[@]}" \
            #         "$patternSearch" \
            #         "$patternReplace" \
            #         "$(( dataIndex + 1 ))" \
            #         "${#data[@]}";
            # fi
        done

        unset patternSearchExported;
        unset patternReplaceExported;
        unset removeEmptyLinesExported;

        # If no limit is declared and did not find any match
        if [ "$matchCountMin" = '' ] && [ "$matchCountMax" = '' ] && [ "${#replaceMetas[@]}" = 0 ];
        then
            return 1;
        fi

        # If too few replaces
        if [ "$matchCountMin" != '' ] && (( ${#replaceMetas[@]} < matchCountMin ));
        then
            # if [ "$verbose" != 0 ];
            # then
            #     Misc_PrintF -v 2 -t 'e' -f $'Too few (minimum %s) replaces: %s\n' -- \
            #         "$matchCountMin" \
            #         "${#replaceMetas[@]}";
            # fi

            return 2;
        fi

        # If too many replaces
        if [ "$matchCountMax" != '' ] && (( ${#replaces[@]} > matchCountMax ));
        then
            # if [ "$verbose" != 0 ];
            # then
            #     Misc_PrintF -v 2 -t 'e' -f $'Too many (maximum %s) replaces: %s\n' -- \
            #         "$matchCountMax" \
            #         "${#replaceMetas[@]}";
            # fi

            return 3;
        fi

        if [ "$streamsOutput" = 1 ];
        then
            # If a single replace (no new line)
            if [ "${#replaces[@]}" = 1 ];
            then
                printf '%s' "${replaces[0]}";

                return 0;
            fi

            # If more than one replace (each line)
            declare replace;

            for replace in "${replaces[@]}";
            do
                printf $'%s\n' "$replace";
            done

            return 0;
        fi

        # If no output reference variable is declared
        if [ "$outputVariableReferenceName" = '' ];
        then
            return 0;
        fi

        # Requested to store results in a referenced variable
        Misc_Regex_outputVariableReference=( "${replaces[@]}" );
        Misc_Regex_outputVariableReferenceOffsets=( "${replaceOffsets[@]}" );

        # shellcheck disable=SC2034
        Misc_Regex_outputVariableReferenceSkips=( "${replaceSkips[@]}" );

        declare metaIndex;

        # Loop through every replace meta
        for (( metaIndex = 0; metaIndex < ${#replaceMetas[@]}; metaIndex++ ));
        do
            declare metaTemp="${replaceMetas[$metaIndex]}"; # I:L:Ss:Se:Rs:Re:D:{match}
            Misc_Regex_outputVariableReferenceIndexes+=( "${metaTemp%%\:*}" ); # I:L:Ss:Se:Rs:Re:D:{match} ~> I

            declare metaTemp="${metaTemp#*\:}"; # I:L:Ss:Se:Rs:Re:D:{match} ~> L:Ss:Se:Rs:Re:D:{match}
            Misc_Regex_outputVariableReferenceLines+=( "${metaTemp%%\:*}" ); # L:Ss:Se:Rs:Re:D:{match} ~> L

            declare metaTemp="${metaTemp#*\:}"; # L:Ss:Se:Rs:Re:D:{match} ~> Ss:Se:Rs:Re:D:{match}
            Misc_Regex_outputVariableReferenceSourceStarts+=( "${metaTemp%%\:*}" ); # Ss:Se:Rs:Re:D:{match} ~> Ss

            declare metaTemp="${metaTemp#*\:}"; # Ss:Se:Rs:Re:D:{match} ~> Se:Rs:Re:D:{match}
            Misc_Regex_outputVariableReferenceSourceEnds+=( "${metaTemp%%\:*}" ); # Se:Rs:Re:D:{match} ~> Se

            declare metaTemp="${metaTemp#*\:}"; # Se:Rs:Re:D:{match} ~> Rs:Re:D:{match}
            Misc_Regex_outputVariableReferenceStarts+=( "${metaTemp%%\:*}" ); # Rs:Re:D:{match} ~> Rs

            declare metaTemp="${metaTemp#*\:}"; # Rs:Re:D:{match} ~> Re:D:{match}
            Misc_Regex_outputVariableReferenceEnds+=( "${metaTemp%%\:*}" ); # Re:D:{match} ~> Re

            declare metaTemp="${metaTemp#*\:}"; # Re:D:{match} ~> D:{match}
            Misc_Regex_outputVariableReferenceDifferences+=( "${metaTemp%%\:*}" ); # D:{match} ~> D
            Misc_Regex_outputVariableReferenceMatches+=( "${metaTemp#*\:}" ); # D:{match} ~> {match}
        done

        return 0;
    fi

    # Search
    # --------------------------------

    # If output reference variable is declared (requested to store results in referenced variables)
    if [ "$outputVariableReferenceName" != '' ];
    then
        if [ "$outputVariableReferenceName" = 'Misc_Regex_outputVariableReferencePositions' ]
        then
            Misc_PrintF -v 1 -t 'f' -nf $'[Misc_Regex] Output variable reference interference: \'%s\'' -- \
                "$( Misc_ArrayJoin -- "$@" )";
            return 100;
        fi

        declare -n Misc_Regex_outputVariableReferencePositions="${outputVariableReferenceName}Positions";
        Misc_Regex_outputVariableReferencePositions=();
    fi

    export patternSearchExported="$patternSearch";
    declare matches=();
    declare dataIndex;

    for (( dataIndex = 0; dataIndex < ${#data[@]}; dataIndex++ ));
    do
        declare dataElement="${data[$dataIndex]}";

        if [ "$dataElement" = '' ];
        then
            # if [ "$verbose" != 0 ];
            # then
            #     Misc_PrintF -v 3 -t 'w' -nf $'Empty data declared for regex search at %s argument' -- "$dataIndex";
            # fi

            continue;
        fi

        declare matchRaw;
        declare matchIndex=0;

        # Process the regex opertaion and loop through every found match
        while IFS= read -r matchRaw # i.e. L:P:O:{match}
        do
            # Add the match to the array
            matches+=( "${dataIndex}:${matchRaw}" );

            # if [ "$verbose" != 0 ] && Misc_Verbosity 5;
            # then
            #     declare matchLine="${matchRaw%%\:*}"; # L:P:O:{match} ~> L
            #     declare match="${matchRaw#*\:}"; # L:P:O:{match} ~> P:O:{match}
            #     declare matchPosition="${match%%\:*}"; # P:O:{match} ~> P
            #     declare match="${match#*\:}"; # P:O:{match} ~> O:{match}
            #     declare matchOffset="${match%%\:*}"; # O:{match} ~> O
            #     declare match="${match#*\:}"; # O:{match} ~> {match}

            #     Misc_PrintF -v 5 -t 'd' -f $'Found %s match at [%4s,%4s,%4s] in %s/%s element using regex pattern(\'%s\'): \'%s\'%s\n' -- \
            #         "$(( matchIndex + 1 ))" \
            #         "$matchLine" \
            #         "$matchPosition" \
            #         "$matchOffset" \
            #         "$(( dataIndex + 1 ))" \
            #         "${#data[@]}" \
            #         "$patternSearch" \
            #         "${match:0:20}" \
            #         "$( (( "${#match}" > 20 )) && printf '...' )";
            # fi

            declare matchIndex=$(( matchIndex + 1 ));
        done \
        < <( # i.e. L:P:O:{match}
            # | perl -ne 'if (!/$ENV{patternSearchExported}/g) { exit 1; }; print $1; exit 0;
            printf '%s' "$dataElement" | perl -nle \
                $'
                    $line=$_;
                    $o;
                    while (/$ENV{patternSearchExported}/g)
                    {
                        print join ":", $., $-[0], $o + $-[0], $&;
                    }
                    $o = tell;
                ' \
                    2> '/dev/null';
        );

        # # declare matchLineCount="${#matches[@]}";
        # if [ "$verbose" != 0 ];
        # then
        #     Misc_PrintF -v 4 -t 's' -f $'Found %s match(es) in total using regex pattern (\'%s\') in %s/%s element\n' -- \
        #         "${#matches[@]}" \
        #         "$patternSearch" \
        #         "$(( dataIndex + 1 ))" \
        #         "${#data[@]}";
        # fi
    done

    unset patternSearchExported;

    # If no limit is declared and did not find any match
    if [ "$matchCountMin" = '' ] && [ "$matchCountMax" = '' ] && [ "${#matches[@]}" = 0 ];
    then
        # if [ "$verbose" != 0 ];
        # then
        #     Misc_PrintF -v 2 -t 'e' -f $'No match found\n';
        # fi

        return 1;
    fi

    # If too few matches
    if [ "$matchCountMin" != '' ] && (( ${#matches[@]} < matchCountMin ));
    then
        # if [ "$verbose" != 0 ];
        # then
        #     Misc_PrintF -v 2 -t 'e' -f $'Too few (minimum %s) matches found: %s\n' -- \
        #         "$matchCountMin" \
        #         "${#matches[@]}";
        # fi

        return 2;
    fi

    # If too many matches
    if [ "$matchCountMax" != '' ] && (( ${#matches[@]} > matchCountMax ));
    then
        # if [ "$verbose" != 0 ];
        # then
        #     Misc_PrintF -v 2 -t 'e' -f $'Too many (maximum %s) matches found: %s\n' -- \
        #         "$matchCountMax" \
        #         "${#matches[@]}";
        # fi

        return 3;
    fi

    # If requested to output to stdout
    if [ "$streamsOutput" = 1 ];
    then
        if [ ${#matches[@]} = 1 ];
        then
            declare match="${matches[0]}"; # I:L:P:O:{match}
            declare match="${match#*\:}"; # I:L:P:O:{match} ~> L:P:O:{match}
            declare match="${match#*\:}"; # L:P:O:{match} ~> P:O:{match}
            declare match="${match#*\:}"; # P:O:{match} ~> O:{match}
            declare match="${match#*\:}"; # O:{match} ~> {match}

            printf '%s' "$match";
        else
            declare match;

            for match in "${matches[@]}";
            do
                declare match="${match#*\:}"; # I:L:P:O:{match} ~> L:P:O:{match}
                declare match="${match#*\:}"; # L:P:O:{match} ~> P:O:{match}
                declare match="${match#*\:}"; # P:O:{match} ~> O:{match}
                declare match="${match#*\:}"; # O:{match} ~> {match}

                printf $'%s\n' "$match";
            done
        fi
    fi

    # If no output reference variable is declared
    if [ "$outputVariableReferenceName" = '' ];
    then
        return 0;
    fi

    # Requested to store results in a referenced variable
    declare matchIndex;

    # Loop through every match
    for (( matchIndex = 0; matchIndex < ${#matches[@]}; matchIndex++ ));
    do
        declare matchRaw="${matches[$matchIndex]}"; # I:L:P:O:{match}
        declare matchElementIndex="${matchRaw%%\:*}"; # I:L:P:O:{match} ~> I
        declare match="${matchRaw#*\:}"; # I:L:P:O:{match} ~> L:P:O:{match}
        declare matchLine="${match%%\:*}"; # L:P:O:{match} ~> L
        declare match="${match#*\:}"; # L:P:O:{match} ~> P:O:{match}
        declare matchPosition="${match%%\:*}"; # P:O:{match} ~> P
        declare match="${match#*\:}"; # P:O:{match} ~> O:{match}
        declare matchOffset="${match%%\:*}"; # O:{match} ~> O
        declare match="${match#*\:}"; # O:{match} ~> {match}

        # Add the match data to the result arrays
        Misc_Regex_outputVariableReference+=( "$match" );
        Misc_Regex_outputVariableReferenceIndexes+=( "$matchElementIndex" );
        Misc_Regex_outputVariableReferenceLines+=( "$matchLine" );
        Misc_Regex_outputVariableReferencePositions+=( "$matchPosition" );
        Misc_Regex_outputVariableReferenceOffsets+=( "$matchOffset" );
    done

    return 0;
}

# ----------------------------------------------------------------
# ----------------------------------------------------------------
# ----------------------------------------------------------------
# DEPRECATED
# ----------------------------------------------------------------
# ----------------------------------------------------------------
# ----------------------------------------------------------------

Misc_PrintRepeat()
{
    declare repeatCount=1;

    if [[ "$1" =~ ^(0|[1-9][0-9]*)$ ]];
    then
        declare repeatCount="$1";
        shift;
    fi

    if [[ "$1" == '--' ]];
    then
        shift;
    fi

    declare repeatStep;

    for (( repeatStep = 0; repeatStep < "$repeatCount"; repeatStep++ ));
    do
        printf -- '%s' "$@";
    done;
}

# Join an array of values to a string
Misc_ArrayJoin()
{
    if [ "$1" == '-e' ];
    then
        declare escape=1;
        shift;
    else
        declare escape=0;
    fi

    if [ "$1" == '--' ];
    then
        declare prefix="'";
        declare postfix="'";
        declare separator=", ";
        shift;
    else
        declare prefix="$1";
        declare postfix="$2";
        declare separator="$3";
        shift 3;
    fi

    if [ $# = 0 ];
    then
        return 1;
    fi

    declare index;

    # If escape chars
    if [ "$escape" = 1 ];
    then
        declare pattern='%s%q%s';
    else
        declare pattern='%s%s%s';
    fi

    for (( index = 1; index <= $#; index++ ));
    do
        IFS=$' \t\n' printf -- "$pattern" "$prefix" "${!index}" "$postfix"

        if (( "$index" < $# ));
        then
            printf -- '%s' "$separator";
        fi
    done
}

# Test if a regex Perl Compatible Regular Expressions (PCRE) pattern is valid (<3 Perl)
Misc_RegexVerify()
{
    IFS=$' \t\n' printf -- '%s' "$@" | perl -ne 'eval { qr/$_/ }; die if $@;' &> '/dev/null';
}

Misc_RegexMatchSimple()
{
    ###########
    # Options #
    ###########

    declare patternSearch="$1";
    shift;
    declare filepaths=( "$@" );

    ########
    # Main #
    ########

    if ! Misc_RegexVerify "$patternSearch";
    then
        printf -- $'Invalid search pattern was declared for regex replace: \'%s\'\n' "$patternSearch";

        return 2;
    fi

    # Todo: Find a non-conflict option. A subshell?
    if [[ "${patternSearchExported+s}" != '' ]];
    then
        printf -- $'Regex search conflict\n';

        return 2;
    fi

    export patternSearchExported="$patternSearch";
    declare matches;
    declare matches=0;

    for filepath in "${filepaths[@]}";
    do
        if [ ! -f "$filepath" ];
        then
            printf -- $'No such file to regex replace: "%s"\n' "$filepath";
        fi

        if IFS=$' \t\n' perl -nle 'm/$ENV{patternSearchExported}/g && print "$1" and $MATCH++; END{exit 1 unless $MATCH > 0}' -- "$filepath";
        then
            declare matches=1;
        # else
        #     printf -- $'No regex match for \'%s\' to replace in \'%s\'\n' "$patternSearch" "$filepath";
        fi
    done

    unset patternSearchExported;

    [[ "$matches" != 0 ]];
}
