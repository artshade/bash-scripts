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

declare _UI_sourceFilepath; _UI_sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )"; readonly _UI_sourceFilepath;
declare _UI_sourceDirpath; _UI_sourceDirpath="$( dirname -- "$_UI_sourceFilepath" 2> '/dev/null'; )"; readonly _UI_sourceDirpath;

[[ ! -f "$_UI_sourceFilepath" || ! -d "$_UI_sourceDirpath" ]] && exit 99;

# Libraries
# ----------------------------------------------------------------

export SHELL_LIBS_DIRPATH="$_UI_sourceDirpath"; [[ -d "$SHELL_LIBS_DIRPATH" ]] || exit 98;

# shellcheck disable=SC1091
[[ "${SHELL_LIB_OPTIONS:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/options.lib.sh" && [[ "${SHELL_LIB_OPTIONS:+s}" != '' ]] || exit 97; };
# shellcheck disable=SC1091
[[ "${SHELL_LIB_MISC:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/misc.lib.sh" && [[ "${SHELL_LIB_MISC:+s}" != '' ]] || exit 97; };
# shellcheck disable=SC1091
[[ "${SHELL_LIB_SHELL:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/shell.lib.sh" && [[ "${SHELL_LIB_SHELL:+s}" != '' ]] || exit 97; };

# shellcheck disable=SC2034
declare -r SHELL_LIB_UI="$_UI_sourceFilepath";

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Variables (Private)
# ----------------------------------------------------------------
# Arrays
# --------------------------------

declare _UI_PrintF_record=();

# Strings
# --------------------------------

declare _UI_PrintF_padding='';

# Functions
# ----------------------------------------------------------------

UI_SetPadding() {
    declare padding="${1:-}";
    shift || true;

    if
        [[ "${#padding}" != '0' ]] &&
        ! Misc_Regex -s '^(?:0|[1-9][0-9]*)?(?:\:(?:0|[1-9][0-9]*))?$' -- "$padding";
    then
        printf -- $'Invalid print format padding: \'%s\'\n' "$padding";

        return 1;
    fi

    _UI_PrintF_padding="$padding";

    return 0;
}

UI_PrintTable()
{
    # Options
    # --------------------------------

    declare args; Options args \
        '/0/^(?:0|[1-9][0-9]*)$' \
        '!?-c;?-n' \
        "$@" \
    || return $?;

    declare __columnCount="${args[0]}";
    declare __columnNoName="${args[1]}";
    declare __items=( "${args[@]:2}" );
    unset args;

    # ----------------

    if [[ "$__columnNoName" == '' ]];
    then
        declare __columnNoName='No';
    fi

    # Main
    # --------------------------------

    # To reset in the local scope
    declare _UI_PrintF_padding='';

    gapLength=2; # Gaps between brackets. For example: [ value ] - 2 spaces.
    declare columns=( "${__items[@]:0:$__columnCount}" ); # Must not include column "No"
    declare values=( "${__items[@]:$__columnCount}" );

    # If too few items
    if (( ${#values[@]} % ${#columns[@]} > 0 ));
    then
        declare itemIndex;

        for (( itemIndex = 0; itemIndex < ${#values[@]} % ${#columns[@]}; itemIndex++ ));
        do
            values+=('');
        done
    fi

    # Maximum value lengths
    # Assuming Header length >= Gap
    # Header length: Value length + Gap >= Header length (since headers are static + printf format should adjust in case V+G is shorter)

    declare columnNoLengthMax="$(( ${#values[@]} / ${#columns[@]} ))";
    declare columnNoLengthMax="${#columnNoLengthMax}";
    declare columnsRowFormat="   %$((columnNoLengthMax + gapLength))s"; # Initial + column "No"
    declare valueLengthsMax=();
    declare columnIndex;

    # Each column
    for (( columnIndex = 0; columnIndex < ${#columns[@]}; columnIndex++ ));
    do
        declare valueIndexStart;
        valueLengthsMax[columnIndex]=0;

        # Each value in the column
        for (( valueIndexStart = 0; valueIndexStart < ${#values[@]}; valueIndexStart += ${#columns[@]} ));
        do
            declare value="${values[$(( valueIndexStart + columnIndex ))]}";
            # declare value="${value//$'\n'}";
            (( valueLengthsMax[columnIndex] < ${#value} )) && valueLengthsMax[columnIndex]="${#value}";
        done

        columnsRowFormat+="     %-$(( valueLengthsMax[columnIndex] + gapLength ))s";
    done

    UI_PrintF -nf "$columnsRowFormat" -- "$__columnNoName" "${columns[@]}";

    # Column and value row lengths
    # Value length: Value length + Gap < Header length ? Header length : Value length + Gap
    # declare columnNoWidth="$( diff=$(( columnNoLengthMax - 5 )); printf '%s' "$(( 5 - ${diff/-*/0} ))"; )";

    declare columnNoWidth="$(( ${#__columnNoName} - gapLength ))";
    (( columnNoLengthMax + gapLength > ${#__columnNoName} )) && declare columnNoWidth="$columnNoLengthMax";
    declare rowIndex;

    # Each row
    for (( rowIndex = 0; rowIndex < $(( ${#values[@]} / ${#columns[@]} )); rowIndex++ ));
    do
        declare rowFormat="  [ %${columnNoWidth}s ]"; # Initial + column "No"
        declare columnIndex;

        # Each column
        for (( columnIndex = 0; columnIndex < ${#columns[@]}; columnIndex++ ));
        do
            declare value="${values[$(( rowIndex * ${#columns[@]} + columnIndex ))]}";
            # declare value="${value//$'\n'}";
            declare columnWidth="$(( ${#columns[columnIndex]} - gapLength ))";
            (( valueLengthsMax[columnIndex] + gapLength > ${#columns[columnIndex]})) && declare columnWidth="${valueLengthsMax[$columnIndex]}";
            rowFormat+=" - [ %-${columnWidth}s ]";
        done

        UI_PrintF -nf "$rowFormat" -- "$(( rowIndex + 1 ))" "${values[@]:$((rowIndex * ${#columns[@]})):${#columns[@]}}";
    done
}

# Repeated formatted data output
UI_PrintR()
{
    # Options
    # --------------------------------

    declare args; Options args \
        '/0/^(?:0|[1-9][0-9]*)$' \
        '?-c;?-f;-n;-e;-s' \
        "$@" \
    || return $?;

    declare __count="${args[0]}";
    declare __format="${args[1]}";
    declare __newLine="${args[2]}";
    declare __newLineEnd="${args[3]}";
    declare __newLineStart="${args[4]}";
    declare __data=( "${args[@]:5}" );
    unset args;

    # ----------------

    if [[ "$__count" == '' ]];
    then
        declare __count=0;
    fi

    if [[ "$__format" == '' ]];
    then
        declare __format='%s';
    fi

    # Main
    # --------------------------------

    declare repeatStep;

    for (( repeatStep = 0; repeatStep < __newLine; repeatStep++ ));
    do
        declare __format="$__format"$'\n';
    done

    for (( repeatStep = 0; repeatStep < __newLineStart; repeatStep++ ));
    do
        printf '\n';
    done

    for (( repeatStep = 0; repeatStep < __count; repeatStep++ ));
    do
        # shellcheck disable=SC2059
        printf -- "$__format" "${__data[@]}";
    done

    for (( repeatStep = 0; repeatStep < __newLineEnd; repeatStep++ ));
    do
        printf '\n';
    done
}

# TODO: Add verbosity level
# TODO: Add colors/meta
UI_PrintF()
{
    # Options
    # --------------------------------

    declare args argsT; Options args '101' \
        '//0?' '%s' \
        '//4?' '1' \
        '//5?' "$_UI_PrintF_padding" \
        '/4/^(?:0|[1-9][0-9]*)$' \
        '/5?/^(?:0|[1-9][0-9]*)?\:?(?:0|[1-9][0-9]*)$' \
        '?-f;?-t;?-F;?-P;?-r;?-p;-n;-c;--forget;--restore' \
        "$@" \
    || return $?;

    declare __messageFormat="${args[0]}"; # -f
    declare __prefixTemplate="${args[1]}"; # -t
    declare __prefixString="${args[2]}"; # -F
    declare __postfixString="${args[3]}"; # -P
    declare __repeatCount="${args[4]}"; # -r
    declare __padding="${args[5]}"; # -p
    declare __newLine="${args[6]}"; # -n
    declare __clear="${args[7]}"; # -c
    declare __forget="${args[8]}"; # --forget
    declare __restore="${args[9]}"; # --restore
    declare __data=( "${args[@]:10}" );
    unset args;

    # ----------------

    # If no options were provided
    if (( argsT == 0 && ${#__data[@]} == 0 ));
    then
        # Add a single new line
        declare __newLine=1;
    fi

    unset argsT;

    # Main
    # --------------------------------

    if [[ "$__restore" != 0 ]];
    then
        if [[ ${#_UI_PrintF_record[@]} == 0 ]];
        then
            return 1;
        fi

        printf '%s' "${_UI_PrintF_record[0]}";

        if [[ "$__forget" != 0 ]];
        then
            _UI_PrintF_record=();
        fi

        return 0;
    fi

    declare prefix="$__prefixString";

    if [[ "$prefix" == '' ]];
    then
        case "$__prefixTemplate"
        in
            '0'|'n'|'none'|'default'    ) declare prefix='[   ] ';;
            '1'|'m'|'meta'              ) declare prefix='[ # ] ';;
            '2'|'q'|'question'          ) declare prefix='[ ? ] ';;
            '3'|'i'|'info'|'information') declare prefix='[ * ] ';;
            '4'|'s'|'success'           ) declare prefix='[ + ] ';;
            '5'|'w'|'warning'           ) declare prefix='[ ! ] ';;
            '6'|'e'|'error'             ) declare prefix='[ - ] ';;
            '7'|'f'|'fatal'             ) declare prefix='[ x ] ';;
            '8'|'d'|'debug'             ) declare prefix='[ D ] ';;
        esac
    fi

    # Padding (top[:left] or :left)
    # ----------------

    declare paddingTop="${__padding%%\:*}";
    declare paddingLeft='';

    if [[ "$__padding" =~ \: ]];
    then
        declare paddingLeft="${__padding##*\:}";
    fi

    if [[ "$paddingTop" == '' ]];
    then
        declare paddingTop=0;
    fi

    if [[ "$paddingLeft" == '' ]];
    then
        declare paddingLeft=0;
    fi

    declare paddingLeftCharacter=' ';
    declare prefixFormat='%s';
    declare padding;

    for (( padding = 0; padding < paddingLeft; padding++ ));
    do
        declare prefixFormat="${paddingLeftCharacter}${prefixFormat}";
    done

    for (( padding = 0; padding < paddingTop; padding++ ));
    do
        declare prefixFormat="\n${prefixFormat}";
    done

    declare postfixFormat='%s';
    declare newLineIndex;

    for (( newLineIndex = 0; newLineIndex < __newLine; newLineIndex++ ));
    do
        declare postfixFormat="${postfixFormat}\n";
    done

    # Print
    # ----------------

    if (( __clear > 0 ));
    then
        clear;
    fi

    declare repeat;

    declare output; output="$(
        for (( repeat = 0; repeat < __repeatCount; repeat++ ));
        do
            # shellcheck disable=SC2059
            printf -- "$prefixFormat" "$prefix";
            # shellcheck disable=SC2059
            printf -- "$__messageFormat" "${__data[@]}";
            # shellcheck disable=SC2059
            printf -- "$postfixFormat" "$__postfixString";
        done

        printf ' ';
    )";

    declare output="${output%?}";
    printf '%s' "$output";
    _UI_PrintF_record=();

    if [[ "$__forget" == 0 ]];
    then
        _UI_PrintF_record=( "$output" );
    fi

    return 0;
}

# @todo Consider how to print a default value on empty-"Cancel" by "Enter" key on the same line as the prompt.
#   Use termina cursor save/restore features (what if the screen scrolled?)? Somehow reliably backspace/remove the added new line?
UI_PromptF()
{
    # Options
    # --------------------------------

    declare args argsC; Options args '11' \
        '/3/^(?:0|[1-9][0-9]*)$' \
        '/4/^(?:0|[1-9][0-9]*)$' \
        '/9?/^(?:0|[1-9][0-9]*)?\:?(?:0|[1-9][0-9]*)$' \
        '!?-o;?-v;?-d;?-l;?-T;?-f;?-t;?-F;?-P;?-p;?-e;-n;-L;-i;-s;-q;-D' \
        "$@" \
    || return $?;

    declare __outputReference="${args[0]}"; # -o
    declare __inputPattern="${args[1]}"; # -v
    declare __defaultInputValue="${args[2]}"; # -d
    declare __length="${args[3]}"; # -l
    declare __timeout="${args[4]}"; # -T
    declare __messageFormat="${args[5]}"; # -f
    declare __prefixTemplate="${args[6]}"; # -t
    declare __prefixString="${args[7]}"; # -F
    declare __postfixEndingString="${args[8]}"; # -P
    declare __padding="${args[9]}"; # -p
    declare __explanation="${args[10]}"; # -e
    declare __newLine="${args[11]}"; # -n
    declare __lowercase="${args[12]}"; # -L
    declare __ignoreInvalidDefault="${args[13]}"; # -i
    declare __isSecret="${args[14]}"; # -s
    declare __disableMessage="${args[15]}"; # -q
    declare __disableInputDefaultPreview="${args[16]}"; # -D
    declare __message=( "${args[@]:17}" );
    unset args;

    # ----------------

    if [[
        "$__outputReference" == 'UI_PromptF_outputVariableReference' ||
        "$__outputReference" == 'UI_PromptF_outputVariableReferenceCancelled'
    ]];
    then
        UI_PrintF -n -- '[UI_PromptF] Output variable reference interference';

        return 100;
    fi

    declare -n UI_PromptF_outputVariableReference="$__outputReference";
    declare -n UI_PromptF_outputVariableReferenceCancelled="${__outputReference}Cancelled";
    UI_PromptF_outputVariableReference='';
    UI_PromptF_outputVariableReferenceCancelled=0;

    if [[ "$__messageFormat" == '' ]];
    then
        declare __messageFormat='%s';
    fi

    if [[ "${argsC[6]}" == 0 ]];
    then
        declare __prefixTemplate='q';
    fi

    if [[ "${argsC[8]}" == 0 ]];
    then
        declare __postfixEndingString=': ';
    fi

    declare defaultIsSet=0;

    if (( argsC[2] > 0 ))
    then
        declare defaultIsSet=1;
    fi

    unset argsC;

    # Main
    # --------------------------------
    # Message
    # ----------------

    declare postfixString='';

    if [[ "$__disableMessage" == 0 ]];
    then
        if [[ "$__explanation" != '' ]];
        then
            declare postfixString; postfixString+="$( printf ' %s' "$__explanation"; )";
        fi

        if [[ "$defaultIsSet" != 0 && "$__disableInputDefaultPreview" == 0 ]];
        then
            declare postfixString; postfixString+="$( printf -- $' (\'%s\')' "${__defaultInputValue-}"; )";
        fi

        if [[ "$__timeout" != '' ]];
        then
            declare postfixString; postfixString+="$( printf --  $' {%ss}' "$__timeout"; )";
        fi

        declare postfixString; postfixString+="$__postfixEndingString";
    fi

    # Input read
    # ----------------

    declare argsMessageTemp; readarray -t argsMessageTemp < <( R -c "$__newLine" -- ' -n ' );
    declare argsReadTemp=();

    if [[ "$__length" != '' ]];
    then
        argsReadTemp+=( '-n' "$__length" );
    fi

    if [[ "$__timeout" != '' ]];
    then
        argsReadTemp+=( '-t' "$__timeout" );
    fi

    if (( __isSecret > 0 ));
    then
        argsReadTemp+=( '-s' );
    fi

    declare emptyInputCountMax=2;
    declare emptyInputCount=0;
    declare inputCancelled=0;
    declare inputDefaultSet=0;
    declare timedout=0;
    unset inputData;
    declare inputData;

    # If not reached manual cancelling
    while (( emptyInputCount < emptyInputCountMax ));
    do
        if [[ "$__disableMessage" == 0 ]];
        then
            UI_PrintF -f "$__messageFormat" -t "$__prefixTemplate" -F "$__prefixString" -P "$postfixString" -p "$__padding" "${argsMessageTemp[@]}" -- "${__message[@]}";
        fi

        declare UI_PromptF_shellOptionsTemp;
        Shell_Options -sro UI_PromptF_shellOptionsTemp;
        set +e;

        # @note "read" sets variable
        IFS= read "${argsReadTemp[@]}" -r -- inputData;

        declare returnCode=$?;
        Shell_Options -lf "$UI_PromptF_shellOptionsTemp";
        unset UI_PromptF_shellOptionsTemp;

        # If not submitted (e.g. cancelled, timed out)
        if [[ "$returnCode" != 0 ]];
        then
            unset inputData;
            declare inputData;

            # If cancelled explicitly (e.g. "Ctrl+D" in some environments) or for unsupported reason
            if [[ "$returnCode" != 142 || "$__timeout" == '' ]];
            then
                declare inputCancelled=1;
                UI_PrintF -n;

                break;
            fi

            # Timed out (code 142)

            declare timedout=1;

            # If default is set
            if [[ "$defaultIsSet" != 0 ]];
            then
                # Set value to default (empty or not).
                declare inputDefaultSet=1;
                declare inputData="$__defaultInputValue";
                UI_PrintF -n -- "$inputData";
            else
                UI_PrintF;
            fi

            UI_PrintF -nf '  [ ! ] Input timed out after %ss' -- "$__timeout";

            # Cancel further input (timed out)

            break;
        fi

        # If input value is not empty
        if [[ "${inputData:+s}" != '' ]];
        then
            declare emptyInputCount=0;

            if
                # If no validation is available
                [[ "$__inputPattern" == '' ]] ||
                # ...or value does pass the validation
                Misc_Regex -s "$__inputPattern" -- "$inputData";
            then
                # Cancel further input (got the value)

                break;
            fi

            # Value does not pass validation

            # shellcheck disable=SC2207
            declare commandArgs=( $( [[ "$__length" != '' && "$inputDefaultSet" == 0 || "$__isSecret" != 0 ]] && printf -- '-p 1'; ) );
            UI_PrintF -n "${commandArgs[@]}" -- '  [ - ] Invalid input';

            # Try prompting again

            continue;
        fi

        unset inputData;
        declare inputData;

        # Input value is empty (cancel attempt).

        # If default value is set
        if [[ "$defaultIsSet" != 0 ]];
        then
            # Set to default value (empty or not)
            declare inputDefaultSet=2;
            declare inputData="$__defaultInputValue";

            # Cancel further input (got cancelled default value)

            break;
        fi

        # Empty input (no default)

        # Increment cancel attempt count
        declare emptyInputCount="$(( emptyInputCount + 1 ))";

        # If it's the first attempt (i.e. very first or after invalid input)
        if [[ "$emptyInputCount" == 1 ]];
        then
            # shellcheck disable=SC2207
            declare commandArgs=( $( (( __isSecret > 0 )) && printf -- '-p 1'; ) );

            UI_PrintF -n "${commandArgs[@]}" \
                -f '  [ * ] %s more empty input to cancel input' -- "$(( emptyInputCountMax - 1 ))";

            continue;
        fi

        # If reached cancelling
        if (( emptyInputCount >= emptyInputCountMax ));
        then
            declare inputCancelled=2;

            break;
        fi

        # Try prompting again
    done

    UI_PrintF --forget;

    if [[ "$__length" != '' && "$inputDefaultSet" == 0 && "$timedout" == 0 ]];
    then
        UI_PrintF -n;
    fi

    # If any value is available (valid custom or any default, including empty)
    if [[ "${inputData+s}" != '' ]];
    then
        #  If convert to lowercase
        if (( __lowercase > 0 ));
        then
            declare inputData="${inputData,,}";
        fi

        # shellcheck disable=SC2034
        UI_PromptF_outputVariableReference="$inputData";

        # State whether the prompt was cancelled and set to "default" or not.
        # shellcheck disable=SC2034
        UI_PromptF_outputVariableReferenceCancelled="$inputCancelled";

        if (( __isSecret > 0 ));
        then
            UI_PrintF;
        fi

        return 0;
    fi

    # If cancelled on "read"
    if [[ "$inputCancelled" == 1 ]];
    then
        # shellcheck disable=SC2207
        # declare commandArgs=( $( [[ "$__isSecret" != 0 ]] && printf -- '-p 1'; ) );
        # UI_PrintF -n "${commandArgs[@]}" -- '  [ ! ] Input cancelled';
        UI_PrintF -n -- '  [ ! ] Input cancelled';

        return 1;
    fi

    # Cancelled for any other reason (e.g. empty input values).

    # shellcheck disable=SC2207
    declare commandArgs=( $( (( __isSecret > 0 )) && printf -- '-p 1'; ) );
    UI_PrintF -n "${commandArgs[@]}" -- '  [ ! ] Input manually cancelled';

    return 1;
}

UI_PromptYesNo()
{
    # Options
    # --------------------------------

    declare args argsC; Options args '11' \
        '/1/^(?:0|[1-9][0-9]*)$' \
        '/5/^(?:0|[1-9][0-9]*)?\:?(?:0|[1-9][0-9]*)$' \
        '//5?' :2 \
        '?-f;?-T;?-t;?-F;?-P;?-p;-y;-m' \
        "$@" \
    || return $?;

    declare __messageFormat="${args[0]}"; # -f
    declare __timeout="${args[1]}"; # -T
    declare __prefixTemplate="${args[2]}"; # -t
    declare __prefixString="${args[3]}"; # -F
    declare __postfixEndingString="${args[4]}"; # -P
    declare __padding="${args[5]}"; # -p
    declare __defaultYes="${args[6]}"; # -y
    declare __manual="${args[7]}"; # -m
    declare __message=( "${args[@]:8}" );
    unset args;

    # ----------------

    if [[ ${#__message[@]} == 0 ]];
    then
        declare __message=( 'Are you sure?' );
    fi

    # Main
    # --------------------------------

    declare commandArgs=();

    if [[ "${argsC[2]}" != 0 ]];
    then
        commandArgs+=( '-t' "$__prefixTemplate" );
    fi

    if [[ "${argsC[3]}" != 0 ]];
    then
        commandArgs+=( '-F' "$__prefixString" );
    fi

    if [[ "${argsC[4]}" != 0 ]];
    then
        commandArgs+=( '-P' "$__postfixEndingString" );
    fi

    if [[ "$__timeout" != '' ]];
    then
        commandArgs+=( '-T' "$__timeout" );
    fi

    if [[ "$__manual" == 0 ]];
    then
        commandArgs+=( '-l' 1 );
    fi

    declare UI_PromptYesNo_prompt='';

    if
        ! UI_PromptF -o UI_PromptYesNo_prompt \
            -d "$( [[ "$__defaultYes" != 0 ]] && printf 'y' || printf 'n'; )" \
            -v '^[YyNn]$' -e '[YyNn]' \
            -p "$__padding" -f "$__messageFormat" \
            "${commandArgs[@]}" -- \
                "${__message[@]}";
    then
        return 1;
    fi

    declare prompt="$UI_PromptYesNo_prompt";
    unset UI_PromptYesNo_prompt;
    unset commandArgs;

    if [[ "$prompt" =~ ^[Yy]$ ]];
    then
        return 0;
    fi

    return 1;
}

UI_GapPrint()
{
    # Options
    # --------------------------------

    declare args; Options args \
        '-s' \
        "$@" \
    || return $?;

    declare __strict="${args[0]}";
    unset args;

    # Main
    # --------------------------------

    declare restored; restored="$( UI_PrintF --restore; printf '.'; )";
    declare restored="${restored%?}";

    if
        ( (( __strict > 0 )) && [[ "$restored" != $'\n' ]] ) ||
        ( (( __strict == 0 )) && ! printf '%s' "$restored" | tail -c 1 | read -r );
    then
        UI_PrintF -n;
    fi
}

# Aliases
# ----------------------------------------------------------------
# Related: SC2262, SC2263

if [[ "${SHELL_LIB_UI_ALIAS-}" != 1 ]];
then
    O()
    {
        UI_PrintF "$@";
    }

    P()
    {
        UI_PromptF "$@";
    }

    YN()
    {
        UI_PromptYesNo "$@";
    }

    R()
    {
        UI_PrintR "$@";
    }
fi

# ----------------------------------------------------------------
# ----------------------------------------------------------------
# ----------------------------------------------------------------
# DEPRECATED
# ----------------------------------------------------------------
# ----------------------------------------------------------------
# ----------------------------------------------------------------

declare -r Misc_OutputStreamStdDefault=1;
declare -r Misc_OutputStreamErrDefault=2;
declare -r Misc_PrintF_SubshellLevelMaxDefault=1;

# shellcheck disable=SC2034
{
    declare -r clBlack='\033[0;30m';
    declare -r clRed='\033[0;31m';
    declare -r clGreen='\033[0;32m';
    declare -r clOrange='\033[0;33m';
    declare -r clBlue='\033[0;34m';
    declare -r clPurple='\033[0;35m';
    declare -r clCyan='\033[0;36m';
    declare -r clLightGray='\033[0;37m'; # "\033[38;2;99;99;99m";
    declare -r clGray='\033[1;30m';
    declare -r clLightRed='\033[1;31m';
    declare -r clLightGreen='\033[1;32m';
    declare -r clYellow='\033[1;33m';
    declare -r clLightBlue='\033[1;34m';
    declare -r clLightPurple='\033[1;35m';
    declare -r clLightCyan='\033[1;36m';
    declare -r clWhite='\033[1;37m';
    declare -r clDefault='\033[0m';
}

# shellcheck disable=SC2034
declare -rA Misc_colorsTheme_default=(
    ['clDefault']="$clDefault"
    ['clWhite']='#ffffff'
    ['clBlack']='#000000'
    ['clRed']='#F12E2E'
    ['clGreen']='#00ff00'
    ['clBlue']='#6648EC'
    ['clBlue2']='#11afec'
    ['clYellow']='#F0D54F' # '#ffff00'
    ['clGray']='#777777'
    ['clLightGray']='#888888'
    ['clLightRed']='#ec5555'
    ['clLightGreen']='#4de37d'
    ['clLightBlue']='#98c1d9'
    ['clLightBlue2']='#59acc6'
    ['clLightPink']='#e54cbd'
    ['clLightCyan']='#11ecec'
    ['clLightOrange']='#F09A4F'
    ['clDarkGray']='#555555'
    ['clDarkCyan']='#64a495'
    ['clLogo']='#31454c' # '#495356' # '#4f5456' # '#A9E4E4'
);

# shellcheck disable=SC2034
declare -rA Misc_colorsTheme_white=(
    ['clDefault']="$clDefault"
    ['clWhite']='#000000'
    ['clBlack']='#ffffff'
    ['clRed']='#BB1D1D'
    ['clGreen']='#1F8C62'
    ['clBlue']='#435AAC'
    ['clBlue2']='#6177C4'
    ['clYellow']='#D5AA36' # '#BF9930' # '#B3AE25'
    ['clGray']='#696969'
    ['clLightGray']='#aaaaaa'
    ['clLightRed']='#ec5555'
    ['clLightGreen']='#449A79'
    ['clLightBlue']='#5695BB'
    ['clLightBlue2']='#5F989A'
    ['clLightPink']='#e54cbd'
    ['clLightCyan']='#48B4BA'
    ['clLightOrange']='#ae7e32' # '#C28D38'
    ['clDarkGray']='#BBBBBB'
    ['clDarkCyan']='#348C89'
    ['clLogo']='#e5ecee' # '#d6dfe2' # '#d3dcdf' # '#c3d2d7' # 93ADBF
);

declare -r Misc_PrintF_OutputStreamsDefault=(
    '/dev/stdin'
    '/dev/stdout'
    '/dev/stderr'
)

# 5 ~ debug, 4 ~ success, 3 ~ warning, 2 - error, 1 - fatal, 0 ~ silent
declare Misc_VerbosityLevel=4;
declare Misc_VerbosityTimestamp=1;
declare Misc_DumpPath='/dev/null';

# Theme

declare -A Misc_ColorsTheme;
declare -n Misc_colorsTheme="Misc_colorsTheme_${_Main_ColorTheme:-default}";

for colorName in "${!Misc_colorsTheme[@]}";
do
    Misc_ColorsTheme["$colorName"]="${Misc_colorsTheme[$colorName]}";
done

# Description: The general output function
#
# Options:
#   -v (parameter) - Verbosity level (0-5)
#   -t (parameter) - Text type (n, m, q, i, s, w, e, f, d)
#   -f (parameter) - Text format
#   -d (parameter) - Descriptor (0-2)
#   -p (parameter) - Text padding (top[, left] or ,left)
#   -r (parameter) - Repeat count
#   -o (parameter) - Output variable reference
#   -n (multi-flag) - New line
#   -m (flag) - Enable text meta
#    * - Text
#
# Returns:
#   0 ~ Successful output
#   1 ~ Too low verbosity level
#   100 ~ Output variable reference interference
#   200 ~ Invalid options
#
# Outputs:
#   1. Prints: A pre-formatted and colored text
#   2. Output reference variable: A pre-formatted and colored text
#
UI_D_PrintF()
{
    ###########
    # Options #
    ###########

    # '@3/^(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/' \
    declare args; Options args \
        '/0/^[0-2]$' \
        '/1/^-?[0-5]$' \
        '/2/^[nmqiswefd]$' \
        '/4/^[0-9]*\,?[0-9]+$' \
        '/5/^-?[0-9]+$' \
        '/9/^[0-1]$' \
        '?-d;?-v;?-t;?-f;?-p;?-r;?-s;?-o;-n;-m;-M;-T;-c;-e' \
        "$@" \
    || return $?;

    declare descriptor="${args[0]}";
    declare verbosityLevel="${args[1]}";
    declare textType="${args[2]}";
    declare textFormat="${args[3]}";
    declare textPadding="${args[4]}";
    declare repeatCount="${args[5]}";
    declare subshellLevelMax="${args[6]}";
    declare outputVariableReferenceName="${args[7]}";
    declare newLine="${args[8]}";
    declare textMeta="${args[9]}";
    declare textMetaEnd="${args[10]}";
    declare textTimestamp="${args[11]}";
    declare clearBefore="${args[12]}";
    declare escapeAdditional="${args[13]}";
    declare text=( "${args[@]:14}" );
    unset args;

    if [[ "$outputVariableReferenceName" != '' ]];
    then
        if [[
            "$outputVariableReferenceName" == 'Misc_PrintF_outputVariableReference' ||
            "$outputVariableReferenceName" == 'Misc_PrintF_outputVariableReferenceFormatMetas'
        ]];
        then
            Misc_PrintF -v 1 -t 'f' -nn -f $'[Misc_PrintF] Output variable reference interference: \'%s\'' -- \
                "$( Misc_ArrayJoin -- "$@" )";
            return 100;
        fi
        declare -n Misc_PrintF_outputVariableReference="$outputVariableReferenceName";
        declare -n Misc_PrintF_outputVariableReferenceFormatMetas="${outputVariableReferenceName}FormatMetas";
        Misc_PrintF_outputVariableReference='';
        Misc_PrintF_outputVariableReferenceFormatMetas=();
    fi

    if [[ "$verbosityLevel" == '' ]];
    then
        declare verbosityLevel="$Misc_VerbosityLevel";
    fi

    if [[ "$subshellLevelMax" == '' ]];
    then
        declare subshellLevelMax="$Misc_PrintF_SubshellLevelMaxDefault";
    fi

    ########
    # Main #
    ########

    # If the current subshell level is higher than permitted or the verbosity level of the text is greater than the configured one
    if (( subshellLevelMax >= 0 && "$BASH_SUBSHELL" > "$subshellLevelMax" || verbosityLevel >= 0 && verbosityLevel > Misc_VerbosityLevel ));
    then
        printf "<<<<< [%s/%s; %s/%s, %s%s] ${textFormat}"$'\n' "$BASH_SUBSHELL" "$subshellLevelMax" "$verbosityLevel" "$Misc_VerbosityLevel" "$textType" \
            "$( [[ "$textMeta" != 0 ]] && printf '; M'; (( repeatCount > 1 )) && printf '; R%s' "$repeatCount" )" "${text[@]}" &>> "$Misc_DumpPath";
        return 0;
    fi

    printf ">>>>> [%s/%s; %s/%s, %s%s] ${textFormat}"$'\n' "$BASH_SUBSHELL" "$subshellLevelMax" "$verbosityLevel" "$Misc_VerbosityLevel" "$textType" \
        "$( [[ "$textMeta" != 0 ]] && printf '; M'; (( repeatCount > 1 )) && printf '; R%s' "$repeatCount" )" "${text[@]}" &>> "$Misc_DumpPath";
    # The default text prefix
    declare textPrefix='';

    if [[ "$textType" != '' ]];
    then
        if [[ "$textTimestamp" != 0 || "$Misc_VerbosityTimestamp" != 0 ]];
        then
            textPrefix+=" ${clGray}[ $( Misc_DateTime -t 5; ) ]${clDefault} ";
        else
            textPrefix=' ';
        fi

        # Set the text prefix according the text type
        # declare textPrefix=" ${clGray}[${clDefault} ${textTypeColors["$textType"]}${textTypeSigns["$textType"]} ${clGray}]${clDefault} ";
        case "$textType" in
            'n') declare textPrefix+="${clGray}[${clDefault}   ${clGray}]${clDefault} ";; # [   ]
            'm') declare textPrefix+="${clGray}[${clDefault} ${clLightPurple}#${clDefault} ${clGray}]${clDefault} ";; # [ # ]
            'q') declare textPrefix+="${clGray}[${clDefault} ${clCyan}?${clDefault} ${clGray}]${clDefault} ";; # [ ? ]
            'i') declare textPrefix+="${clGray}[${clDefault} ${clGray}*${clDefault} ${clGray}]${clDefault} ";; # [ * ]
            's') declare textPrefix+="${clGray}[${clDefault} ${clLightGreen}+${clDefault} ${clGray}]${clDefault} ";; # [ + ]
            'w') declare textPrefix+="${clGray}[${clDefault} ${clYellow}!${clDefault} ${clGray}]${clDefault} ";; # [ ! ]
            'e') declare textPrefix+="${clGray}[${clDefault} ${clLightRed}-${clDefault} ${clGray}]${clDefault} ";; # [ - ]
            'f') declare textPrefix+="${clGray}[${clDefault} ${clRed}x${clDefault} ${clGray}]${clDefault} ";; # [ x ]
            'd') declare textPrefix+="${clGray}[${clDefault} ${clBlue}D${clDefault} ${clGray}]${clDefault} ";; # [ D ]
        esac

        if [[ "$subshellLevelMax" != "$Misc_PrintF_SubshellLevelMaxDefault" ]];
        then
            textPrefix+="${clGray}[${clDefault} $( printf '%s/%s' "$BASH_SUBSHELL" "$subshellLevelMax"; ) ${clGray}]${clDefault} ";
        fi
    fi

    # If a custom output stream was declared
    if [[ "$descriptor" != '' && "${Misc_PrintF_OutputStreamsDefault[$descriptor]}" != '' ]];
    then
        declare outputStream="${Misc_PrintF_OutputStreamsDefault[$descriptor]}";
    else
        # If the text type is related to an error or fatal
        if [[ "$textType" == 'e' || "$textType" == 'f' ]];
        then
            declare outputStream="${Misc_PrintF_OutputStreamsDefault[$Misc_OutputStreamErrDefault]}";
        else
            declare outputStream="${Misc_PrintF_OutputStreamsDefault[$Misc_OutputStreamStdDefault]}";
        fi
    fi

    # Related: https://mywiki.wooledge.org/BashFAQ/053 (*I have a fancy prompt with colors, and now bash doesn't seem to*...)
    declare textFormatEscapeStart='';
    declare textFormatEscapeEnd='';

    if [[ "$escapeAdditional" == 1 ]];
    then
        declare textFormatEscapeStart='\[';
        declare textFormatEscapeEnd='\]';
    elif (( escapeAdditional > 1 ));
    then
        declare textFormatEscapeStart='\001';
        declare textFormatEscapeEnd='\002';
    fi

    declare metaType=0;
    declare textFormatMetas=();
    declare textFormatMetasOffsets=();
    # If text format was declared
    if [[ "$textFormat" != '' ]];
    then
        # If metas are enabled
        if [[ "$textMeta" != 0 ]];
        then
            Misc_AdvancedRegex -o Misc_PrintF_textFormatMetas -s '(?:\{\{@[0-9a-zA-Z]+\}\}|\{\{\#[0-9a-fA-F]{6}\}\}|\{\{\#[0-9a-fA-F]{3}\}\})' -- "$textFormat";
            declare textFormatMetas=( "${Misc_PrintF_textFormatMetas[@]}" );
            declare textFormatMetasOffsets=( "${Misc_PrintF_textFormatMetasOffsets[@]}" );
            # If a meta was found
            if [[ "${#textFormatMetas[@]}" != 0 ]];
            then
                # declare textFormatTemp='';
                # Get the first plain part before the first meta, if exists
                # echo "textFormatMetas=${textFormatMetas[@]}" &>> "$Misc_DumpPath";
                declare textFormatTemp="${textFormat:0:${textFormatMetasOffsets[0]}}";
                declare textFormatPlainLength=0;
                declare textFormatMetaIndex;
                # Loop through each found meta
                for (( textFormatMetaIndex = 0; textFormatMetaIndex < ${#textFormatMetas[@]}; textFormatMetaIndex++ ));
                do
                    # Parse the meta
                    # Get raw meta data from the format string and trim it
                    declare textFormatMetaRaw="${textFormatMetas[$textFormatMetaIndex]}"; # {{meta}}
                    declare textFormatMeta="${textFormatMetaRaw%\}\}}" # {{meta}} ~> {{meta
                    declare textFormatMeta="${textFormatMeta#\{\{}" # {{meta ~> meta
                    # echo "[${textFormatMetaIndex}]textFormatMeta=${textFormatMeta}" &>> "$Misc_DumpPath";
                    # We might need another way to find the meta's type (i.e. with a group search above, returning
                    # groups' positions(which mean the types of meta) instead of only match or not), else
                    # it runs multiple times per the same data (the textFormat and each meta)
                    # Set the constant if exists (@constant)
                    declare textFormatConstantName="${textFormatMeta#\@}"; # @constant ~> constant

                    # If the constant with such array associative index exists
                    if [[ "${Misc_ColorsTheme[$textFormatConstantName]+s}" != '' ]];
                    then
                        declare textFormatMeta="${Misc_ColorsTheme[$textFormatConstantName]}";
                    fi

                    # If a meta is a color (#RRGGBB or #RGB)
                    if Misc_AdvancedRegex -s '\#[0-9a-zA-Z]{6}|\#[0-9a-zA-Z]{3}' -- "$textFormatMeta";
                    then
                        declare metaType=1;
                        # A meta is a color
                        declare textFormatCHex=${textFormatMeta#\#}; # #RRGGBB ~> RRGGBB or #RGB ~> RGB
                        # If the colors is in RGB format
                        if [[ "${#textFormatCHex}" == 3 ]];
                        then
                            textFormatCHex="${textFormatCHex:0:1}${textFormatCHex:0:1}${textFormatCHex:1:1}${textFormatCHex:1:1}${textFormatCHex:2:1}${textFormatCHex:2:1}"
                        fi
                        # i.e. 33FF11 ~> 51;255;17
                        declare textFormatMetaDec; textFormatMetaDec="$( printf "%d;%d;%d" "0x${textFormatCHex:0:2}" "0x${textFormatCHex:2:2}" "0x${textFormatCHex:4:2}" )";
                        declare textFormatMeta="\033[38;2;${textFormatMetaDec}m";
                    else # Meta is a constant
                        declare metaType=2;
                    fi

                    # Get the current color start char position
                    declare textFormatMetaStart="${textFormatMetasOffsets[textFormatMetaIndex]}";
                    # If the next color exists
                    if (( "$textFormatMetaIndex" + 1 < ${#textFormatMetas[@]} ));
                    then
                        # Get the next color start char position
                        declare textFormatMetaStartNext="${textFormatMetasOffsets[textFormatMetaIndex + 1]}";
                    else
                        # Set the next color position to the end of the format string
                        declare textFormatMetaStartNext="${#textFormat}";
                    fi

                    # Parse the text
                    # The start position of the plain text part (meta start + meta length)
                    declare textFormatStart=$(( textFormatMetaStart + ${#textFormatMetaRaw} ));
                    # The plain text part (from whole format: from "text start" to ("next meta start or end of the format" - text start))
                    declare textFormatPlain="${textFormat:$textFormatStart:$(( textFormatMetaStartNext - textFormatStart ))}";
                    # Add the current part's length to the parsed plain text length
                    textFormatPlainLength=$((textFormatPlainLength + ${#textFormatPlain}));
                    # Append the current part with the color to the parsed plain text
                    textFormatTemp+="${textFormatEscapeStart}${textFormatMeta}${textFormatEscapeEnd}${textFormatPlain}";
                done

                # Set the text format
                declare textFormat="${textFormatTemp}";
            fi
        fi
    else
        declare textFormat='%s';
    fi

    # If color was found in textFormat and metaEnd is not set or no color was found and metaEnd is set
    if [[ "$metaType" != 0 && "$textMetaEnd" == 0 || "$metaType" == 0 && "$textMetaEnd" != 0 ]];
    then
        # End colors
        textFormat+="${textFormatEscapeStart}\033[m${textFormatEscapeEnd}";
    fi

    # Padding (top[,left] or ,left)
    declare textPaddingTop="${textPadding%%,*}";

    if [[ "${textPadding-}" =~ \, ]];
    then
        declare textPaddingLeft="${textPadding##*,}";
    fi

    if [[ "${textPaddingTop-}" == '' ]];
    then
        declare textPaddingTop=0;
    fi

    if [[ "${textPaddingLeft-}" == '' ]];
    then
        declare textPaddingLeft=0;
    fi

    if [[ "${repeatCount-}" == '' ]];
    then
        declare repeatCount=1;
    fi

    if [[ "$clearBefore" != 0 ]];
    then
        clear;
    fi

    # If requested to set the referenced variable
    if [[ "$outputVariableReferenceName" != '' ]];
    then
        Misc_PrintF_outputVariableReference='';
        declare whitespaceIndex;

        # Padding top loop
        for (( whitespaceIndex = 0; whitespaceIndex < "$textPaddingTop"; whitespaceIndex++ ));
        do
            Misc_PrintF_outputVariableReference="\n${Misc_PrintF_outputVariableReference}";
        done

        # Padding left loop
        for (( whitespaceIndex = 0; whitespaceIndex < "$textPaddingLeft"; whitespaceIndex++ ));
        do
            Misc_PrintF_outputVariableReference=" ${Misc_PrintF_outputVariableReference}";
        done

        declare repeatIndex;

        # As many times as declared
        for (( repeatIndex = 0; repeatIndex < "$repeatCount"; repeatIndex++ ));
        do
            # > Command substitutions strip all trailing newlines from the output of the command inside them.
            # So, we add 1 character at the very end after possible new lines and remove it later
            # shellcheck disable=SC2059
            Misc_PrintF_outputVariableReference+="$( printf "${textPrefix}${textFormat}" "${text[@]}"; printf '.'; )";
            Misc_PrintF_outputVariableReference="${Misc_PrintF_outputVariableReference%\.}";
        done

        # New line loop (padding bottom)
        for (( whitespaceIndex = 0; whitespaceIndex < "$newLine"; whitespaceIndex++ ));
        do
            Misc_PrintF_outputVariableReference="${Misc_PrintF_outputVariableReference}\n";
        done

        # shellcheck disable=SC2034
        Misc_PrintF_outputVariableReferenceFormatMetas=( "${textFormatMetas[@]}" );

        return 0;
    fi

    declare whitespaceIndex;

    # Padding top loop
    for (( whitespaceIndex = 0; whitespaceIndex < "$textPaddingTop"; whitespaceIndex++ ));
    do
        printf '\n';
    done

    # Padding left loop
    for (( whitespaceIndex = 0; whitespaceIndex < "$textPaddingLeft"; whitespaceIndex++ ));
    do
        printf ' ';
    done

    declare repeatIndex;

    # As many times as declared
    for (( repeatIndex = 0; repeatIndex < "$repeatCount"; repeatIndex++ ));
    do
        # Output a prepared text to the specified stream
        # shellcheck disable=SC2059
        printf "${textPrefix}${textFormat}" "${text[@]}" > "$outputStream";
    done

    # New line loop (padding bottom)
    for (( whitespaceIndex = 0; whitespaceIndex < "$newLine"; whitespaceIndex++ ));
    do
        printf '\n';
    done

    return 0;
}
