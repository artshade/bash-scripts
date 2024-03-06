#! /usr/bin/env bash

# Copyright 2016-2024 Artfaith

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

# Description
# ----------------------------------------------------------------

# Version: 2023-10-22

# Help
# ----------------------------------------------------------------

# Required options (i.e. must be set; both `arguments` and `flags`)
# --------------------------------

# Required options are noted via `!` char in option pattern variants.
# For example: '!?-a:--optA;!-b;-c' - parameter '-a' (or '--optA') and flag '-b' are required.

# Validation and replacement rules
# --------------------------------
#
# Option property argument rules (option pattern prefix '/' to validate, '//' - replace):
#
# - 1. Validate (only set options get validated):
#   - 1.1. '/3?/[a-z]+' - Option at index 3: may be empty, non-empty must match '[a-z]';
#   - 1.2.  '/2/[a-z]+' - Option at index 2: must not be empty, must match '[a-z]';
#   - 1.3.        '/1?' - Option at index 1: may be empty (may be used to omit the default validation);
#   - 1.4.         '/0' - Option at index 0: must not be empty (may be used to omit the default validation);
#   - 1.5.  '/?/[a-z]+' - All options without rules: may be empty, non-empty must match '[a-z]';
#   - 1.6.    '/[a-z]+' - All options without rules: must not be empty, must match '[a-z]';
#   - 1.7.         '/?' - All options without rules: may be empty;
#   - 1.8.          '/' - All options without rules: must not be empty;
#
# - 2. Replace:
#   - 2.1. '//3?/[a-z]+' 'value' - Option at index 3: matches + unset;
#   - 2.2.  '//2/[a-z]+' 'value' - Option at index 2: matches;
#   - 2.3.        '//1?' 'value' - Option at index 1: empty + unset;
#   - 2.4.         '//0' 'value' - Option at index 0: empty;
#   - 2.5.  '//?/[a-z]+' 'value' - All options without rules: matches + unset;
#   - 2.6.   '///[a-z]+' 'value' - All options without rules: matches;
#   - 2.7.         '//?' 'value' - All options without rules: empty + unset;
#   - 2.8.          '//' 'value' - All options without rules: empty;

# Todo
# ----------------------------------------------------------------

# @todo In case Option #1 is enabled, the reference "declaration" array should help indicating whether default value is set or not
# @todo Add "help" message (e.g. '--help')
# @todo Add switch: option order respect factor output
# @todo Add option debug switch (e.g. for more verbose fail/error messages, parsing steps)
# @todo Add option: prefer first or last value/argument in option arguments (e.g. skip disabled, but do count)
# @todo Add a global variable with the option at index of the parse fail (e.g. '_Options_FO')
# @todo Check behavior when 'Options' receives multiple option patters: '1101' '1'...
# @todo Reconsider mode when rule may not work as expected: '/1/.*' vs '/1?/.+'
# @todo Consider two default validation/replace expressions to be allowed (e.g. one for set values, and another - for unset).
# @todo Rename option property "value" to "argument"
# @todo Add/Replace current options of "Options" library to something more sensible like `-v` to add a validation rule, `-r` for a replace rule, and
#   `--` having mandatory highlighting the start of actual options to parse. The reference variable could be the first, options patterns the second,
#   anything else is next, and the last - `--` to state the end of "Options" options and start of anything to process/parse.
#   For example: `_options args '!?-a;?-b;?-c:--cc;-d' -s '1101' -v '0/[0-9]' -v '1' -r '2/[a-b]+' 'C' -- "$@" || return $?;`.
# @todo Probably add "-%" option for "Options" to use for comments in multi-line calls (just in case?).
#   For example, `_options args '-a;-b' -0 '"-a" - Append changes' -- "$@"`.
# @todo Probably allow declaring option patters in separate options like `_options args -o '!?-a' 'Description' -o '?-b' -o '-c' -- "$@"`.
# @todo Reconsider an addition to "{reference}C" or option provided/set count. Is it possible to set a named variable reference to an associative array?
#   If so, would it be also convenient to return an array which would have set for provided/set actual options, and unset for those which were not found?
# @todo Fix an issue with no plain values found with no pattern provided (e.g. `declare args; _options args '/' "$@" || return $?; echo "${args[@]}"; unset args;`).
# @todo Add rules to specify conflicting options (e.g. option '-a' cannot bet set with option '-b' set, too).
# @todo Add rules to specify overloading/overwriting options of the same type (e.g. if parameters '?-a' and '?-b' are both set, `-b` overwrites argument of '-a').
# @todo Add option to control whether parameter value stores the last or first provided argument.
# @todo Remove debugging from the library and provide a separate special version with it included.
# @todo Add option to support multiple finite arguments for single parameter option (e.g. `-a b c -d` ~ `a=(b c) d=1`).

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Initials
# ----------------------------------------------------------------

declare _Options_sourceFilepath; _Options_sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}"; )"; readonly _Options_sourceFilepath;
declare _Options_sourceDirpath; _Options_sourceDirpath="$( dirname -- "$_Options_sourceFilepath"; )"; readonly _Options_sourceDirpath;

[[ ! -f "$_Options_sourceFilepath" || ! -d "$_Options_sourceDirpath" ]] && exit 99;

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

    _verifyChecksum "$_Options_sourceFilepath" "$_Options_sourceDirpath";
) || {
    printf -- $'Failed to self-verify file integrity: \'%s\'.\n' "$_Options_sourceFilepath" >&2;

    exit 98;
}

# Libraries
# ----------------------------------------------------------------

declare SHELL_LIB_OPTIONS; SHELL_LIB_OPTIONS="$( sha256sum -b -- "$_Options_sourceFilepath" | cut -d ' ' -f 1; ):${_Options_sourceFilepath}";

# shellcheck disable=SC2034
readonly SHELL_LIB_OPTIONS;

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Constants Private
# ----------------------------------------------------------------
# Arrays
# --------------------------------

# @todo Add previews/examples?
# Default switch values
declare -r __switchesDefault=(
    1 #  1 - Show error message on option parse fail (default: 1)
    0 #  2 - Set global option count variable (${reference}C) (default: 0)
    0 #  3 - Set global option total count variable (${reference}T) (default: 0)
    0 #  4 - Arguments with prefix '-' (default: 0)
    0 #  5 - Options without prefix '-' (default: 0)
    1 #  6 - Combined short options with a leading '=' character and joined argument (default: 1)
    1 #  7 - Options combined with values (default: 1)
    1 #  8 - Combined short options (default: 1)
    1 #  9 - Empty arguments (default: 1)
    1 # 10 - Empty values (default: 1) # @todo Unnecessary switch due to switch "Empty arguments"?
    1 # 11 - Arguments prefixed with '-' character (default: 1) # @todo Unnecessary switch (due to switch 3)?
    1 # 12 - Arguments right after '=' character prefixed with '-' character (default: 1)
    1 # 13 - Option argument RegEx rule count must be less or equal option pattern count (default: 1) # @todo Unnecessary switch?
    0 # 14 - Skip to the next pattern after the first argument occurrence (default: 0)
    0 # 15 - Skip to the next pattern after the first flag occurrence (default: 0)
    1 # 16 - Prefix '-' character while splitting short options (default: 1)
    1 # 17 - Show error message more verbose details (default: 1)
    1 # 18 - Allow parameters to have multiple arguments (default: 1)
);

declare -r _Options_errorMessages=(
    $'Pattern duplicate' #1
    $'Encountered value prefixed with \'-\' character' #2
    $'Encountered empty argument' #3
    $'Unknown option' #4
    $'Encountered pattern not prefixed with \'-\'' #5
    $'Empty pattern' #6
    $'Encountered value for flag' #7
    $'Argument not found' #8
    $'Encountered value prefixed with \'-\' character after \'=\' character' #9
    $'Too many switches' #10
    $'Encountered option combined with its possible value' #11
    $'Encountered empty value for parameter after \'=\' character' #12
    $'Encountered \'--\' pattern' #13
    $'Too few function arguments' #14
    $'Required option not found' #15
    $'Invalid validation expression' # 16
    $'Validation expression duplicate' # 17
    $'Validation rule count overflow' # 18
    $'Invalid argument' #19
    $'Empty pattern variant' #20
    $'Encountered \'-\' option' #21
    $'Output variable reference interference' #22
    $'Replacement rule count overflow' #23
    $'Replacement rule index overflow' #24
    $'Replacement expression duplicate' #25
    $'Invalid replacement expression' #26
    $'Invalid rule format' #27
    $'Invalid replacement for flag' #28
    $'Invalid replacement function' #29
);

declare -rA _OPTIONS_LIB_DEBUGSteps=(
    ['start']=1 # Print "start"
    ['call_stack']=1 # Print "call stack"
    ['processed_initials']=1 # Print "processed initials"
    ['result']=1 # Print "result"
    ['end']=1 # Print "end"
);

# Primitives
# --------------------------------

# Default value for unset flag
declare -r _Options_flagValueDefault=0;

# Default value for unset parameter argument
declare -r _Options_argumentValueDefault=();

# Custom first char before each option as first option after split(when multiple split from options is allowed)
declare -r _Options_optionShortCombinedPrefix='-';

# Functions
# ----------------------------------------------------------------

