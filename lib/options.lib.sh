#! /usr/bin/env bash

# Copyright 2016-2023 Artfaith

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
#   For example: `Options args '!?-a;?-b;?-c:--cc;-d' -s '1101' -v '0/[0-9]' -v '1' -r '2/[a-b]+' 'C' -- "$@" || return $?;`.
# @todo Probably add "-%" option for "Options" to use for comments in multi-line calls (just in case?).
#   For example, `Options args '-a;-b' -0 '"-a" - Append changes' -- "$@"`.
# @todo Probably allow declaring option patters in separate options like `Options args -o '!?-a' 'Description' -o '?-b' -o '-c' -- "$@"`.
# @todo Reconsider an addition to "{reference}C" or option provided/set count. Is it possible to set a named variable reference to an associative array?
#   If so, would it be also convenient to return an array which would have set for provided/set actual options, and unset for those which were not found?
# @todo Fix an issue with no plain values found with no pattern provided (e.g. `declare args; Options args '/' "$@" || return $?; echo "${args[@]}"; unset args;`).
# @todo Add rules to specify conflicting options (e.g. option '-a' cannot bet set with option '-b' set, too).
# @todo Add rules to specify overloading/overwriting options of the same type (e.g. if parameters '?-a' and '?-b' are both set, `-b` overwrites argument of '-a').

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Initials
# ----------------------------------------------------------------

declare _Options_sourceFilepath; _Options_sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )"; readonly _Options_sourceFilepath;
declare _Options_sourceDirpath; _Options_sourceDirpath="$( dirname -- "$_Options_sourceFilepath" 2> '/dev/null'; )"; readonly _Options_sourceDirpath;

[[ ! -f "$_Options_sourceFilepath" || ! -d "$_Options_sourceDirpath" ]] && exit 99;

# shellcheck disable=SC2034
declare -r SHELL_LIB_OPTIONS="$_Options_sourceFilepath";

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Constants Private
# ----------------------------------------------------------------
# Arrays
# --------------------------------

# @todo Add previews/examples?
# Default switch values
declare -r _Options_switchesDefault=(
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
    $'Encountered empty value for flag after \'=\' character' #12
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
);

declare -rA _Options_debugSteps=(
    ['start']=1 # Print "start"
    ['call_stack']=1 # Print "call stack"
    ['processed_initials']=1 # Print "processed initials"
    ['result']=1 # Print "result"
    ['end']=1 # Print "end"
);

# Primitives
# --------------------------------

# Switch characters
declare -r _Options_switchDisabledChar='0';
declare -r _Options_switchEnabledChar='1';

# Default value for unset flag
declare -r _Options_flagValueDefault=0;

# Default value for unset parameter argument
declare -r _Options_argumentValueDefault='';

# Custom first char before each option as first option after split(when multiple split from options is allowed)
declare -r _Options_optionShortCombinedPrefix='-';

# Functions
# ----------------------------------------------------------------

