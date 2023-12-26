#!/usr/bin/env bash

# Copyright 2022 Faither

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

declare _Template_sourceFilepath; _Template_sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )"; readonly _Template_sourceFilepath;
declare _Template_sourceDirpath; _Template_sourceDirpath="$( dirname -- "$_Template_sourceFilepath" 2> '/dev/null'; )"; readonly _Template_sourceDirpath;

[[ ! -f "$_Template_sourceFilepath" || ! -d "$_Template_sourceDirpath" ]] && exit 99;

# Libraries
# ----------------------------------------------------------------

# shellcheck disable=SC2034
declare -r SHELL_LIB_TEMPLATE="$_Template_sourceFilepath";

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Functions
# ----------------------------------------------------------------

# Test if a regex Perl Compatible Regular Expressions (PCRE) pattern is valid (<3 Perl)
Template_RegexVerify()
{
    IFS=$' \t\n' printf '%s' "$@" | perl -ne 'eval { qr/$_/ }; die if $@;' &> '/dev/null';
}

Template_RegexReplace()
{
    ###########
    # Options #
    ###########

    declare patternSearch="$1";
    declare patternReplace="$2";
    shift 2;
    declare filepaths=( "$@" );

    ########
    # Main #
    ########

    if ! Template_RegexVerify "$patternSearch";
    then
        printf $'Invalid search pattern was declared for regex replace: \'%s\'\n' "$patternSearch";

        return 2;
    fi

    if [[ "$patternReplace" != '' ]] && ! Template_RegexVerify "$patternReplace";
    then
        printf $'Invalid replace pattern was declared for regex replace: \'%s\'\n' "$patternReplace";

        return 2;
    fi

    # Todo: Find a non-conflict option. A subshell?
    if [[ "${patternSearchExported+s}" != '' || "${patternReplaceExported+s}" != '' ]];
    then
        printf $'Regex replace conflict\n';

        return 2;
    fi

    export patternSearchExported="$patternSearch";
    export patternReplaceExported="$patternReplace";
    # declare perlReplaceBackupExtension='.backup';
    declare matches=0;

    for filepath in "${filepaths[@]}";
    do
        if [ ! -f "$filepath" ];
        then
            printf $'No such file to regex replace: "%s"\n' "$filepath";
        fi

        if IFS=$' \t\n' perl -pi"${perlReplaceBackupExtension:-}" -e 's/$ENV{patternSearchExported}/$ENV{patternReplaceExported}/g && $MATCH++; END{exit 1 unless $MATCH > 0}' "$filepath";
        then
            # if [[ "${perlReplaceBackupExtension-}" != '' ]];
            # then
            #     rm "${filepath}.${perlReplaceBackupExtension}";
            # fi

            declare matches="$((matches + 1))";
        # else
        #     printf $'No regex match for \'%s\' to replace in \'%s\'\n' "$patternSearch" "$filepath";
        fi
    done

    unset patternSearchExported;
    unset patternReplaceExported;

    [[ "$matches" != 0 ]];
}

Template_ValueSet()
{
    declare patternSearch="$1";
    declare patternReplace="$2";
    shift 2;
    declare filepaths=( "$@" );

    if ! Template_RegexReplace "TEMPLATE_VALUE\(${patternSearch}\)" "$patternReplace" "${filepaths[@]}";
    then
        return 1;
    fi

    return 0;
}

Template_ValuesSet()
{
    declare filepath="$1";
    shift 1;
    declare matches=0;
    declare varIndex;

    for (( varIndex = 1; varIndex <= $#; varIndex += 2 ));
    do
        # shellcheck disable=SC2124
        declare patternSearch="${@:$varIndex:1}";
        # shellcheck disable=SC2124
        declare patternReplace="${@:$((varIndex + 1)):1}";

        if Template_ValueSet "$patternSearch" "$patternReplace" "$filepath";
        then
            declare matches="$((matches + 1))";
        fi
    done

    printf $'\'%s\' (%s change%s)\n' "$filepath" "$matches" "$( (( matches > 1 )) && printf 's' )";

    return 0;
}