_options()
{
    # Variables
    # ----------------------------------------------------------------
    # Primitives
    # --------------------------------

    # Debug
    declare _OPTIONS_LIB_DEBUG="${_OPTIONS_LIB_DEBUG-0}";
    declare _OPTIONS_LIB_DEBUG_STEP=0;

    declare _Options_RC=-1; # Final result code
    declare _Options_FI=-1; # Index of the last failed option parse if any
    declare _Options_FM=''; # Fail error message of the last parse if any (based on '_Options_RC')

    # Variables Private
    # ----------------------------------------------------------------
    # Arrays
    # --------------------------------

    # Switches
    declare _Options_S=( "${__switchesDefault[@]}" );

    # Items
    declare _Options_A=(); # All initial options passed to the main function of library "Options".
    declare _Options_U=(); # Unparsed patterns.
    declare _Options_O=(); # Unprocessed options.
    declare _Options_UF=(); # Parsed unsplit flag options.
    declare _Options_F=(); # Parsed split flag options (e.g. '-a -b', '-ab').
    declare _Options_UP=(); # Parsed unsplit parameter options.
    declare _Options_P=(); # Parsed split parameter options (e.g. '-a 1', '--optA 1', '--optA "1 2"', --optA='1 2').
    declare _Options_T=(); # Option types.

    declare _Options_flagIndexes=();
    declare _Options_parameterIndexes=();

    # For value validations
    declare -A _Options_validateModes=();
    declare -A _Options_validateExpressions=();

    # For value replacements
    declare -A _Options_replaceModes=();
    declare -A _Options_replaceExpressions=();
    declare -A _Options_replacements=();

    # Primitives
    # --------------------------------

    # For value validations
    declare _Options_validateModeDefault='';
    declare _Options_validateExpressionDefault='';

    # For value replacements
    declare _Options_replaceDefaultMode='';
    declare _Options_replaceExpressionDefault='';
    declare _Options_replacementDefault='';

    # Functions (Private)
    # ----------------------------------------------------------------

    # shellcheck disable=SC2317
    _isVarReference()
    {
        declare varAttrs; varAttrs="$( declare -p "$1" 2> '/dev/null' || :; )";
        declare refVarRegex='^declare -n [^=]+=\"([^\"]+)\"$';

        [[ "$varAttrs" =~ $refVarRegex ]];
    }

    # Get variable type name if available.
    # Recursively iterates over variable references until found any actual or unset.
    # @see https://stackoverflow.com/a/42877229/5113030
    # shellcheck disable=SC2317
    _varType() {
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

    # shellcheck disable=SC2317
    _isVarOfType()
    {
        if [[ "$#" != 2 ]];
        then
            return 2;
        fi

        declare typeName="$1";
        shift;
        declare varType; varType="$( _varType "$1" || :; )";
        shift;

        if [[ "$varType" == "$typeName" ]];
        then
            return 0;
        fi

        return 1;
    }

    # Check if the array contains any of the declared elements and return the first found position
    _findArrayElement()
    {
        declare valuePositionPrint=1;

        # If requested to not print the value's position in the array
        if [[ "$1" == '-' ]];
        then
            declare valuePositionPrint=0;
            shift;
        fi

        # Delimiter of elements to find
        declare delimiter='';
        declare elementsToFind=( "$1" ); # Value or delimiter

        # If the delimiter is declared, meaning multiple values to find may be also declared
        if [[ "${1:0:1}" == '!' ]];
        then
            # Remove the first '!' from the delimiter
            declare delimiter="${1:1}";
            shift;

            # If the delimiter is empty
            if [[ "$delimiter" == '' ]];
            then
                return 2;
            fi

            # Fill the array with values separated by the delimiter
            IFS="$delimiter" read -ra elementsToFind <<< "$1";
        elif [[ "${1:0:1}" == '%' ]]; # If the char '!' may the be first character in the value
        then
            elementsToFind=( "${1:1}" );
        fi

        shift;
        declare elementToFindPosition="0"; # Value's position in values' array(if delimiter declared)
        declare elementToFind;

        for elementToFind in "${elementsToFind[@]}"; # Loop each value(if delimiter declared) or only one value
        do
            declare elementPosition="0"; # Position of value in array
            declare element; # For array of elements of array

            for element in "$@";
            do
                if [[ "$element" == "$elementToFind" ]]; # If value is equal to array's element
                then
                    if [[ "$valuePositionPrint" == 1 ]]; # If allowed, print value's position in array
                    then
                        # If any delimiter is found
                        if [[ "$delimiter" != '' ]];
                        then
                            # Print/Output value's position in the array.

                            printf '%s' "$elementToFindPosition,";
                        fi

                        printf $'%s\n' "$elementPosition";
                    fi

                    return 0;
                fi

                declare elementPosition="$(( elementPosition + 1 ))"; # Increment checking value's position
            done

            declare elementToFindPosition="$(( elementToFindPosition + 1 ))"; # Increment value's position in values' array
        done

        return 1;
    }

    _printArray()
    {
        declare assocArrayReferenceName;
        declare isAssoc=0;
        declare delimiter=', ';
        declare format;
        declare printKeys=0;
        declare printExtended=0;
        declare paddingChar='';
        declare modifierFunctionName='';
        declare prefix=$'\'';
        declare postfix=$'\'';

        # Use `getopts`?
        while (( $# > 0 ));
        do
            case "$1" in
                '-a')
                    # If associative array is already set
                    if [[ "${assocArrayReferenceName+s}" != '' ]];
                    then
                        return 1;
                    fi

                    declare isAssoc=1;
                    shift;

                    continue;
                ;;

                '-d')
                    declare delimiter="$2";
                    shift 2;

                    continue;
                ;;

                '-f')
                    declare format="$2";
                    shift 2;

                    continue;
                ;;

                '-k')
                    declare printKeys=1;
                    shift;

                    continue;
                ;;

                '-e')
                    declare printExtended=1;
                    shift;

                    continue;
                ;;

                '-p')
                    declare paddingChar="${2:0:1}";
                    shift 2;

                    continue;
                ;;

                '-m')
                    declare modifierFunctionName="$2";
                    shift 2;

                    if ! declare -F -- "$modifierFunctionName" &> '/dev/null';
                    then
                        return 2;
                    fi

                    continue;
                ;;

                # If skip further processing
                '--')
                    if (( isAssoc > 0 ));
                    then
                        shift;
                        declare assocArrayReferenceName="$1";
                    fi

                    shift;

                    break;
                ;;

                '-'*)
                    # If possible option is unknown
                    return 2;
                ;;
            esac

            if (( isAssoc > 0 ));
            then
                declare assocArrayReferenceName="$1";
                shift;
                declare isAssoc=0;
            fi

            shift;
        done

        # Main
        # --------------------------------

        # If associative array
        if [[ "${assocArrayReferenceName+s}" != '' ]];
        then
            declare -n arrayReference="$assocArrayReferenceName";
            declare itemCount="${#arrayReference[@]}";
            declare maxKeyLength=0;

            if [[ "$paddingChar" != '' ]] && (( printExtended > 0 ));
            then
                declare itemKey;

                for itemKey in "${!arrayReference[@]}";
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
                if (( printKeys > 0 ));
                then
                    declare format="[%s%s]%s%s";
                else
                    declare format='%s';
                fi
            fi

            if (( printExtended > 0 ));
            then
                printf -- '[\n';
            fi

            declare itemIndex=0;
            declare itemKey;

            # keys=()
            for itemKey in "${!arrayReference[@]}";
            do
                declare item="${arrayReference[$itemKey]}";

                if [[ "$modifierFunctionName" != '' ]];
                then
                    item="$( "$modifierFunctionName" "$item"; printf '.'; )";
                    declare item="${item:0:-1}";
                fi

                if (( printExtended > 0 ));
                then
                    printf -- '    ';
                fi

                declare padding='';

                if (( maxKeyLength > 0 ));
                then
                    declare padding; padding="$(
                        declare i;
                        for (( i = 0; i < (maxKeyLength - ${#itemKey}); i++ )); do printf '%s' "$paddingChar"; done;
                    )";
                fi

                if (( printKeys > 0 ));
                then
                    # shellcheck disable=SC2059
                    printf -- "$format" "$padding" "'${itemKey}'" "$( (( printExtended == 0 )) && printf '=' || printf ' '; )" \
                        "${prefix}${item}${postfix}";
                else
                    # shellcheck disable=SC2059
                    printf -- "$format" "${prefix}${item}${postfix}";
                fi

                if (( printExtended > 0 ));
                then
                    printf -- '\n';
                else
                    if (( itemIndex + 1 < itemCount ));
                    then
                        printf '%s' "$delimiter";
                    fi
                fi

                declare itemIndex="$(( itemIndex + 1 ))";
            done

            if (( printExtended > 0 ));
            then
                printf -- ']';
            fi

            return 0;
        fi

        # Indexed array

        if (( $# == 0 ));
        then
            return 0;
        fi

        declare items=( "$@" );
        declare itemCount="$#";
        shift $#;

        if [[ "${format+s}" != 's' ]];
        then
            if (( printKeys > 0 ));
            then
                declare format; format="[%s%s]%s%s";
            else
                declare format='%s';
            fi
        fi

        if (( printExtended > 0 ));
        then
            printf -- '[\n';
        fi

        for (( itemIndex = 0; itemIndex < itemCount; itemIndex++ ));
        do
            declare item="${items[itemIndex]}";

            if [[ "$modifierFunctionName" != '' ]];
            then
                item="$( "$modifierFunctionName" "$item"; printf '.'; )";
                declare item="${item:0:-1}";
            fi

            if (( printExtended > 0 ));
            then
                printf -- '    ';
            fi

            declare padding='';

            if [[ "$paddingChar" != '' ]];
            then
                declare padding; padding="$(
                    declare i;
                    for (( i = 0; i < (${#itemCount} - ${#itemIndex}); i++ )); do printf '%s' "$paddingChar"; done;
                )";
            fi

            if (( printKeys > 0 ));
            then
                # shellcheck disable=SC2059
                printf -- "$format" "$padding" "$itemIndex" "$( (( printExtended == 0 )) && printf '=' || printf ' '; )" \
                    "${prefix}${item}${postfix}";
            else
                # shellcheck disable=SC2059
                printf -- "$format" "${prefix}${item}${postfix}";
            fi

            if (( printExtended > 0 ));
            then
                printf -- '\n';
            else
                if (( itemIndex + 1 < itemCount ));
                then
                    printf '%s' "$delimiter";
                fi
            fi
        done

        if (( printExtended > 0 ));
        then
            printf -- ']';
        fi

        return 0;
    }

    # shellcheck disable=SC2317
    _decToBin()
    {
        if [[ $# != 1 ]];
        then
            return 2;
        fi

        perl -e $'printf(\'%b\', $ARGV[0]);' -- "$1";
    }

    _isRegexValid()
    {
        declare value;

        for value in "$@";
        do
            if ! IFS=$' \t\n' printf '%s' "$value" | perl -ne 'eval { qr/$_/ }; die if $@;' &>> '/dev/null';
            then
                return 1;
            fi
        done

        return 0;
    }

    _regexTest()
    {
        if (( "$#" < 2 ));
        then
            return 3;
        fi

        declare regex="$1";
        shift;
        declare itemCount="$#";

        # --------------------------------

        declare matchCount=0;

        for value in "$@";
        do
            # shellcheck disable=SC2036 disable=SC2034
            if
                IFS=$' \t\n' \
                INPUT="$value" \
                REGEX="$regex" \
                    perl -e $'$MATCH_COUNT=0; ($ENV{INPUT} =~ /$ENV{REGEX}/) && $MATCH_COUNT++; print "${MATCH_COUNT}\n"; END{exit 1 unless $MATCH_COUNT > 0}';
            then
                declare matchCount="$(( matchCount + 1 ))";
            fi
        done

        if (( itemCount == matchCount ));
        then
            return 0;
        fi

        if (( matchCount > 0 ));
        then
            return 2;
        fi

        return 1;
    }

    _regexReplace()
    {
        if (( $# < 3 ));
        then
            return 2;
        elif [[ $# == 3 ]];
        then
            return 1;
        fi

        declare __ref="$1";
        declare __searchRegex="$2";
        declare __replaceRegex="$3";
        shift 3;
        declare __values=( "$@" );
        shift $# || :;

        # --------------------------------

        if
            ! _isRegexValid "$__searchRegex" ||
            ! _isRegexValid "$__replaceRegex";
        then
            return 2;
        fi

        declare -n ref="$__ref";

        readarray -t ref < <(
            declare value;

            for value in "${__values[@]}";
            do
                IFS=$' \t\n' \
                VALUE="$value" \
                SEARCH_REGEX="$__searchRegex" \
                REPLACE_REGEX="$__replaceRegex" \
                    perl -le $'
                        use strict;
                        use warnings;
                        use utf8;

                        # --------------------------------

                        # From package "Data::Munge" (v0.097; line 122)
                        sub submatches {
                            no strict \'refs\';
                            map $$_, 1 .. $#+
                        }

                        # (modified) From package "Data::Munge" (v0.097; line 96)
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

                            my $matchCount;

                            if ($g) {
                                $matchCount = $str =~ s{$re}{ $f->(substr($str, $-[0], $+[0] - $-[0]), submatches(), $-[0], $str) }eg;
                            } else {
                                $matchCount = $str =~ s{$re}{ $f->(substr($str, $-[0], $+[0] - $-[0]), submatches(), $-[0], $str) }e;
                            }

                            ($str, $matchCount)
                        }

                        # --------------------------------

                        my $matchCount = 0;
                        my $value = "$ENV{VALUE}";

                        ($value, $matchCount) = replace($value, "$ENV{SEARCH_REGEX}", "$ENV{REPLACE_REGEX}",, 1);

                        if ($matchCount == 0) {
                            exit 1;
                        }

                        print "$value";
                ' \
                    || return $?;
            done
        );

        [[ ${#ref[@]} == "${#__values[@]}" ]];
    }

    # Validate option value using Perl regex.
    _validateValue()
    {
        # If reset validations
        if [[ "$1" == '-r' ]];
        then
            _Options_validateModes=();
            _Options_validateExpressions=();
            _Options_validateModeDefault='';
            _Options_validateExpressionDefault='';
            _Options_FI=-1;

            return 0;
        fi

        # If add a validation
        if [[ "$1" == '-a' ]];
        then
            shift;
            declare validateFull="$1";
            declare validateIndex='';
            declare validateExpression='';

            # If validation is not complex (no regex)
            if [[ "$validateFull" =~ ^/(0|[1-9][0-9]*)?\??/?$ ]];
            then
                # For example:
                # -  '/',  '/1',  '/?',  '/1?'
                # - '//', '/1/', '/?/', '/1?/'

                declare validateFull="${1:1}";

                # Index:
                # - Default: '?', '[a-z]+', '?', '';
                # -   Index: '3?', '3', '3?', '3'.
                declare validateIndex="${validateFull%%\/*}";
            elif [[ "$validateFull" =~ ^/(0|[1-9][0-9]*)?\??/ ]];
            then
                # For example:
                # -      '///',      '/1//',      '/?//,      '/1?//' - Regex '/';
                # -  '//[0-9]',  '/1/[0-9]',  '/?/[0-9],  '/1?/[0-9]' - Regex '[0-9]';
                # - '//[0-9]/', '/1/[0-9]/', '/?/[0-9]/, '/1?/[0-9]/' - Regex '[0-9]/'.

                # If index is set
                if [[ "$validateFull" =~ ^/(0|[1-9][0-9]*)?\??/.+ ]];
                then
                    # e.g. '//[0-9]/' -> '/[0-9]/'
                    declare validateFull="${1:1}";
                fi

                # Index:
                # - Default: '?', '[a-z]+', '?', '';
                # -   Index: '3?', '3', '3?', '3'.
                declare validateIndex="${validateFull%%\/*}";

                # Expression:
                # - Default: '[a-z]+', '', '?', '';
                # -   Index: '[a-z]+', '[a-z]+', '3?', '3'.
                declare validateExpression="${validateFull#*\/}";
            else
                # Invalid validation format
                return 5;
            fi

            # return 0;

            # Ignore unset option values
            declare validateMode=0;

            # If the last char in index is '?'
            if [[ "${validateIndex: -1}" == '?' ]];
            then
                # Validate unset
                declare validateMode=1;

                # Remove the last char '?'
                declare validateIndex="${validateIndex:0:-1}";
            fi

            shift 2;

            # If invalid regex
            if [[ "$validateExpression" != '' ]] && ! _isRegexValid "$validateExpression";
            then
                return 2; # Invalid validation
            fi

            # If it's a default validation
            if [[ "$validateIndex" == '' ]];
            then
                # Default validation (for all that don't have their own validation set).

                # If the default validation is already set
                if [[ "$_Options_validateModeDefault" != '' ]];
                then
                    return 3; # Already exists (default)
                fi

                # Set default validation

                _Options_validateModeDefault="$validateMode";
                _Options_validateExpressionDefault="$validateExpression"; # Either empty or regex

                return 0;
            fi

            # If such option validate expression exists already
            if [[ "${_Options_validateModes["$validateIndex"]+s}" != '' ]];
            then
                return 3; # Already exists (indexed)
            fi

            # Set custom validate expression

            _Options_validateModes["$validateIndex"]="$validateMode";
            _Options_validateExpressions["$validateIndex"]="$validateExpression";

            return 0;
        fi

        # Try validating a value (i.e. -v).

        shift;
        declare optionIndex="$1";
        declare optionValue;
        shift;

        if (( $# > 0 ));
        then
            declare optionValue="$1";
            shift;
        fi

        declare validateMode="$_Options_validateModeDefault";
        declare validateExpression="$_Options_validateExpressionDefault";

        # If no option validate expression is declared (no mode for such index is found - try default)
        if [[ "${_Options_validateModes[$optionIndex]+s}" != '' ]];
        then
            # Index validate expression is available

            declare validateMode="${_Options_validateModes[$optionIndex]}";
            declare validateExpression="${_Options_validateExpressions[$optionIndex]}";
        fi

        # If validation mode is empty or unset
        if [[ "${validateMode:-s}" == '' ]];
        then
            # Valid (no validation mode is available)

            return 0;
        fi

        # If argument or flag is unset
        if [[ "${optionValue+s}" == '' ]];
        then
            # Valid (argument - not set)

            return 0;
        fi

        # If argument is empty
        if [[ "${optionValue:+s}" == '' ]];
        then
            # If must not be empty or empty values are prohibited
            if [[ "$validateMode" == '0' ]] || ! _switch 10;
            then
                # Invalid (empty - prohibited)

                return 1;
            fi

            # Valid (empty - allowed)

            return 0;
        fi

        # Argument is not empty

        # If expression is not available
        if [[ "$validateExpression" == '' ]];
        then
            # Valid (no expression - ignored)

            return 0;
        fi

        if ! _regexTest "$validateExpression" "$optionValue" &> '/dev/null';
        then
            return 1; # Invalid (does not pass expression)
        fi

        # Valid (passes expression)

        return 0;
    }

    # Replace option value conditionally.
    _replaceValue()
    {
        # If reset replacements
        if [[ "$1" == '-r' ]];
        then
            _Options_replaceModes=();
            _Options_replaceExpressions=();
            _Options_replacements=();
            _Options_replaceDefaultMode='';
            _Options_replaceExpressionDefault='';
            _Options_replacementDefault='';
            _Options_FI=-1;

            return 0;
        fi

        # If add a replacement
        if [[ "$1" == '-a' ]];
        then
            shift;
            declare rule="$1";
            declare replacement="$2";
            shift 2;

            declare replaceIndex='';
            declare expression='';

            # Ignore unset option values
            declare replaceMode="$(( 2#000 ))";

            # If invalid replacement rule
            if [[ ! "$rule" =~ ^/(/|!)(0|[1-9][0-9]*)?\?? ]];
            then
                return 5;
            fi

            # Remove first char '/'
            declare rule="${rule:1}";

            # If mode "function" (rule starts from '!', otherwise, starts with '/' - mode "simple" or "regex")
            if [[ "$rule" =~ ^! ]];
            then
                # If function is not available
                if ! declare -F -- "$replacement" &> '/dev/null';
                then
                    # Invalid replacement
                    return 6;
                fi

                # Set mode "function"
                declare replaceMode="$(( replaceMode | 2#100 ))";
            fi

            # Remove first '/' or '!'
            declare rule="${rule:1}";

            # Index:
            # - Default: '?', '[a-z]+', '?', '';
            # -   Index: '3?', '3', '3?', '3'.
            declare replaceIndex="${rule%%\/*}";

            # If mode "unset"
            if [[ "$replaceIndex" =~ \?$ ]];
            then
                # Set mode "unset"
                declare replaceMode="$(( replaceMode | 2#001 ))";

                # Remove the last char '?'
                declare replaceIndex="${replaceIndex:0:-1}";
            fi

            # If expression exists
            if [[ "$rule" =~ ^(0|[1-9][0-9]*)?\??/ ]];
            then
                declare expression="${rule#*\/}";

                if ! _isRegexValid "$expression";
                then
                    return 2;
                fi

                # If mode "advanced"
                if [[ "$expression" =~ ^\/ ]];
                then
                    # Set mode "advanced"
                    declare replaceMode="$(( replaceMode | 2#010 ))";

                    # Remove the first char '/'
                    declare expression="${expression:1}";
                fi
            fi

            # If it's a default replacement
            if [[ "$replaceIndex" == '' ]];
            then
                # Default replacement (for all that don't have their own replacement set).

                # If the default replacement is already set
                if [[ "$_Options_replaceDefaultMode" != '' ]];
                then
                    return 3; # Already exists (default)
                fi

                # Set default replacement

                _Options_replaceDefaultMode="$replaceMode";
                _Options_replaceExpressionDefault="$expression"; # Either empty or regex
                _Options_replacementDefault="$replacement"; # Any string

                return 0;
            fi

            # If such option replace expression exists already
            if [[ "${_Options_replaceModes["$replaceIndex"]+s}" != '' ]];
            then
                return 3; # Already exists (indexed)
            fi

            # Set custom replace expression

            _Options_replaceModes["$replaceIndex"]="$replaceMode";
            _Options_replaceExpressions["$replaceIndex"]="$expression";
            _Options_replacements["$replaceIndex"]="$replacement";

            return 0;
        fi

        # Try applying a replacement (i.e. -v).

        shift;
        declare outputVariableReferenceName="$1";
        declare optionIndex="$2";
        declare optionValue;
        shift 2;

        if (( $# > 0 ));
        then
            declare optionValue="$1";
            shift;
        fi

        # --------------------------------

        # In case an output variable has the same name as the reference (may interfere)
        if
            [[
                "$outputVariableReferenceName" == 'Options_OutputVariableReference' ||
                "$outputVariableReferenceName" == 'Options_OutputVariableReferenceTemp'
            ]];
        then
            _setResultCode 22;

            return "$_Options_RC";
        fi

        declare -n Options_OutputVariableReference="$outputVariableReferenceName";
        Options_OutputVariableReference='';

        # --------------------------------

        declare replaceMode="$_Options_replaceDefaultMode";
        declare replaceExpression="$_Options_replaceExpressionDefault";
        declare replacement="$_Options_replacementDefault";

        # If option replacement expression is available
        if [[ "${_Options_replaceModes[$optionIndex]+s}" != '' ]];
        then
            declare replaceMode="${_Options_replaceModes[$optionIndex]}";
            declare replaceExpression="${_Options_replaceExpressions[$optionIndex]}";
            declare replacement="${_Options_replacements[$optionIndex]}";
        fi

        # If no replacement available
        if [[ "${replaceMode:+s}" == '' ]];
        then
            # Do not replace

            return 1;
        fi

        # Replacement is available

        # If value is not set
        if [[ "${optionValue+s}" == '' ]];
        then
            # If only set
            if (( (replaceMode & 2#001) == 0 ));
            then
                return 1; # Do not replace
            fi

            # If mode "function"
            if (( (replaceMode & 2#100) != 0 ));
            then
                declare replacementValue;

                # If function returns success
                if replacementValue="$( "$replacement" "$optionIndex"; )";
                then
                    Options_OutputVariableReference="$replacementValue";

                    # Replace with function output

                    return 0;
                fi

                # Do not replace

                return 1;
            fi

            # Replace unset

            Options_OutputVariableReference="$replacement";

            return 0;
        fi

        # Value is set

        # If expression is not available
        if [[ "$replaceExpression" == '' ]];
        then
            # If mode "function"
            if (( (replaceMode & 2#100) != 0 ));
            then
                declare replacementValue;

                # If function returns success
                if replacementValue="$( "$replacement" "$optionIndex" "$optionValue"; )";
                then
                    Options_OutputVariableReference="$replacementValue";

                    # Replace with function output

                    return 0;
                fi

                # Do not replace

                return 1;
            fi

            # If value is not empty
            if [[ "${optionValue:+s}" != '' ]];
            then
                return 1; # Do not replace (not empty)
            fi

            # Replace (empty)

            Options_OutputVariableReference="$replacement";
            # Options_OutputVariableReference="$_Options_argumentValueDefault";

            return 0;
        fi

        # Expression is available

        # If mode "function"
        if (( (replaceMode & 2#100) != 0 ));
        then
            if ! _regexTest "$replaceExpression" "$optionValue" &> '/dev/null';
            then
                return 1; # Do not replace (does not match)
            fi

            declare replacementValue;

            # If function returns success
            if replacementValue="$( "$replacement" "$optionIndex" "$optionValue"; )";
            then
                Options_OutputVariableReference="$replacementValue";

                # Replace with function output

                return 0;
            fi

            # Do not replace

            return 1;
        fi

        # If mode "advanced"
        if (( (replaceMode & 2#10) != 0 ));
        then
            # Regex replace

            declare replacementTemp;

            if ! _regexReplace replacementTemp "$replaceExpression" "$replacement" "$optionValue" &> '/dev/null';
            then
                return 1; # Do not replace (does not match)
            fi

            # Replace (match)

            Options_OutputVariableReference="$replacementTemp";

            return 0;
        fi

        if ! _regexTest "$replaceExpression" "$optionValue" &> '/dev/null';
        then
            return 1; # Do not replace (does not match)
        fi

        # Replace (match)

        Options_OutputVariableReference="$replacement";

        return 0;
    }

    # Functions (Project)
    # ----------------------------------------------------------------

    # Get or set switches
    _switch()
    {
        # If reset
        if [[ "$1" == '-r' ]];
        then
            _Options_S=( "${__switchesDefault[@]}" );

            return 0;
        fi

        # If set the switches using a switch string (i.e. '0100101') (do we need a dec to bin conversion here just for comfy?)
        if [[ "$1" == '-s' ]];
        then
            shift;
            declare switchesString="$1";

            if [[ "$switchesString" =~ ^0x[0-9A-Fa-f]+$ ]];
            then
                declare switchesString; switchesString="$(
                    VALUE="$switchesString" \
                        perl -e '$v = "$ENV{VALUE}"; printf("%b", $v =~ /^0x[0-9A-Fa-f]+$/ ? hex($v) : $v);';
                )";
            fi

            # If the length of switch string is longer than then the number of switches supported
            if (( ${#switchesString} > ${#_Options_S[@]} ));
            then
                return 2;
            fi

            # If the length of the current switches or the switch string mismatches with expected (i.e. default)
            if [[
                ${#_Options_S[@]} != "${#__switchesDefault[@]}" ||
                ${#switchesString} != "${#__switchesDefault[@]}"
            ]];
            then
                _switch -r;
            fi

            declare i;

            # Set switches
            for (( i = 0; i < ${#switchesString}; i++ ));
            do
                if [[ "${switchesString:$i:1}" == 1 ]];
                then
                    _Options_S[i]=1;

                    continue;
                fi

                _Options_S[i]=0;
            done

            return 0;
        fi

        # Obtain switch state

        # If option index in the available option range
        if (( "$1" > 0 && "$1" <= "${#_Options_S[@]}" ));
        then
            declare i=$(( $1 - 1 ));

            if [[ $# == 2 ]];
            then
                _Options_S[i]="$2";

                return 0;
            fi

            if [[ "${_Options_S[$i]}" == 1 ]];
            then
                return 0;
            fi

            return 1;
        fi
    }

    _validateOptionValue()
    {
        declare __value="$1";
        declare __index="$2";
        shift 2;

        # --------------------------------

        # Try validating the value by index
        if ! _validateValue -v "$__index" "$__value";
        then
            # "Invalid argument"
            _setResultCode 19 "$__index";

            return "$_Options_RC";
        fi
    }

    _setOptionValue()
    {
        declare __index="$1";
        shift;

        declare __value;

        if (( $# ));
        then
            declare __value="$1";
            shift;
        fi

        # --------------------------------

        declare value;

        if [[ -v __value ]];
        then
            declare value="$__value";

            # Try replacing option value (argument or flag).

            declare Options_replacementTemp;

            # If replaced
            if _replaceValue -v Options_replacementTemp "$__index" "$value";
            then
                declare value="$Options_replacementTemp";
            fi
        else
            declare Options_replacementTemp;

            # If replaced
            if _replaceValue -v Options_replacementTemp "$__index";
            then
                declare value="$Options_replacementTemp";
            fi
        fi

        # Set reference

        declare -n optionValues="${outputVariableReferenceName}${__index}";

        # If option is parameter
        if [[ "${_Options_T[$__index]}" == 1 ]];
        then
            # Set parameter value(s)

            # If parameter argument is empty (even after replacement) and empty arguments are prohibited
            if [[ "${value-}" == '' ]] && ! _switch 9;
            then
                # Encountered empty argument
                _setResultCode 3 "$__index";

                return "$_Options_RC";
            fi

            if [[ ! -v value ]];
            then
                # Set parameter option value to an empty array
                optionValues=();

                # unset 'optionFinalValues[$__index]';
                optionFinalValues[__index]='';

                return 0;
            fi

            # If multiple option values are prohibited
            # if ... ! _switch 18;
            # then
            #     return 1;
            # fi

            # Add argument to the parameter option values
            optionValues+=( "$value" );

            # Set parameter option value to the latest
            optionFinalValues[__index]="$value";

            return 0;
        fi

        # Set flag value

        declare value="${value-0}";

        # shellcheck disable=SC2178
        optionValues="$value";

        # Set flag option value to the latest
        optionFinalValues[__index]="$value";

        return 0;
    }

    # Print error message and return its code if set
    _printErrorMessage()
    {
        declare functionName="${FUNCNAME[3]}";

        if [[ "$#" != 0 ]];
        then
            if [[ "$1" != '--' ]];
            then
                declare functionName="$1";
            fi

            shift;
        fi

        if (( _Options_RC <= 0 ));
        then
            printf $'Options parse empty error for \'%s()\'\n' "$functionName" 1>&2;

            return 1;
        fi

        printf $'Invalid options for \'%s()\' (error code %s)\n' "$functionName" "$_Options_RC" 1>&2;

        if ! _switch 17;
        then
            return "$_Options_RC";
        fi

        printf $'\nDescription: \'%s\'\n' "$_Options_FM" 1>&2;

        if (( _Options_FI >= 0 ));
        then
            printf $'Index: %s\n' "$_Options_FI" 1>&2;

            if [[ "${#_Options_O[@]}" != 0 ]];
            then
                printf $'Items:\n\n' 1>&2;

                declare padding="${#_Options_O[@]}";
                declare padding="${#padding}";
                declare optionIndex;

                for (( optionIndex = 0; optionIndex < ${#_Options_O[@]}; optionIndex++ ));
                do
                    # shellcheck disable=SC2059
                    printf -- $"  [ %${padding}s ] \'%s\'\n" "$optionIndex" "${_Options_O[$optionIndex]}" 1>&2;
                done
            fi
        fi

        printf -- '\n' 1>&2;

        return "$_Options_RC";
    }

    # Set the return code (exit status) and related global variables
    _setResultCode()
    {
        # If reset
        if [[ "$1" == '-r' ]];
        then
            _Options_RC=-1;
            _Options_FM='';

            # Reset the index of the last failed option value verification
            _Options_FI=-1;

            return 0;
        fi

        _Options_RC="$1";

        # If the return code (exit code) was declared and it's greater than 0
        if (( "$1" > 0 ));
        then
            _Options_FM="${_Options_errorMessages["$(( $1 - 1 ))"]}";

            # If the failed element index was provided
            if [[ "${2-}" != '' ]] && (( "$2" >= 0 ));
            then
                _Options_FI="$2";
            fi

            if _switch 1;
            then
                _printErrorMessage -- "${_Options_O[@]}";
            fi
        fi

        return "$_Options_RC";
    }

    # "Debug" ^^"
    _debug()
    {
        # If debugging is disabled
        if (( _OPTIONS_LIB_DEBUG == 0 ));
        then
            return 0;
        fi

        # If "Debug Start"
        if (( "$_OPTIONS_LIB_DEBUG_STEP" == 0 ));
        then
            if [[  "${_OPTIONS_LIB_DEBUGSteps['start']-}" == 1 ]];
            then
                {
                    printf -- $'\n# // [Shell Library] [Debug] [Options] Start\n# //\n# ////////////////////////////////////////////////////////////////\n\n';
                } \
                    1>&2;
            fi
        fi

        # If increment debug step
        if [[ "$1" == '-s' ]];
        then
            _OPTIONS_LIB_DEBUG_STEP="$(( _OPTIONS_LIB_DEBUG_STEP + 1 ))";

            shift;

        # If set final debug step
        elif [[ "$1" == '-f' ]];
        then
            _OPTIONS_LIB_DEBUG_STEP="${#_OPTIONS_LIB_DEBUGSteps[@]}";
            shift;

        # If set to initial debug step
        elif (( "$_OPTIONS_LIB_DEBUG_STEP" == 0 ));
        then
            _OPTIONS_LIB_DEBUG_STEP="1";
        fi

        # If unexpected behavior: Too many debug step increments.
        if (( "$_OPTIONS_LIB_DEBUG_STEP" > "${#_OPTIONS_LIB_DEBUGSteps[@]}" ));
        then
            exit 50;
        fi

        if [[ "$1" == '--' ]];
        then
            shift;
        fi

        declare debugType="$1";
        shift;

        # If print "call stack"
        if [[
            "$debugType" == 'call_stack' &&
            "${_OPTIONS_LIB_DEBUGSteps["$debugType"]-}" == 1
        ]];
        then
            {
                declare callStackDepthOffset=2;
                declare callStackItems=( "${FUNCNAME[@]}" );
                declare callStackItemCount="${#callStackItems[@]}";

                printf -- $'# // ----- (%s)\n#\n' "$debugType";
                printf -- $'# Call Stack (%s total):\n# │\n' "$callStackItemCount";

                declare indexPadding="${#callStackItemCount}";
                declare callIndex;

                for (( callIndex = 0; callIndex < callStackItemCount; callIndex++ ));
                do
                    declare connectionChar; connectionChar="$( (( (callIndex + 1) < callStackItemCount )) && printf '├' || printf '└'; )";
                    declare funcname="${callStackItems[$callIndex]}";

                    # shellcheck disable=SC2059
                    printf -- $"# %s─ [%${indexPadding}s/%s] \'%s()\'%s\n" \
                        "$connectionChar" "$((callIndex + 1))" "$callStackItemCount" "$funcname" "$( [[ "$callIndex" == "$callStackDepthOffset" ]] && printf ' <--'; )" 1>&2;
                done

                printf -- $'#\n# ----- //\n';
            } \
                1>&2;
        elif
            (( _OPTIONS_LIB_DEBUG > 2 )) &&
            [[
                # If print "processed initials"
                "$debugType" == 'processed_initials' &&
                "${_OPTIONS_LIB_DEBUGSteps["$debugType"]-}" == 1
            ]];
        then
            {
                printf -- $'\n# // ----- (%s)\n#\n' "$debugType";
                printf -- $'# Switches (%s):' "${#_Options_S[@]}"; _printArray -- "${_Options_S[@]}"; printf -- '\n';
                printf -- $'# Unparsed initials (%s):' "${#_Options_A[@]}"; _printArray -k -p ' ' -e -- "${_Options_A[@]}"; printf -- '\n';
                printf -- $'# ---\n';
                printf -- $'# Unparsed patterns (%s)' "${#_Options_U[@]}";

                if (( ${#_Options_U[@]} > 0 ));
                then
                    printf -- ': ';
                    _printArray -e -k -p ' ' -a _Options_U;
                fi

                printf -- '\n# Parsed unsplit parameters (%s)' "${#_Options_UP[@]}";

                if (( ${#_Options_UP[@]} > 0 ));
                then
                    printf -- ': ';
                    _printArray -e -k -p ' ' -a _Options_UP;
                fi

                printf -- '\n# Parsed split parameters (%s)' "${#_Options_P[@]}";

                if (( ${#_Options_P[@]} > 0 ));
                then
                    printf -- ': ';
                    _printArray -e -k -p ' ' -a _Options_P;
                fi

                printf -- '\n# Parsed unsplit flags (%s)' "${#_Options_UF[@]}";

                if (( ${#_Options_UF[@]} > 0 ));
                then
                    printf -- ': ';
                    _printArray -e -k -p ' ' -a _Options_UF;
                fi

                printf -- '\n# Parsed split flags (%s)' "${#_Options_F[@]}";

                if (( ${#_Options_F[@]} > 0 ));
                then
                    printf -- ': ';
                    _printArray -e -k -a -p ' ' _Options_F;
                fi

                printf -- $'\n# ---\n';
                printf -- $'# Validation default mode: \'%s\'\n' "$_Options_validateModeDefault";
                printf -- $'# Validation default expression: \'%s\'\n' "$_Options_validateExpressionDefault";
                printf -- $'# Validation modes (%s)' "${#_Options_validateModes[@]}";

                if (( ${#_Options_validateModes[@]} > 0 ));
                then
                    printf -- ': ';
                    _printArray -e -k -p ' ' -a _Options_validateModes;
                fi

                printf -- '\n# Validation rules (%s)' "${#_Options_validateExpressions[@]}";

                if (( ${#_Options_validateExpressions[@]} > 0 ));
                then
                    printf -- ': ';
                    _printArray -e -k -p ' ' -a _Options_validateExpressions;
                fi

                printf -- $'\n# ---\n';
                printf -- $'# Replacement default mode: \'%s\'\n' "$_Options_replaceDefaultMode";
                printf -- $'# Replacement default expression: \'%s\'\n' "$_Options_replaceExpressionDefault";
                printf -- $'# Replacement modes (%s)' "${#_Options_replaceModes[@]}";

                if (( ${#_Options_replaceModes[@]} > 0 ));
                then
                    printf -- ': ';
                    _printArray -e -k -p ' ' -m _decToBin -a _Options_replaceModes;
                fi

                printf -- '\n# Replacement rules (%s)' "${#_Options_replaceExpressions[@]}";

                if (( ${#_Options_replaceExpressions[@]} > 0 ));
                then
                    printf -- ': ';
                    _printArray -e -k -p ' ' -a _Options_replaceExpressions;
                fi

                printf -- '\n# Replacements (%s)' "${#_Options_replacements[@]}";

                if (( ${#_Options_replacements[@]} > 0 ));
                then
                    printf -- ': ';
                    _printArray -e -k -p ' ' -a _Options_replacements;
                fi

                printf -- $'\n# ---\n';
                printf -- $'# Unprocessed options (%s): ' "${#_Options_O[@]}"; _printArray -e -k -p ' ' -- "${_Options_O[@]}";
                printf -- $'\n# ----- //\n';
            } \
                1>&2;
        elif [[
            # If print "result"
            "$debugType" == 'result' &&
            "${_OPTIONS_LIB_DEBUGSteps["$debugType"]-}" == 1
        ]];
        then
            {
                printf -- $'\n';
                printf -- $'# // ----- (%s)\n#\n' "$debugType";

                declare __variableReferenceName="$1";
                shift;

                declare -n reference="$__variableReferenceName";
                declare referenceFinalValues=( "${reference[@]}" );
                declare referenceFinalValuesCount="${#referenceFinalValues[@]}";

                declare references;
                readarray -t references < <( set | grep -- "^${__variableReferenceName}" | sed -e 's/=.*//'; );
                declare referencesCount=${#references[@]};

                declare referenceItems=();
                declare referenceIndex;

                for (( referenceIndex = 0; referenceIndex < referencesCount; referenceIndex++ ));
                do
                    declare referenceName="${references[$referenceIndex]}";
                    referenceItems+=( "$( declare -p -- "$referenceName"; )" );
                done

                declare parsedItems=( "$@" );
                declare parsedItemsCount="${#parsedItems[@]}";
                declare unsplitPatternsCount="${#_Options_U[@]}";
                declare parameterUnsplitPatternsCount="${#_Options_UP[@]}";
                declare flagUnsplitPatternsCount="${#_Options_UF[@]}";
                declare parsedKnownCount="$(( parameterUnsplitPatternsCount + flagUnsplitPatternsCount ))";
                declare parsedPlainCount="$(( parsedItemsCount - parsedKnownCount ))";
                declare totalIndexPadding="${#parsedItemsCount}";

                if (( _OPTIONS_LIB_DEBUG > 1 ));
                then
                    printf -- $'# \'unparsedItems\' (total %s): %s\n' "$unsplitPatternsCount" "$( _printArray -- "${_Options_U[@]}"; )";
                    printf -- $'# \'parsedParameters\' (total %s): %s\n' "$parameterUnsplitPatternsCount" "$( _printArray -- "${_Options_UP[@]}"; )";
                    printf -- $'# \'parsedFlags\' (total %s): %s\n' "$flagUnsplitPatternsCount" "$( _printArray -- "${_Options_UF[@]}"; )";
                    printf -- $'# \'parsedItems\' (total %s): %s\n' "$parsedItemsCount" "$( _printArray -- "${parsedItems[@]}"; )";
                    printf -- $'# ---\n';
                    printf -- $'# \'referenceName\': \'%s\'\n' "$__variableReferenceName";
                    printf -- $'# \'references\' (total %s): \n' "$referencesCount"; _printArray -k -p ' ' -e -- "${referenceItems[@]}"; printf -- '\n';
                    printf -- $'# \'referenceFinalValues\' (total %s): ' "$referenceFinalValuesCount"; _printArray -k -p ' ' -e -- "${referenceFinalValues[@]}"; printf -- '\n';
                    printf -- $'# ---\n';
                fi

                # Parameters (print parameter patterns and arguments if available).

                if (( parameterUnsplitPatternsCount > 0 ));
                then
                    printf -- '# Parameter arguments (total %s of %s):\n' "$parameterUnsplitPatternsCount" "$parsedItemsCount" 1>&2;
                    declare indexPadding="${#parameterUnsplitPatternsCount}";
                    declare optionIndex;
                    declare parameterIndex=0;

                    for (( optionIndex = 0; optionIndex < unsplitPatternsCount; optionIndex++ ));
                    do
                        # If option is not of type "parameter"
                        if [[ "${_Options_T[$optionIndex]}" != 1 ]];
                        then
                            continue;
                        fi

                        declare -n parameterArguments="${__variableReferenceName}${optionIndex}";
                        declare argsCount=${#parameterArguments[@]};

                        declare -n nextParameterArguments="${__variableReferenceName}$(( optionIndex + 1 ))";
                        declare nextArgsCount=0;

                        # If next option is parameter
                        if [[ "${_Options_T[$(( optionIndex + 1 ))]-0}" == 1 ]];
                        then
                            declare nextArgsCount=${#nextParameterArguments[@]};
                        fi;

                        declare optionDepthChar; optionDepthChar="$( (( (parameterIndex + 1) < parameterUnsplitPatternsCount )) && printf '├' || printf '└'; )";

                        # If no arguments found
                        if (( ! argsCount ));
                        then
                            declare parameterIndex="$(( parameterIndex + 1 ))";

                            continue;
                        fi

                        printf '# │\n' 1>&2;

                        # If no arguments found
                        if (( argsCount == 1 ));
                        then
                            # shellcheck disable=SC2059
                            printf -- $"# %s─ [%${totalIndexPadding}s] [%${indexPadding}s] '%s' (total %s): \'%s\'\n" \
                                "$optionDepthChar" "$optionIndex" "$parameterIndex" "${_Options_UP[$parameterIndex]}" "$argsCount" "${parsedItems[$optionIndex]}" 1>&2;

                            declare parameterIndex="$(( parameterIndex + 1 ))";

                            continue;
                        fi

                        # shellcheck disable=SC2059
                        printf -- $"# %s─ [%${totalIndexPadding}s] [%${indexPadding}s] '%s' (total %s): \'%s\'\n" \
                            "$optionDepthChar" "$optionIndex" "$parameterIndex" "${_Options_UP[$parameterIndex]}" "$argsCount" "${parsedItems[$optionIndex]}" 1>&2;

                        declare optionDepthChar; optionDepthChar="$( (( (parameterIndex + 1) < parameterUnsplitPatternsCount && nextArgsCount > 0 )) && printf '│' || printf ' '; )";
                        declare argIndexPadding="${#argsCount}";
                        declare argIndex;

                        for (( argIndex = 0; argIndex < argsCount; argIndex++ ));
                        do
                            declare argValue="${parameterArguments[$argIndex]}";
                            declare argDepthChar; argDepthChar="$( (( (argIndex + 1) < argsCount )) && printf '├' || printf '└'; )";

                            # shellcheck disable=SC2059
                            printf -- $"# %s       %s─ [%${argIndexPadding}s]: '%s'\n" \
                                "$optionDepthChar" "$argDepthChar" "$argIndex" "$argValue" 1>&2;
                        done

                        declare parameterIndex="$(( parameterIndex + 1 ))";
                    done
                else
                    printf -- '# No parameter arguments found\n';
                fi

                printf -- '# \n';

                # Flags (print flag patterns and values if available).

                if (( flagUnsplitPatternsCount > 0 ));
                then
                    printf -- '# Flags (total %s of %s):\n# │\n' "$flagUnsplitPatternsCount" "$parsedItemsCount";
                    declare indexPadding="${#flagUnsplitPatternsCount}";
                    declare optionIndex;
                    declare flagIndex=0;

                    for (( optionIndex = 0; optionIndex < unsplitPatternsCount; optionIndex++ ));
                    do
                        # If option is not of type "flag"
                        if [[ "${_Options_T[$optionIndex]}" != 0 ]];
                        then
                            continue;
                        fi

                        declare connectionChar; connectionChar="$( (( (flagIndex + 1) < flagUnsplitPatternsCount )) && printf '├' || printf '└'; )";

                        # shellcheck disable=SC2059
                        printf -- $"# %s─ [%${totalIndexPadding}s] [%${indexPadding}s] '%s': '%s'\n" \
                            "$connectionChar" "$optionIndex" "$flagIndex" "${_Options_UF[$flagIndex]}" "${parsedItems[$optionIndex]}" 1>&2;

                        declare flagIndex="$(( flagIndex + 1 ))";
                    done
                else
                    printf -- '# No flags found\n';
                fi

                printf -- '# \n';

                # Plain values (print if available).

                if (( parsedPlainCount > 0 ));
                then
                    printf -- '# Plain values (total %s of %s):\n# │\n' "$parsedPlainCount" "$parsedItemsCount";
                    declare indexPadding="${#parsedPlainCount}";
                    declare optionIndex;

                    for (( optionIndex = 0; optionIndex < parsedPlainCount; optionIndex++ ));
                    do
                        declare valueIndex="$(( optionIndex + parsedKnownCount ))";
                        declare connectionChar; connectionChar="$( (( (optionIndex + 1) < parsedPlainCount )) && printf '├' || printf '└'; )";

                        # shellcheck disable=SC2059
                        printf -- $"# %s─ [%${totalIndexPadding}s] [%${indexPadding}s] '%s'\n" \
                            "$connectionChar" "$valueIndex" "$optionIndex" "${parsedItems[$valueIndex]}" 1>&2;
                    done
                else
                    printf -- '# No plain values\n';
                fi

                printf -- $'#\n# ----- //\n';
            } \
                1>&2;
        fi

        # If "Debug End"
        if (( "$_OPTIONS_LIB_DEBUG_STEP" >= "${#_OPTIONS_LIB_DEBUGSteps[@]}" ))
        then
            if [[ "${_OPTIONS_LIB_DEBUGSteps['end']-}" == 1 ]];
            then
                {
                    printf -- $'\n# ////////////////////////////////////////////////////////////////\n# //\n# // [Shell Library] [Debug] [Options] End\n\n';
                } \
                    1>&2;
            fi

            _OPTIONS_LIB_DEBUG_STEP="$(( _OPTIONS_LIB_DEBUG_STEP + 1 ))";
        fi

        return 0;
    }

    # Main
    # ----------------------------------------------------------------

    # @debug
    _debug -s 'call_stack';

    # Options_resetGlobalVariables;

    # Reset the result of a parse
    _setResultCode -r;

    # If too few function arguments (no pattern and possible element) were declared
    if (( "$#" < 2 ));
    then
        _setResultCode 14;

        return "$_Options_RC";
    fi

    _Options_A=( "$@" );

    # Set the parsing result variable reference
    declare outputVariableReferenceName="$1";
    shift;

    # Switches
    # --------------------------------

    # Reset switches
    _switch -r;

    # @todo Move the whole switches parsing to the function "_switch" itself?

    declare switchesString;

    # If found a switch(-es) (i.e. the first option contains either 0 or 1 only; e.g. '0100101')
    if [[ "$1" =~ ^([01]+|0x[0-9A-Fa-f]+)$ ]];
    then
        declare switchesString="$1";
        shift;

        # Try setting the switches
        if ! _switch -s "$switchesString";
        then
            _setResultCode 10;

            return "$_Options_RC";
        fi
    fi

    # In case an output variable has the same name as the reference (may interfere)
    if
        [[
            "$outputVariableReferenceName" == 'Options_OutputVariableReference' ||
            "$outputVariableReferenceName" == 'Options_OutputVariableReferenceTemp'
        ]];
    then
        _setResultCode 22;

        return "$_Options_RC";
    fi

    declare -n Options_OutputVariableReference="$outputVariableReferenceName";
    Options_OutputVariableReference=();

    # Reset validations
    _validateValue -r;
    # Reset replacements
    _replaceValue -r;
    declare initialOptionIndex;
    declare replacementRule;

    # Try adding replacement and validation rules

    # Loop through each initial option
    for (( initialOptionIndex = 1; initialOptionIndex < "${#_Options_A[@]}"; initialOptionIndex += 1 ));
    do
        # If a replacement rule was found
        if [[ "${replacementRule+s}" != '' ]];
        then
            declare replacementValue="$2";

            # Try adding a replacement ("rule" "replacement")
            _replaceValue -a "$replacementRule" "$replacementValue";
            declare expressionAddResult=$?;

            # If added the replacement rule and replacement successfully
            if [[ "$expressionAddResult" == 0 ]];
            then
                # Remove replacement rule and value from initial options
                shift 2;

                unset replacementRule;

                continue;
            fi

            # If the expression is invalid
            if [[ "$expressionAddResult" == 2 ]];
            then
                # "Invalid replacement expression"
                _setResultCode 26 "$(( initialOptionIndex - 1 ))";

                return "$_Options_RC";
            fi

            # If replacement expression duplicate
            if [[ "$expressionAddResult" == 3 ]];
            then
                # "Replacement expression duplicate"
                _setResultCode 25 "$(( initialOptionIndex - 1 ))";

                return "$_Options_RC";
            fi

            # If replacement function is invalid
            if [[ "$expressionAddResult" == 6 ]];
            then
                # "Invalid replacement function"
                _setResultCode 29 "$(( initialOptionIndex - 1 ))";

                return "$_Options_RC";
            fi

            # "Invalid rule format"
            _setResultCode 27 "$(( initialOptionIndex - 1 ))";

            return "$_Options_RC";
        fi

        # If not validation nor replacement rule
        if [[ "${1:0:1}" != '/' ]];
        then
            continue;
        fi

        # Replacement
        # --------------------------------

        # If replacement rule (simple, regex, or function)
        if [[ "${1:0:2}" =~ ^/(/|!)$ ]];
        then
            # Set replacement rule
            declare replacementRule="$1";

            # Continue to the replacement to also process the rule
            continue;
        fi

        # Validation
        # --------------------------------

        declare validationRule="$1";

        # Try adding a validation rule
        _validateValue -a "$validationRule";
        declare expressionAddResult=$?;

        # If added the validation rule successfully
        if [[ "$expressionAddResult" == 0 ]];
        then
            shift; # Remove expression(s) from declared function options

            continue;
        fi

        # If invalid validation expression
        if [[ "$expressionAddResult" == 2 ]];
        then
            # "Invalid validation expression"
            _setResultCode 16 "$(( initialOptionIndex - 1 ))";

            return "$_Options_RC";
        fi

        # If validation expression duplicate
        if [[ "$expressionAddResult" == 3 ]];
        then
            # "Validation expression duplicate"
            _setResultCode 17 "$(( initialOptionIndex - 1 ))";

            return "$_Options_RC";
        fi

        # "Invalid rule format"
        _setResultCode 27 "$(( initialOptionIndex - 1 ))";

        return "$_Options_RC";
    done

    # Patterns
    # --------------------------------

    declare patternsString="$1";
    shift;

    # A pattern or rule may also start with a switch char. For example, "Options '%1;?-x' "$@" where patterns are: "1" flag, "-s" parameter.
    if [[ "${patternsString:0:1}" == "%" ]];
    then
        declare patternsString="${patternsString:1}";
    fi

    # If the pattern is empty
    if [[ "$patternsString" == '' ]];
    then
        # Set the result code to error and the index from the expressions loop which stopped at this option
        _setResultCode 6 "$(( initialOptionIndex - 1 ))";

        return "$_Options_RC";
    fi

    # Store actual options (to be parsed)
    _Options_O=( "$@" );

    declare elements=( "${_Options_O[@]}" );
    declare doubleDashPosition; doubleDashPosition="$( _findArrayElement '--' "$@" )"; # If "--" option exists return its position
    declare valuesAdditional=(); # Array with plain values which are after "--" option

    # If the option "--" exists then separate options and plain values(before and after "--" option)
    if [[ "$doubleDashPosition" != '' ]];
    then
        declare elements=( "${@:1:$doubleDashPosition}" ); # Options before "--" option
        declare valuesAdditional=( "${@:$(( doubleDashPosition + 2 ))}" ); # Options after "--" option
    fi

    # Split all patterns
    declare patterns;
    IFS=';' read -ra patterns <<< "$patternsString";

    # Store unparsed patterns
    _Options_U=( "${patterns[@]}" );
    _Options_UP=();
    _Options_UF=();
    declare flagPatterns=(); # For array of flag options
    declare parameterPatterns=(); # For array of options which require an argument - patterns
    declare pattern;
    declare patternIndex;

    # Fill up separated arrays of parameter and flag patterns, and validate some rules.
    for (( patternIndex = 0; patternIndex < ${#_Options_U[@]}; patternIndex++ ));
    do
        declare pattern="${_Options_U[$patternIndex]}";
        declare optionIsParameter=0;

        # If the first char is '!'
        if [[ "${pattern:0:1}" == '!' ]];
        then
            # Options is required

            # Remove char '!'
            declare pattern="${pattern:1}";
        fi

        # If the first char is '?'
        if [[ "${pattern:0:1}" == '?' ]]; then
            # Option is a parameter (i.e. expects an argument after "=" char or as the next element).

            declare optionIsParameter=1;

            # Remove char '?'
            declare pattern="${pattern:1}";

            _Options_T[patternIndex]=1;
            _Options_parameterIndexes+=( "$patternIndex" );
        else
            _Options_T[patternIndex]=0;
            _Options_flagIndexes+=( "$patternIndex" );
        fi

        # If the first char is '%'
        if [[ "${pattern:0:1}" == '%' ]];
        then
            # Possibly, was used to prevent effect of previous pattern modifiers like '!', '?', '%'.

            # Remove char '%'
            declare pattern="${pattern:1}";
        fi

        if
            [[
                # If pattern is flag
                "$optionIsParameter" == 0 &&
                # ...and replacement rule exists
                "${_Options_replaceModes[$patternIndex]+s}" != '' &&
                # ...and the replacement is not a number
                ! "${_Options_replacements[$patternIndex]}" =~ ^(0|[1-9][0-9]*)$
            ]];
        then
            # "Invalid replacement for flag"
            _setResultCode 28 "$patternIndex";

            return "$_Options_RC";
        fi

        # Store unsplit option patterns

        if [[ "$optionIsParameter" == 1 ]];
        then
            _Options_UP+=( "$pattern" );
        else
            _Options_UF+=( "$pattern" );
        fi

        # Store split option patterns

        declare patternVariants=''; # For array from loop
        IFS=':' read -ra patternVariants <<< "$pattern"; # Create an array with ":" delimiter

        # If pattern expects a value then add its element(s) to options' array else add its element(s) to flags' array
        if [[ "$optionIsParameter" == 1 ]];
        then
            parameterPatterns+=( "${patternVariants[@]}" );
        else
            flagPatterns+=( "${patternVariants[@]}" );
        fi
    done

    # Store parsed patterns
    _Options_F=( "${flagPatterns[@]}" );
    _Options_P=( "${parameterPatterns[@]}" );

    # Processed initials

    # @debug
    _debug -s 'processed_initials';

    # If pattern '--' exists
    if _findArrayElement '-' '--' "${flagPatterns[@]}" "${parameterPatterns[@]}";
    then
        _setResultCode 13;

        return "$_Options_RC";
    fi

    # If any pattern duplicate exists
    if
        [[
            # If any parameter option pattern duplicate is found
            "$(printf '%s\n' "${parameterPatterns[@]}" | LC_ALL=C sort | wc -l)" != "$(printf '%s\n' "${parameterPatterns[@]}" | LC_ALL=C sort | uniq | wc -l)" ||

            # If any flag option pattern duplicate is found
            "$(printf '%s\n' "${flagPatterns[@]}" | LC_ALL=C sort | wc -l)" != "$(printf '%s\n' "${flagPatterns[@]}" | LC_ALL=C sort | uniq | wc -l)" ||

            # If any parameter option pattern matches a flag
            "$(LC_ALL=C comm -1 -2  <(printf '%s\n' "${parameterPatterns[@]}" | LC_ALL=C sort) <(printf '%s\n' "${flagPatterns[@]}" | LC_ALL=C sort))" != ''
        ]];
    then
        # Pattern duplicate
        _setResultCode 1;

        return "$_Options_RC";
    fi

    # If combined short options are allowed
    if _switch 8;
    then
        # Try splitting combined short options.

        declare elementsTemp=(); # Temporary array of split multiple options from one and other options
        declare nextElementIsArgument=''; # If skip option because it's a value for previous option
        declare element=''; # For split loop when splitting multiple options from one
        declare elementIndex;

        # Loop through all elements(before "--", if exists)
        for (( elementIndex = 0; elementIndex < "${#elements[@]}"; elementIndex++ ));
        do
            element="${elements[$elementIndex]}";
            declare optionName="${element%%=*}"; # Get the possible option's name

            # If it's the value for the previous option
            if [[ "$nextElementIsArgument" == 1 ]];
            then
                elementsTemp+=("$element"); # Add an option because it's a
                declare nextElementIsArgument=0;

                continue;
            fi

            # If the option is an argument option
            if ! _findArrayElement '-' "%${optionName}" "${parameterPatterns[@]}";
            then
                # If the option doesn't start from the '-' character or starts with '--' characters or is not an option with the leading '=' character
                if
                    [[
                        "${element:0:1}" != '-' ||
                        "${element:1:1}" == '-' ||
                        "${element:1:1}" == '=' ||
                        "${element:2:1}" == '='
                    ]];
                then
                    elementsTemp+=( "$element" ); # Add a not combined option

                    continue;
                fi

                # If encountered the option '-'
                if [[ "$element" == '-' ]];
                then
                    _setResultCode 21 "$elementIndex";

                    return "$_Options_RC";
                fi

                # Get everything after '-' character from the element
                declare optionNameDirty="${element#-*}";

                # If the option name has only one character
                if [[ "${#optionNameDirty}" == 1 ]];
                then
                    elementsTemp+=( "$element" ); # Add a not combined option

                    continue;
                fi

                declare optionNameCharacterIndex;
                declare optionNameCharacter;
                declare optionsSplit=(); # An array of split and other options

                # Loop through all characters in the option's name
                for (( optionNameCharacterIndex=0; optionNameCharacterIndex < "${#optionNameDirty}"; optionNameCharacterIndex++ ));
                do
                    # Set current character
                    declare optionNameCharacter="${optionNameDirty:optionNameCharacterIndex:1}";

                    # If it's not the '-' character and the prefix '-' for split short options is enabled
                    if [[ "$optionNameCharacter" != '-' ]] && _switch 16;
                    then
                        # Add the prefix to the option
                        declare optionNameCharacter="${_Options_optionShortCombinedPrefix}${optionNameCharacter}";
                    fi

                    # If the next character is '=' and combined short options with a leading '=' character and joined argument are allowed
                    if [[ "${optionNameDirty:$(( optionNameCharacterIndex + 1 )):1}" == '=' ]] && _switch 6;
                    then
                        # Add the option with the leading '=' and its argument
                        optionsSplit+=("${optionNameCharacter}${optionNameDirty:$(( optionNameCharacterIndex + 1 ))}");

                        break;
                    fi

                    # Add the short option
                    optionsSplit+=( "$optionNameCharacter" );

                    # If there's such short argument option
                    if _findArrayElement '-' "%${optionNameCharacter}" "${parameterPatterns[@]}";
                    then
                        # If this is the last character
                        if [[ "${optionNameDirty:$(( optionNameCharacterIndex + 1 ))}" == '' ]];
                        then
                            # The next element is an argument
                            declare nextElementIsArgument=1;

                            continue;
                        fi

                        # If options combined with values are allowed
                        if _switch 7;
                        then
                            # Add the option with everything joined as its argument
                            optionsSplit+=("${optionNameDirty:$(( optionNameCharacterIndex + 1 ))}");

                            break;
                        fi

                        # Encountered an option combined with its possible value
                        _setResultCode 11 "$elementIndex";

                        return "$_Options_RC";
                    fi
                done

                # Add split and other options
                elementsTemp+=("${optionsSplit[@]}");

                continue;
            fi

            # Add a not combined option
            elementsTemp+=( "$element" );

            # If there's no leading "=" character
            if [[ "${element:${#optionName}:1}" != '=' ]];
            then
                # The next element is an argument
                declare nextElementIsArgument=1;
            fi
        done

        # Add all split and other options to array of all options
        elements=( "${elementsTemp[@]}" );
    fi

    # Validate processed initials
    # --------------------------------

    # If too many validations
    if (( ${#_Options_validateExpressions[@]} > ${#_Options_P[@]} )) && ! _switch 13;
    then
        # Validation rule count overflow
        _setResultCode 18;

        return "$_Options_RC";
    fi

    # If too many replacement rules for argument options (parameters)
    if (( ${#_Options_replaceExpressions[@]} > ${#_Options_P[@]} ));
    then
        # "Replacement rule count overflow"
        _setResultCode 23;

        return "$_Options_RC";
    fi

    # Parse actual options
    # --------------------------------

    declare optionPlains=(); # An array for all plain values
    declare optionFinalValues=(); # An array for all option values

    # If already checked all elements in array (before "--", if exists; for force next pattern (if there were plain values after
    # last checked pattern and also all patterns were found)).
    declare checkedAllElements='';

    declare pattern; # For loop when looping through each pattern divided by ";" char
    declare patternIndex;

    # # Loop through each pattern (Between ';')
    # for (( patternIndex = 0; patternIndex < ${#_Options_U[@]}; patternIndex++ ));
    # do
    #     # Set the option's presence counter to 0
    #     Options_OutputVariableReferenceCountTemp[patternIndex]=0;
    # done

    # @todo Reconsider the similar logic above which parses patterns and separates flags and arguments ignoring the options order
    # Loop through each pattern (Between ';')
    for (( patternIndex = 0; patternIndex < ${#_Options_U[@]}; patternIndex++ ));
    do
        declare pattern="${_Options_U[$patternIndex]}";
        declare optionIsRequired=0;
        declare optionIsParameter=0;

        # If the first char is '!'
        if [[ "${pattern:0:1}" == '!' ]];
        then
            # Options is required

            declare optionIsRequired=1;

            # Remove char '!'
            declare pattern="${pattern:1}";
        fi

        # If the first char is '?'
        if [[ "${pattern:0:1}" == '?' ]];
        then
            # Option is a parameter (i.e. expects an argument after "=" char or as the next element).

            declare optionIsParameter=1;

            # Remove char '?'
            declare pattern="${pattern:1}";
        fi

        # If the first char is '%'
        if [[ "${pattern:0:1}" == '%' ]];
        then
            # Possibly, was used to prevent effect of previous pattern modifiers like '!', '?', '%'.

            # Remove char '%'
            declare pattern="${pattern:1}";
        fi

        declare patternVariants; # For array from loop
        IFS=':' read -ra patternVariants <<< "$pattern";

        # printf $'\n ///// PATTERN[%s]: \'%s\'\n' "$patternIndex" "$pattern";

        declare optionPlainCount=0; # Current plain value's index
        declare nextElementIsArgument=0; # If get value from next option inside loop
        declare skipToNextPattern=0; # If got final option (pattern) value
        declare skipElement=0; # If currently element is a value for previous element-parameter
        declare optionValue;
        unset optionValue; # Unset option's value
        declare element; # For loop
        declare elementIndex;

        # declare -p elements;

        # Loop through all elements(before "--", if exists)
        for (( elementIndex = 0; elementIndex < ${#elements[@]}; elementIndex++ ));
        do
            # If skip to the next option pattern and all elements were parsed
            if [[ "$skipToNextPattern" == 1 && "$checkedAllElements" == 1 ]];
            then
                break;
            fi

            declare element="${elements[$elementIndex]}";

            # If the previous element was an option which expects the current to be its value (e.g. an argument for a parameter)
            if [[ "$nextElementIsArgument" == 1 ]];
            then
                # If the argument is prefixed with character '-' and that's prohibited
                if [[ "${element:0:1}" == '-' ]] && ! _switch 11;
                then
                    _setResultCode 2 "$elementIndex";

                    return "$_Options_RC";
                fi

                # If skip to the next option pattern (a value has already been set and checked)
                if [[ "$skipToNextPattern" == 1 ]];
                then
                    break;
                fi

                declare optionValue="$element"; # Set an actual value of the option

                _validateOptionValue "$optionValue" "$patternIndex" || return $?;

                _setOptionValue "$patternIndex" "$optionValue";

                declare nextElementIsArgument=0; # Tell the loop that value for the option was gathered

                # @todo Re-verify behavior
                # Tell the loop to not skip the next option (may happen when more than one option appears in the pattern, any option had a value and
                # another option told to skip the next option since they search in known option(s))
                declare skipElement=0;

                # If skip to the next pattern after the first argument occurrence
                if _switch 14;
                then
                    declare skipToNextPattern=1; # Skip to the next option pattern

                    break;
                fi

                continue;
            fi

            if [[ "$skipElement" == 1 ]];
            then
                declare skipElement=0; # An element is a value for the previous option (not current)

                continue;
            fi

            declare patternVariant=''; # For loop of options in pattern of patterns (between ":")
            unset optionPlain; # Temporary plain value

            # Loop through each pattern variant in the pattern (between ':')
            for (( patternVariantIndex = 0; patternVariantIndex < ${#patternVariants[@]}; patternVariantIndex++ ));
            do
                declare patternVariant="${patternVariants[$patternVariantIndex]}";

                # If the pattern variant is empty
                if [[ "$patternVariant" == '' ]];
                then
                    _setResultCode 20 "$patternVariantIndex";

                    return "$_Options_RC";
                fi

                # If the pattern variant doesn't assume a general option or an argument-like option (no '-' prefix)
                if [[ "${patternVariant:0:1}" != '-' ]] && ! _switch 5;
                then
                    # "Encountered pattern not prefixed with '-'"
                    _setResultCode 5 "$patternVariantIndex";

                    return "$_Options_RC";
                fi

                case "$patternVariant" in
                    # (Flag/Parameter) i.e. '-a' or '-a a'
                    "$element")
                        # If pattern has "?" char at the start(which means that it requires next option be a value) then
                        # get value from next option else default value for flag
                        if [[ "$optionIsParameter" == 1 ]];
                        then
                            declare nextElementIsArgument=1;

                            continue;
                        fi

                        if [[ "$skipToNextPattern" == 1 ]];
                        then
                            break;
                        fi

                        # Increase the flag's counter
                        declare optionValue="$(( ${optionValue-0} + 1 ))";

                        _validateOptionValue "$optionValue" "$patternIndex" || return $?;

                        _setOptionValue "$patternIndex" "$optionValue";

                        # If skip to the next pattern after the first flag occurrence
                        if _switch 15;
                        then
                            declare skipToNextPattern=1; # Skip to the next option pattern

                            break;
                        fi
                    ;;

                    # (Parameter) i.e. '-a=[value]' (includes empty values)
                    "${element%%=?*}")
                        declare optionName="${element%%=*}";

                        if ! _findArrayElement '-' "%${optionName}" "${_Options_P[@]}"; # If option expects value
                        then
                            _setResultCode 7 "$elementIndex"; # Encountered a value for a flag

                            return "$_Options_RC";
                        fi

                        declare optionValueTemp="${element#*=}"; # A value of option(after "=" char)

                        # If the argument after the '=' character is prefixed with the '-' character and that's prohibited
                        if [[ "${optionValueTemp:0:1}" == '-' ]] && ! _switch 12;
                        then
                            # Encountered an argument prefixed with character '-' after '=' character
                            _setResultCode 9 "$elementIndex";

                            return "$_Options_RC";
                        fi

                        # Encountered empty value for parameter after '=' character
                        # _setResultCode 12 "$elementIndex";

                        if [[ "$skipToNextPattern" == 1 ]]; # If skip to the next option pattern
                        then
                            break;
                        fi

                        declare optionValue="$optionValueTemp"; # Set an actual argument of the option

                        _validateOptionValue "$optionValue" "$patternIndex" || return $?;

                        _setOptionValue "$patternIndex" "$optionValue";

                        # If skip to next pattern after the first argument occurrence
                        if _switch 14;
                        then
                            declare skipToNextPattern=1; # Skip to the next option pattern

                            break;
                        fi
                    ;;

                    # (Argument, Plain) Plain value or it's not related to the currently processed pattern
                    *)
                        # Get the name of the option(before "=" char or whole)
                        declare optionName="${element%%=*}";

                        # If the element is a supported option
                        if _findArrayElement '-' "%${optionName}" "${_Options_P[@]}";
                        then
                            # If the option assumes the next element to be its value
                            if [[ "${element:${#optionName}:1}" != '=' ]];
                            then
                                # Skip the next iteration
                                declare skipElement=1;
                            fi
                        elif ! _findArrayElement '-' "%${optionName}" "${_Options_F[@]}"; # If the element is not a supported flag
                        then
                            # If it's an unsupported/unknown option and option-like arguments are not allowed
                            if [[ "${element:0:1}" == '-' ]] && ! _switch 4;
                            then
                                # Unknown option
                                _setResultCode 4 "$elementIndex";

                                return "$_Options_RC";
                            fi

                            # It is a plain value
                            declare optionPlain="$element";
                        fi
                    ;;
                esac
            done

            # If it was a plain value
            if [[ "${optionPlain+s}" != '' ]];
            then
                # Increase the current plain value index
                declare optionPlainCount="$(( optionPlainCount + 1 ))";

                # If the current plain value index is bigger than the plain value array length then add it to the plain value's array
                if (( optionPlainCount > ${#optionPlains[@]} ));
                then
                    optionPlains+=( "$optionPlain" );
                fi

                continue;
            fi
        done

        # Parsed a pattern

        # If argument for parameter is missing
        if [[ "$nextElementIsArgument" == 1 ]];
        then
            # "Argument not found"
            _setResultCode 8 "$patternIndex";

            return "$_Options_RC";
        fi

        # Tell that the loop has already iterated through all elements
        # @todo What is the exact purpose of this?
        if [[ "$checkedAllElements" != 1 ]];
        then
            checkedAllElements=1;
        fi

        # If option value is set
        if [[ "${optionValue+s}" != '' ]];
        then
            continue;
        fi

        # Option value is unset.

        # If the option is important/required
        if [[ "$optionIsRequired" == 1 ]];
        then
            # "Required option not found"
            _setResultCode 15 "$patternIndex";

            return "$_Options_RC";
        fi

        # Try validating the unset parameter or default flag value
        if ! _validateValue -v "$patternIndex";
        then
            # "Invalid argument"
            _setResultCode 19 "$patternIndex";

            return "$_Options_RC";
        fi

        # Try replacing the unset parameter or default flag value

        declare Options_replacementTemp;

        # If replaced argument or flag
        if _replaceValue -v Options_replacementTemp "$patternIndex";
        then
            _setOptionValue "$patternIndex" "$Options_replacementTemp";

            continue;
        fi

        # Not replaced

        if [[ "$optionIsParameter" == 1 ]];
        then
            _setOptionValue "$patternIndex";

            continue;
        fi

        _setOptionValue "$patternIndex" "$_Options_flagValueDefault";
    done

    # Successful parsing; Save a result to a variable(firstly, option(s)' and flag(s)' values and, secondly, plain value(s)) and,
    # finally, everything after "--" option.

    unset Options_OutputVariableReferenceTemp;
    declare Options_OutputVariableReferenceTemp=( "${optionFinalValues[@]}" "${optionPlains[@]}" "${valuesAdditional[@]}" );

    # @todo Consider validating plain and additional values

    # Set the result global variable
    # shellcheck disable=SC2034
    Options_OutputVariableReference=( "${Options_OutputVariableReferenceTemp[@]}" );

    # Set the option count global variable
    if _switch 2 || _switch 3;
    then
        # In case an output variable has the same name as the reference (else, may interfere)
        if
            _switch 2 && [[ "$outputVariableReferenceName" == 'Options_OutputVariableReferenceC' ]] ||
            _switch 3 && [[ "$outputVariableReferenceName" == 'Options_OutputVariableReferenceC' ]] ||
            [[ "$outputVariableReferenceName" == 'Options_OutputVariableReferenceCountTotalTemp' ]];
        then
            _setResultCode 22;

            return "$_Options_RC";
        fi

        if _switch 2;
        then
            declare -n Options_OutputVariableReferenceC="${outputVariableReferenceName}C";
            # shellcheck disable=SC2034
            Options_OutputVariableReferenceC=( "${Options_OutputVariableReferenceCountTemp[@]}" );
        fi

        if _switch 3;
        then
            declare -n Options_OutputVariableReferenceT="${outputVariableReferenceName}T";

            unset Options_OutputVariableReferenceCountTotalTemp;
            declare Options_OutputVariableReferenceCountTotalTemp=0;
            declare optionValueCount;

            for optionValueCount in "${Options_OutputVariableReferenceCountTemp[@]}";
            do
                Options_OutputVariableReferenceCountTotalTemp="$((Options_OutputVariableReferenceCountTotalTemp + optionValueCount))";
            done

            # shellcheck disable=SC2034
            Options_OutputVariableReferenceT="$Options_OutputVariableReferenceCountTotalTemp";
        fi
    fi

    _setResultCode 0; # Successfully parsed

    # @debug
    _debug -f -- 'result' "$outputVariableReferenceName" "${Options_OutputVariableReference[@]}";

    return "$_Options_RC";
}