Options()
{
    # Variables
    # ----------------------------------------------------------------
    # Primitives
    # --------------------------------

    # Debug
    declare _OPTIONS_DEBUG="${LIB_OPTIONS_DEBUG-0}";
    declare _OPTIONS_DEBUG_STEP=0;

    declare _Options_RC=-1; # Final result code
    declare _Options_FI=-1; # Index of the last failed option parse if any
    declare _Options_FM=''; # Fail error message of the last parse if any (based on '_Options_RC')

    # Variables Private
    # ----------------------------------------------------------------
    # Arrays
    # --------------------------------

    declare _Options_A=(); # All initial options passed to the main function of library "Options".
    declare _Options_U=(); # Unparsed patterns.
    declare _Options_O=(); # Unprocessed options.
    declare _Options_F=(); # Parsed split flag options (those which do not expect values; e.g. '-a -b', '-ab').
    declare _Options_UF=(); # Parsed split flag options (those which do not expect values; e.g. '-a -b', '-ab').
    declare _Options_P=(); # Parsed split parameter options (those which require expect a value; e.g. '-a 1', '--optA 1', '--optA "1 2"', --optA='1 2').
    declare _Options_UP=(); # Parsed split parameter options (those which require expect a value; e.g. '-a 1', '--optA 1', '--optA "1 2"', --optA='1 2').

    # Switches
    declare _Options_S=( "${_Options_switchesDefault[@]}" );

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

    # Print error message and return its code if set
    Options_E()
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

        if ! Options_switch 17;
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

    # Functions Private
    # ----------------------------------------------------------------

    # Set the return code (exit code) and related global variables
    Options_resultCodeSet()
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

            if Options_switch 1;
            then
                Options_E -- "${_Options_O[@]}";
            fi
        fi

        return "$_Options_RC";
    }

    # Check if the array contains any of the declared elements and return the first found position
    Options_arrayFindElement()
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

    Options_printArray()
    {
        declare assocArrayReferenceName;
        declare isAssoc=0;
        declare delimiter=', ';
        declare format;
        declare printKeys=0;
        declare printExtended=0;
        declare paddingChar='';
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
                # declare item="${arrayReference[$itemKey]}";

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
                        "${prefix}${arrayReference[$itemKey]}${postfix}";
                else
                    # shellcheck disable=SC2059
                    printf -- "$format" "${prefix}${arrayReference[$itemKey]}${postfix}";
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

        declare itemCount="$#";

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

        for (( itemIndex = 1; itemIndex <= itemCount; itemIndex++ ));
        do
            if (( printExtended > 0 ));
            then
                printf -- '    ';
            fi

            declare padding='';

            if [[ "$paddingChar" != '' ]];
            then
                declare padding; padding="$(
                    declare p="$(( itemCount - 1 ))";
                    declare i;
                    for (( i = 0; i < (${#p} - ${#itemIndex}); i++ )); do printf '%s' "$paddingChar"; done;
                )";
            fi

            if (( printKeys > 0 ));
            then
                # shellcheck disable=SC2059
                printf -- "$format" "$padding" "$(( itemIndex - 1 ))" "$( (( printExtended == 0 )) && printf '=' || printf ' '; )" \
                    "${prefix}${!itemIndex}${postfix}";
            else
                # shellcheck disable=SC2059
                printf -- "$format" "${prefix}${!itemIndex}${postfix}";
            fi

            if (( printExtended > 0 ));
            then
                printf -- '\n';
            else
                if (( itemIndex + 1 <= itemCount ));
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

    # Get or set switches
    Options_switch()
    {
        # If reset
        if [[ "$1" == '-r' ]];
        then
            _Options_S=( "${_Options_switchesDefault[@]}" );

            return 0;
        fi

        # If set the switches using a switch string (i.e. '0100101') (do we need a dec to bin conversion here just for comfy?)
        if [[ "$1" == '-s' ]];
        then
            shift;
            declare switchesString="$1";

            # If the length of switch string is longer than then the number of switches supported
            if (( ${#switchesString} > ${#_Options_S[@]} ));
            then
                return 2;
            fi

            if [[ ${#_Options_S[@]} != "${#_Options_switchesDefault[@]}" ]];
            then
                Options_switch -r;
            fi

            declare i;

            # Set switches
            for (( i = 0; i < ${#switchesString}; i++ ));
            do
                if [[ "${switchesString:$i:1}" == "$_Options_switchEnabledChar" ]];
                then
                    _Options_S[i]=1;

                    continue;
                fi

                _Options_S[i]=0;
            done

            return 0;
        fi

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

    Options_isRegexValid()
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

    Options_regexTest()
    {
        if (( "$#" < 2 ));
        then
            return 3;
        fi

        declare regex="$1";
        shift;
        declare itemCount="$#";
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

    # Validate option value using extended regular expressions (ERE)
    Options_validateValue()
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
            if [[ "$validateExpression" != '' ]] && ! Options_isRegexValid "$validateExpression";
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
            if [[ "$validateMode" == '0' ]] || ! Options_switch 10;
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

        if ! Options_regexTest "$validateExpression" "$optionValue" &> '/dev/null';
        then
            return 1; # Invalid (does not pass expression)
        fi

        # Valid (passes expression)

        return 0;
    }

    Options_replaceValue()
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
            declare replaceFull="$1";
            declare replacementValue="$2";
            declare replaceIndex='';
            declare replaceExpression='';

            # If replacement is not complex (no regex)
            if [[ "$replaceFull" =~ ^//(0|[1-9][0-9]*)?\??/?$ ]];
            then
                # For example:
                # -  '//',  '//1',  '//?',  '//1?'
                # - '///', '//1/', '//?/', '//1?/'

                declare replaceFull="${1:2}";

                # Index:
                # - Default: '?', '[a-z]+', '?', '';
                # -   Index: '3?', '3', '3?', '3'.
                declare replaceIndex="${replaceFull%%\/*}";
            elif [[ "$replaceFull" =~ ^//(0|[1-9][0-9]*)?\??/ ]];
            then
                # For example:
                # -      '////',      '//1//',      '//?//,      '//1?//' - Regex '/';
                # -  '///[0-9]',  '//1/[0-9]',  '//?/[0-9],  '//1?/[0-9]' - Regex '[0-9]';
                # - '///[0-9]/', '//1/[0-9]/', '//?/[0-9]/, '//1?/[0-9]/' - Regex '[0-9]/'.

                # If index is set
                if [[ "$replaceFull" =~ ^//(0|[1-9][0-9]*)?\??/.+ ]];
                then
                    # e.g. '///[0-9]/' -> '/[0-9]/'
                    declare replaceFull="${1:2}";
                fi

                # Index:
                # - Default: '?', '[a-z]+', '?', '';
                # -   Index: '3?', '3', '3?', '3'.
                declare replaceIndex="${replaceFull%%\/*}";

                # Expression:
                # - Default: '[a-z]+', '', '?', '';
                # -   Index: '[a-z]+', '[a-z]+', '3?', '3'.
                declare replaceExpression="${replaceFull#*\/}";
            else
                # Invalid replacement
                return 5;
            fi

            # Ignore unset option values
            declare replaceMode=0;

            # If the last char in index is '?'
            if [[ "${replaceIndex: -1}" == '?' ]];
            then
                # Replace unset
                declare replaceMode=1;

                # Remove the last char '?'
                declare replaceIndex="${replaceIndex:0:-1}";
            fi

            shift 2;

            # If invalid regex
            if [[ "$replaceExpression" != '' ]] && ! Options_isRegexValid "$replaceExpression";
            then
                return 2; # Invalid replacement
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
                _Options_replaceExpressionDefault="$replaceExpression"; # Either empty or regex
                _Options_replacementDefault="$replacementValue"; # Any string

                return 0;
            fi

            # If such option replace expression exists already
            if [[ "${_Options_replaceModes["$replaceIndex"]+s}" != '' ]];
            then
                return 3; # Already exists (indexed)
            fi

            # Set custom replace expression

            _Options_replaceModes["$replaceIndex"]="$replaceMode";
            _Options_replaceExpressions["$replaceIndex"]="$replaceExpression";
            _Options_replacements["$replaceIndex"]="$replacementValue";

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
            Options_resultCodeSet 22;

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

        # If replace mode is empty or unset
        if [[ "${replaceMode:+s}" == '' ]];
        then
            return 1; # Do not replace
        fi

        # If value is not set
        if [[ "${optionValue+s}" == '' ]];
        then
            # If replace only set
            if [[ "$replaceMode" == '0' ]];
            then
                return 1; # Do not replace
            fi

            # Replace unset

            Options_OutputVariableReference="$replacement";

            return 0;
        fi

        # If expression is not available
        if [[ "$replaceExpression" == '' ]];
        then
            # If value is not empty
            if [[ "${optionValue:+s}" != '' ]];
            then
                return 1; # Do not replace (not empty)
            fi
        elif ! Options_regexTest "$replaceExpression" "$optionValue" &> '/dev/null';
        then
            return 1; # Do not replace (does not match)
        fi

        # Replace (empty or match)

        Options_OutputVariableReference="$replacement";

        return 0;
    }

    # "Debug" ^^"
    Options_Debug()
    {
        # If debugging is disabled
        if (( _OPTIONS_DEBUG == 0 ));
        then
            return 0;
        fi

        # If "Debug Start"
        if (( "$_OPTIONS_DEBUG_STEP" == 0 ));
        then
            if [[  "${_Options_debugSteps['start']-}" == 1 ]];
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
            _OPTIONS_DEBUG_STEP="$(( _OPTIONS_DEBUG_STEP + 1 ))";

            shift;

        # If set final debug step
        elif [[ "$1" == '-f' ]];
        then
            _OPTIONS_DEBUG_STEP="${#_Options_debugSteps[@]}";
            shift;

        # If set to initial debug step
        elif (( "$_OPTIONS_DEBUG_STEP" == 0 ));
        then
            _OPTIONS_DEBUG_STEP="1";
        fi

        # If unexpected behavior: Too many debug step increments.
        if (( "$_OPTIONS_DEBUG_STEP" > "${#_Options_debugSteps[@]}" ));
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
            "${_Options_debugSteps["$debugType"]-}" == 1
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
        elif [[
            # If print "processed initals"
            "$debugType" == 'processed_initials' &&
            "${_Options_debugSteps["$debugType"]-}" == 1
        ]];
        then
            # @todo Apply an adequate array print function (e.g. PHP's 'print_r').

            {
                echo;
                printf -- $'# // ----- (%s)\n#\n' "$debugType";
                echo -n "# Switches (${#_Options_S[@]}): "; Options_printArray -- "${_Options_S[@]}"; printf -- '\n';
                echo -n "# Unparsed initials (${#_Options_A[@]}): "; Options_printArray -k -p ' ' -e -- "${_Options_A[@]}"; printf -- '\n';
                echo '# ---';
                printf -- '# Unparsed patterns (%s)' "${#_Options_U[@]}";
                
                if (( ${#_Options_U[@]} > 0 ));
                then
                    printf -- ': ';
                    Options_printArray -e -k -p ' ' -a _Options_U;
                fi

                printf -- '\n# Parsed unsplit parameters (%s)' "${#_Options_UP[@]}";
                
                if (( ${#_Options_UP[@]} > 0 ));
                then
                    printf -- ': ';
                    Options_printArray -e -k -p ' ' -a _Options_UP;
                fi

                printf -- '\n# Parsed split parameters (%s)' "${#_Options_P[@]}";
                
                if (( ${#_Options_P[@]} > 0 ));
                then
                    printf -- ': ';
                    Options_printArray -e -k -p ' ' -a _Options_P;
                fi

                printf -- '\n# Parsed unsplit flags (%s)' "${#_Options_UF[@]}";
                
                if (( ${#_Options_UF[@]} > 0 ));
                then
                    printf -- ': ';
                    Options_printArray -e -k -p ' ' -a _Options_UF;
                fi

                printf -- '\n# Parsed split flags (%s)' "${#_Options_F[@]}";
                
                if (( ${#_Options_F[@]} > 0 ));
                then
                    printf -- ': ';
                    Options_printArray -e -k -a -p ' ' _Options_F;
                fi

                printf -- '\n# ---\n';
                echo -n "# Validation default mode: '${_Options_validateModeDefault}'"; printf -- '\n';
                echo -n "# Validation default expression: '${_Options_validateExpressionDefault}'"; printf -- '\n';
                printf -- '# Validation modes (%s)' "${#_Options_validateModes[@]}";
                
                if (( ${#_Options_validateModes[@]} > 0 ));
                then
                    printf -- ': ';
                    Options_printArray -e -k -p ' ' -a _Options_validateModes;
                fi

                printf -- '\n# Validation rules (%s)' "${#_Options_validateExpressions[@]}";
                
                if (( ${#_Options_validateExpressions[@]} > 0 ));
                then
                    printf -- ': ';
                    Options_printArray -e -k -p ' ' -a _Options_validateExpressions;
                fi

                printf -- '\n# ---\n';
                echo -n "# Replacement default mode: '${_Options_replaceDefaultMode}'"; printf -- '\n';
                echo -n "# Replacement default expression: '${_Options_replaceExpressionDefault}'"; printf -- '\n';
                printf -- '# Replacement modes (%s)' "${#_Options_replaceModes[@]}";

                if (( ${#_Options_replaceModes[@]} > 0 ));
                then
                    printf -- ': ';
                    Options_printArray -e -k -p ' ' -a _Options_replaceModes;
                fi

                printf -- '\n# Replacement rules (%s)' "${#_Options_replaceExpressions[@]}";

                if (( ${#_Options_replaceExpressions[@]} > 0 ));
                then
                    printf -- ': ';
                    Options_printArray -e -k -p ' ' -a _Options_replaceExpressions;
                fi

                printf -- '\n# Replacements (%s)' "${#_Options_replacements[@]}";

                if (( ${#_Options_replacements[@]} > 0 ));
                then
                    printf -- ': ';
                    Options_printArray -e -k -p ' ' -a _Options_replacements;
                fi

                printf -- '\n# ---\n';
                printf '# Unprocessed options (%s): ' "${#_Options_O[@]}"; Options_printArray -e -k -p ' ' -- "${_Options_O[@]}";
                printf -- $'\n# ----- //\n';
            } \
                1>&2;
        elif [[
            # If print "result"
            "$debugType" == 'result' &&
            "${_Options_debugSteps["$debugType"]-}" == 1
        ]];
        then
            {
                printf -- '\n';
                printf -- $'# // ----- (%s)\n#\n' "$debugType";

                declare variableReferenceName="$1";
                shift;
                declare parsedItems=( "$@" );
                declare parsedItemsCount="${#parsedItems[@]}";
                declare unsplitPatternsCount="${#_Options_U[@]}";
                declare parameterUnsplitPatternsCount="${#_Options_UP[@]}";
                declare flagUnsplitPatternsCount="${#_Options_UF[@]}";
                declare parsedKnownCount="$(( parameterUnsplitPatternsCount + flagUnsplitPatternsCount ))";
                declare parsedPlainCount="$(( parsedItemsCount - parsedKnownCount ))";
                declare totalIndexPadding="${#parsedItemsCount}";

                printf -- $'# \'variableReferenceName\': \'%s\'\n' "$variableReferenceName";
                printf -- $'# \'unparsedItems\' (total %s): %s\n' "$unsplitPatternsCount" "$( Options_printArray -- "${_Options_U[@]}"; )";
                printf -- $'# \'parsedParameters\' (total %s): %s\n' "$parameterUnsplitPatternsCount" "$( Options_printArray -- "${_Options_UP[@]}"; )";
                printf -- $'# \'parsedFlags\' (total %s): %s\n' "$flagUnsplitPatternsCount" "$( Options_printArray -- "${_Options_UF[@]}"; )";
                printf -- $'# \'parsedItems\' (total %s): %s\n' "$parsedItemsCount" "$( Options_printArray -- "${parsedItems[@]}"; )";
                printf -- $'# \n';

                printf -- $'# [Shell Library] [Debug] [Options] Parsed items (total %s):\n# \n' "$parsedItemsCount";

                # @todo Create a function for the follwoing arrays printing.
                # Parameters (print parameter patterns and arguments if available).

                if (( parameterUnsplitPatternsCount > 0 ));
                then
                    printf -- '# Parameter arguments (total %s of %s):\n# │\n' "$parameterUnsplitPatternsCount" "$parsedItemsCount";
                    declare indexPadding="${#parameterUnsplitPatternsCount}";
                    declare optionIndex;

                    for (( optionIndex = 0; optionIndex < parameterUnsplitPatternsCount; optionIndex++ ));
                    do
                        declare connectionChar; connectionChar="$( (( (optionIndex + 1) < parameterUnsplitPatternsCount )) && printf '├' || printf '└'; )";

                        # shellcheck disable=SC2059
                        printf -- $"# %s─ [%${totalIndexPadding}s] [%${indexPadding}s] '%s': '%s'\n" \
                            "$connectionChar" "$optionIndex" "$optionIndex" "${_Options_UP[$optionIndex]}" "${parsedItems[$optionIndex]}" 1>&2;
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

                    for (( optionIndex = 0; optionIndex < flagUnsplitPatternsCount; optionIndex++ ));
                    do
                        declare valueIndex="$(( optionIndex + parameterUnsplitPatternsCount ))";
                        declare connectionChar; connectionChar="$( (( (optionIndex + 1) < flagUnsplitPatternsCount )) && printf '├' || printf '└'; )";

                        # shellcheck disable=SC2059
                        printf -- $"# %s─ [%${totalIndexPadding}s] [%${indexPadding}s] '%s': '%s'\n" \
                            "$connectionChar" "$valueIndex" "$optionIndex" "${_Options_UF[$optionIndex]}" "${parsedItems[$valueIndex]}" 1>&2;
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
        if (( "$_OPTIONS_DEBUG_STEP" >= "${#_Options_debugSteps[@]}" ))
        then
            if [[ "${_Options_debugSteps['end']-}" == 1 ]];
            then
                {
                    printf -- $'\n# // [Shell Library] [Debug] [Options] End\n# //\n# ////////////////////////////////////////////////////////////////\n\n';
                } \
                    1>&2;
            fi

            _OPTIONS_DEBUG_STEP="$(( _OPTIONS_DEBUG_STEP + 1 ))";
        fi

        return 0;
    }

    # Main
    # ----------------------------------------------------------------

    # @debug
    Options_Debug -s 'call_stack';

    # Options_resetGlobalVariables;

    # Reset the result of a parse
    Options_resultCodeSet -r;

    # If too few function arguments (no pattern and possible element) were declared
    if (( "$#" < 2 ));
    then
        Options_resultCodeSet 14;

        return "$_Options_RC";
    fi

    _Options_A=( "$@" );

    # Set the parsing result variable reference
    declare outputVariableReferenceName="$1";
    shift;

    # Switches
    # --------------------------------

    # Reset switches
    Options_switch -r;

    # @todo Move the whole switches parsing to the function "Options_switch" itself?

    declare switchesString;
    declare switchesRegex="^[${_Options_switchDisabledChar}${_Options_switchEnabledChar}]+$";

    # If found a switch(-es) (i.e. the first option contains either 0 or 1 only; e.g. '0100101')
    if [[ "$1" =~ $switchesRegex ]];
    then
        declare switchesString="$1";
        shift;

        # Try setting the switches
        if ! Options_switch -s "$switchesString";
        then
            Options_resultCodeSet 10;

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
        Options_resultCodeSet 22;

        return "$_Options_RC";
    fi

    declare -n Options_OutputVariableReference="$outputVariableReferenceName";
    Options_OutputVariableReference=();

    # Reset validations
    Options_validateValue -r;
    # Reset replacements
    Options_replaceValue -r;
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
            Options_replaceValue -a "$replacementRule" "$replacementValue";
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
                Options_resultCodeSet 26 "$(( initialOptionIndex - 1 ))";

                return "$_Options_RC";
            fi

            # If replacement expression duplicate
            if [[ "$expressionAddResult" == 3 ]];
            then
                # "Replacement expression duplicate"
                Options_resultCodeSet 25 "$(( initialOptionIndex - 1 ))";

                return "$_Options_RC";
            fi

            # "Invalid rule format"
            Options_resultCodeSet 27 "$(( initialOptionIndex - 1 ))";

            return "$_Options_RC";
        fi

        # If not validation nor replacement rule
        if [[ "${1:0:1}" != '/' ]];
        then
            continue;
        fi

        # Replacement
        # --------------------------------

        # If replacement rule
        if [[ "${1:0:2}" == '//' ]];
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
        Options_validateValue -a "$validationRule";
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
            Options_resultCodeSet 16 "$(( initialOptionIndex - 1 ))";

            return "$_Options_RC";
        fi

        # If validation expression duplicate
        if [[ "$expressionAddResult" == 3 ]];
        then
            # "Validation expression duplicate"
            Options_resultCodeSet 17 "$(( initialOptionIndex - 1 ))";

            return "$_Options_RC";
        fi

        # "Invalid rule format"
        Options_resultCodeSet 27 "$(( initialOptionIndex - 1 ))";

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
        Options_resultCodeSet 6 "$(( initialOptionIndex - 1 ))";

        return "$_Options_RC";
    fi

    # Store actual options (to be parsed)
    _Options_O=( "$@" );

    declare elements=( "${_Options_O[@]}" );
    declare doubleDashPosition; doubleDashPosition="$( Options_arrayFindElement '--' "$@" )"; # If "--" option exists return its position
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
            Options_resultCodeSet 28 "$patternIndex";

            return "$_Options_RC";
        fi

        # Store unsplit option patterns

        if [[ "$optionIsParameter" == 1 ]];
        then
            # echo "Added to _Options_UP: '$pattern'";
            _Options_UP+=( "$pattern" );
        else
            # echo "Added to _Options_UF: '$pattern'";
            _Options_UF+=( "$pattern" );
        fi

        # Store split option patterns

        declare patternVariants=''; # For array from loop
        IFS=':' read -ra patternVariants <<< "$pattern"; # Create an array with ":" delimiter

        # If pattern expects a value then add its element(s) to options' array else add its element(s) to flags' array
        if [[ "$optionIsParameter" == 1 ]];
        then
            # echo -n "Added to parameterPatterns: "; Options_printArray -- "${patternVariants[@]}"; echo;
            parameterPatterns+=( "${patternVariants[@]}" );
        else
            # echo -n "Added to flagPatterns: "; Options_printArray -- "${patternVariants[@]}"; echo;
            flagPatterns+=( "${patternVariants[@]}" );
        fi
    done

    # Store parsed patterns
    _Options_F=( "${flagPatterns[@]}" );
    _Options_P=( "${parameterPatterns[@]}" );

    # Processed initials

    # @debug
    Options_Debug -s 'processed_initials';

    # If pattern '--' exists
    if Options_arrayFindElement '-' '--' "${flagPatterns[@]}" "${parameterPatterns[@]}";
    then
        Options_resultCodeSet 13;

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
        Options_resultCodeSet 1;

        return "$_Options_RC";
    fi

    # If combined short options are allowed
    if Options_switch 8;
    then
        # Try splitting combined short options.

        declare elementsTemp=(); # Temporary array of split multiple options from one and other options
        declare nextElementIsValue=''; # If skip option because it's a value for previous option
        declare element=''; # For split loop when splitting multiple options from one
        declare elementIndex;

        # Loop through all elements(before "--", if exists)
        for (( elementIndex = 0; elementIndex < "${#elements[@]}"; elementIndex++ ));
        do
            element="${elements[$elementIndex]}";
            declare optionName="${element%%=*}"; # Get the possible option's name

            # If it's the value for the previous option
            if [[ "$nextElementIsValue" == 1 ]];
            then
                elementsTemp+=("$element"); # Add an option because it's a
                declare nextElementIsValue=0;

                continue;
            fi

            # If the option is an argument option
            if ! Options_arrayFindElement '-' "%${optionName}" "${parameterPatterns[@]}";
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
                    Options_resultCodeSet 21 "$elementIndex";

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
                    if [[ "$optionNameCharacter" != '-' ]] && Options_switch 16;
                    then
                        # Add the prefix to the option
                        declare optionNameCharacter="${_Options_optionShortCombinedPrefix}${optionNameCharacter}";
                    fi

                    # If the next character is '=' and combined short options with a leading '=' character and joined argument are allowed
                    if [[ "${optionNameDirty:$(( optionNameCharacterIndex + 1 )):1}" == '=' ]] && Options_switch 6;
                    then
                        # Add the option with the leading '=' and its argument
                        optionsSplit+=("${optionNameCharacter}${optionNameDirty:$(( optionNameCharacterIndex + 1 ))}");

                        break;
                    fi

                    # Add the short option
                    optionsSplit+=( "$optionNameCharacter" );

                    # If there's such short argument option
                    if Options_arrayFindElement '-' "%${optionNameCharacter}" "${parameterPatterns[@]}";
                    then
                        # If this is the last character
                        if [[ "${optionNameDirty:$(( optionNameCharacterIndex + 1 ))}" == '' ]];
                        then
                            # The next element is an argument
                            declare nextElementIsValue=1;

                            continue;
                        fi

                        # If options combined with values are allowed
                        if Options_switch 7;
                        then
                            # Add the option with everything joined as its argument
                            optionsSplit+=("${optionNameDirty:$(( optionNameCharacterIndex + 1 ))}");

                            break;
                        fi

                        # Encountered an option combined with its possible value
                        Options_resultCodeSet 11 "$elementIndex";

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
                declare nextElementIsValue=1;
            fi
        done

        # Add all split and other options to array of all options
        elements=( "${elementsTemp[@]}" );
    fi

    # Validate processed initials
    # --------------------------------

    # If too many validations
    if (( ${#_Options_validateExpressions[@]} > ${#_Options_P[@]} )) && ! Options_switch 13;
    then
        # Validation rule count overflow
        Options_resultCodeSet 18;

        return "$_Options_RC";
    fi

    # If too many replacement rules for argument options (parameters)
    if (( ${#_Options_replaceExpressions[@]} > ${#_Options_P[@]} ));
    then
        # "Replacement rule count overflow"
        Options_resultCodeSet 23;

        return "$_Options_RC";
    fi

    # Parse actual options
    # --------------------------------

    declare optionPlains=(); # An array for all plain values
    declare optionArguments=(); # An array for all option values
    unset Options_OutputVariableReferenceCountTemp;
    declare Options_OutputVariableReferenceCountTemp=(); # An array for all option presence counters

    # If already checked all elements in array (before "--", if exists; for force next pattern (if there were plain values after
    # last checked pattern and also all patterns were found)).
    declare checkedAllElements='';

    declare pattern; # For loop when looping through each pattern divided by ";" char
    declare patternIndex;

    # Loop through each pattern (Between ';')
    for (( patternIndex = 0; patternIndex < ${#_Options_U[@]}; patternIndex++ ));
    do
        # Set the option's presence counter to 0
        Options_OutputVariableReferenceCountTemp[patternIndex]=0;
    done

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
        declare optionPlainCount=0; # Current plain value's index
        declare nextElementIsValue=0; # If get value from next option inside loop
        declare skipToNextPattern=0; # If got value flag
        declare skipElement=0; # An element is a value is for previous option or not
        declare optionCount=0; # Option counter (e.g. two same option argument or flags provided)
        unset optionArgument; # Unset option's value
        declare element; # For loop
        declare elementIndex;

        # Loop through all elements(before "--", if exists)
        for (( elementIndex = 0; elementIndex < ${#elements[@]}; elementIndex++ ));
        do
            # If skip to the next option pattern and all elements were parsed
            if [[ "$skipToNextPattern" == 1 && "$checkedAllElements" == 1 ]];
            then
                break;
            fi

            declare element="${elements[$elementIndex]}";

            # If the previous element was an option which expects the current be a value for that option
            if [[ "$nextElementIsValue" == 1 ]];
            then
                # If the argument is prefixed with the '-' character and that's prohibited
                if [[ "${element:0:1}" == '-' ]] && ! Options_switch 11;
                then
                    Options_resultCodeSet 2 "$elementIndex";

                    return "$_Options_RC";
                fi

                # If skip to the next option pattern (a value has already been set and checked)
                if [[ "$skipToNextPattern" == 1 ]];
                then
                    break;
                fi

                declare optionArgument="$element"; # Set an actual value of the option
                declare optionCount=$((optionCount + 1));
                declare nextElementIsValue=0; # Tell the loop that value for the option was gathered

                # @todo Re-verify behavior
                # Tell the loop to not skip the next option (may happen when more than one option appears in the pattern, any option had a value and
                # another option told to skip the next option since they search in known option(s))
                declare skipElement=0;

                # If skip to the next pattern after the first argument occurrence
                if Options_switch 14;
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
                declare patternVariant="${patternVariants[patternVariantIndex]}";

                # If the pattern variant is empty
                if [[ "$patternVariant" == '' ]];
                then
                    Options_resultCodeSet 20 "$patternVariantIndex";

                    return "$_Options_RC";
                fi

                # If the pattern variant doesn't assume a general option or an argument-like option (no '-' prefix)
                if [[ "${patternVariant:0:1}" != '-' ]] && ! Options_switch 5;
                then
                    # "Encountered pattern not prefixed with '-'"
                    Options_resultCodeSet 5 "$patternVariantIndex";

                    return "$_Options_RC";
                fi

                case "$patternVariant" in
                    # i.e. '-a'
                    "$element")
                        # If pattern has "?" char at the start(which means that it requires next option be a value) then
                        # get value from next option else default value for flag
                        if [[ "$optionIsParameter" == 1 ]];
                        then
                            declare nextElementIsValue=1;
                        else
                            if [[ "$skipToNextPattern" == 1 ]]; # If skip to the next option pattern
                            then
                                break;
                            fi

                            # If it's the first flag occurrence
                            if [[ "${optionArgument-}" == '' ]];
                            then
                                declare optionArgument=1; # Set the flag's counter to 1
                            else
                                declare optionArgument="$(( optionArgument + 1 ))"; # Increase the flag's counter
                            fi

                            declare optionCount=$((optionCount + 1));

                            # If skip to the next pattern after the first flag occurrence
                            if Options_switch 15;
                            then
                                declare skipToNextPattern=1; # Skip to the next option pattern

                                break;
                            fi
                        fi
                    ;;

                    # i.e. '-a=[value]'
                    "${element%%=?*}")
                        declare optionName="${element%%=*}";

                        if ! Options_arrayFindElement '-' "%${optionName}" "${_Options_P[@]}"; # If option expects value
                        then
                            Options_resultCodeSet 7 "$elementIndex"; # Encountered a value for a flag

                            return "$_Options_RC";
                        fi

                        declare optionValueTemp="${element#*=}"; # A value of option(after "=" char)

                        # If the argument after the '=' character is prefixed with the '-' character and that's prohibited
                        if [[ "${optionValueTemp:0:1}" == '-' ]] && ! Options_switch 12;
                        then
                            Options_resultCodeSet 9 "$elementIndex"; # Encountered a value prefixed with the '-' character after '=' character

                            return "$_Options_RC";
                        fi

                        if [[ "$skipToNextPattern" == 1 ]]; # If skip to the next option pattern
                        then
                            break;
                        fi

                        declare optionArgument="$optionValueTemp"; # Set an actual value of the option
                        declare optionCount=$((optionCount + 1));

                        # If skip to next pattern after the first argument occurrence
                        if Options_switch 14;
                        then
                            declare skipToNextPattern=1; # Skip to the next option pattern

                            break;
                        fi
                    ;;

                    # i.e. '-a=[empty]'
                    "${element%%=}")

                        declare optionName="${element%%=}";

                        # If such option exists in pattern(s) and expects a value
                        if ! Options_arrayFindElement '-' "%${optionName}" "${_Options_P[@]}";
                        then
                            Options_resultCodeSet 12 "$elementIndex"; # Encountered an empty value for a flag

                            return "$_Options_RC";
                        fi

                        declare optionArgument=''; # Set an actual value of the option
                        declare optionCount=$((optionCount + 1));
                    ;;

                    # If it's plain value or it's not related to the currently processed pattern
                    *)
                        # Get the name of the option(before "=" char or whole)
                        declare optionName="${element%%=*}";

                        # If the element is a supported option
                        if Options_arrayFindElement '-' "%${optionName}" "${_Options_P[@]}";
                        then
                            # If the option assumes the next element to be its value
                            if [[ "${element:${#optionName}:1}" != '=' ]];
                            then
                                # Skip the next iteration
                                declare skipElement=1;
                            fi
                        elif ! Options_arrayFindElement '-' "%${optionName}" "${_Options_F[@]}"; # If the element is not a supported flag
                        then
                            # If it's an unsupported/unknown option and option-like arguments are not allowed
                            if [[ "${element:0:1}" == '-' ]] && ! Options_switch 4;
                            then
                                # Unknown option
                                Options_resultCodeSet 4 "$elementIndex";

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
            fi
        done

        # Parsed an element

        # If the argument was set (an argument or flag)
        if [[ "${optionArgument+s}" != '' ]];
        then
            # # If it's an argument option (i.e. property value)
            # if [[ "$optionIsParameter" == 1 ]];
            # then
            # Try validating the value by index
            if ! Options_validateValue -v "$patternIndex" "$optionArgument";
            then
                # "Invalid argument"
                Options_resultCodeSet 19 "$patternIndex";

                return "$_Options_RC";
            fi

            declare Options_replacementTemp;

            # Try replacing the value
            if Options_replaceValue -v Options_replacementTemp "$patternIndex" "$optionArgument";
            then
                declare optionArgument="$Options_replacementTemp";
            fi

            unset Options_replacementTemp;
            # fi

            # If the argument is not empty or it's a flag (starts with 1)
            if [[ "$optionArgument" != '' ]];
            then
                # Add the value to the result array
                optionArguments+=( "$optionArgument" );
            else
                # Argument (i.e. option property value) is empty (even after replacement).

                # @todo Reconsider the behavior when both empty values are prohibited and a value gets replaced to an empty.

                # If empty arguments are prohibited
                if ! Options_switch 9;
                then
                    Options_resultCodeSet 3 "$patternIndex"; # Encountered an empty argument

                    return "$_Options_RC";
                fi

                optionArguments+=( "$_Options_argumentValueDefault" );
            fi

            # Set/increase option presence counter (flag's value is its count in general)

            # If option counter already has value
            if [[ "${Options_OutputVariableReferenceCountTemp[$patternIndex]}" != 0 ]];
            then
                Options_OutputVariableReferenceCountTemp[patternIndex]="$((${Options_OutputVariableReferenceCountTemp[$patternIndex]} + 1))";
            else
                Options_OutputVariableReferenceCountTemp[patternIndex]="$optionCount";
            fi
        else
            # No argument nor flag was provided for the option (unset)

            # If the option is important/required
            if [[ "$optionIsRequired" == 1 ]];
            then
                # "Required option not found"
                Options_resultCodeSet 15 "$patternIndex";

                return "$_Options_RC";
            fi
            
            # Try validating the unset parameter or default flag value
            if ! Options_validateValue -v "$patternIndex";
            then
                echo 'Invalid argument: '"${patternIndex}: '${optionIsRequired}'";
                # "Invalid argument"
                Options_resultCodeSet 19 "$patternIndex";

                return "$_Options_RC";
            fi

            # Try replacing the unset parameter or default flag value

            declare Options_replacementTemp;

            # If replaced argument or flag
            if Options_replaceValue -v Options_replacementTemp "$patternIndex";
            then
                # Add the replaced value
                optionArguments+=( "$Options_replacementTemp" );
            else
                # If it's a flag
                if [[ "$optionIsParameter" == 0 ]];
                then
                    # Add the default flag value
                    optionArguments+=( "$_Options_flagValueDefault" );
                else
                    # Add the defalut argument value
                    optionArguments+=( "$_Options_argumentValueDefault" );
                fi
            fi

            unset Options_replacementTemp;
            # unset commandArgs;
        fi

        # An argument was not declared
        if [[ "$nextElementIsValue" == 1 ]];
        then
            # "Argument not found"
            Options_resultCodeSet 8 "$patternIndex";

            return "$_Options_RC";
        fi

        # Tell that the loop has already iterated through all elements (What is that ?)
        if [[ "$checkedAllElements" != 1 ]];
        then
            checkedAllElements=1;
        fi
    done

    # Successful parsing; Save a result to a variable(firstly, option(s)' and flag(s)' values and, secondly, plain value(s)) and,
    # finally, everything after "--" option.

    unset Options_OutputVariableReferenceTemp;
    declare Options_OutputVariableReferenceTemp=( "${optionArguments[@]}" "${optionPlains[@]}" "${valuesAdditional[@]}" );

    # @todo Consider validating plain and additional values

    # Set the result global variable
    # shellcheck disable=SC2034
    Options_OutputVariableReference=( "${Options_OutputVariableReferenceTemp[@]}" );

    # Set the option count global variable
    if Options_switch 2 || Options_switch 3;
    then
        # In case an output variable has the same name as the reference (else, may interfere)
        if
            Options_switch 2 && [[ "$outputVariableReferenceName" == 'Options_OutputVariableReferenceC' ]] ||
            Options_switch 3 && [[ "$outputVariableReferenceName" == 'Options_OutputVariableReferenceC' ]] ||
            [[ "$outputVariableReferenceName" == 'Options_OutputVariableReferenceCountTotalTemp' ]];
        then
            Options_resultCodeSet 22;

            return "$_Options_RC";
        fi

        if Options_switch 2;
        then
            declare -n Options_OutputVariableReferenceC="${outputVariableReferenceName}C";
            # shellcheck disable=SC2034
            Options_OutputVariableReferenceC=( "${Options_OutputVariableReferenceCountTemp[@]}" );
        fi

        if Options_switch 3;
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

    Options_resultCodeSet 0; # Successfully parsed

    # @debug
    Options_Debug -f -- 'result' "$outputVariableReferenceName" "${Options_OutputVariableReference[@]}";

    return "$_Options_RC";
}
