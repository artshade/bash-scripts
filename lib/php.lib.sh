#! /usr/bin/env bash

set -eu;

# Initials
# ----------------------------------------------------------------

declare _Php_sourceFilepath; _Php_sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )"; readonly _Php_sourceFilepath;
declare _Php_sourceDirpath; _Php_sourceDirpath="$( dirname -- "$_Php_sourceFilepath" 2> '/dev/null'; )"; readonly _Php_sourceDirpath;

[[ ! -f "$_Php_sourceFilepath" || ! -d "$_Php_sourceDirpath" ]] && exit 99;

# Libraries
# ----------------------------------------------------------------

export SHELL_LIBS_DIRPATH="$_Php_sourceDirpath"; [[ -d "$SHELL_LIBS_DIRPATH" ]] || exit 98;

# shellcheck disable=SC1091
[[ "${SHELL_LIB_OPTIONS:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/options.lib.sh" && [[ "${SHELL_LIB_OPTIONS:+s}" != '' ]] || exit 97; };
# shellcheck disable=SC1091
[[ "${SHELL_LIB_SHELL:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/shell.lib.sh" && [[ "${SHELL_LIB_SHELL:+s}" != '' ]] || exit 97; };
# shellcheck disable=SC1091
[[ "${SHELL_LIB_TIME:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/time.lib.sh" && [[ "${SHELL_LIB_TIME:+s}" != '' ]] || exit 97; };
# shellcheck disable=SC1091
[[ "${SHELL_LIB_GIT:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/git.lib.sh" && [[ "${SHELL_LIB_GIT:+s}" != '' ]] || exit 97; };
# shellcheck disable=SC1091
[[ "${SHELL_LIB_UI:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/ui.lib.sh" && [[ "${SHELL_LIB_UI:+s}" != '' ]] || exit 97; };

# shellcheck disable=SC2034
declare -r SHELL_LIB_PHP="$_Php_sourceFilepath";

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Functions
# ----------------------------------------------------------------

Php_CsFixerDiff()
{
    # Options
    # --------------------------------

    declare args; Options args \
        '!?-e;?-o;?-d;?-s;-c' \
        "$@" \
    || return $?;

    declare __phpCsFixerExecutableFilepath="${args[0]}";
    declare __outputReference="${args[1]}";
    declare __gitBranchDestination="${args[2]}";
    declare __gitBranch="${args[3]}";
    declare __changed="${args[4]}";
    declare __filepaths=( "${args[@]:5}" );
    unset args;

    # ----------------

    if [[ "$__outputReference" != '' ]];
    then
        if [[
            "$__outputReference" == 'Php_CsFixerDiff_outputVariableReference' ||
            "$__outputReference" == 'Php_CsFixerDiff_outputVariableReferenceStates' ||
            "$__outputReference" == 'Php_CsFixerDiff_outputVariableReferenceDiffs'
        ]];
        then
            UI_PrintF -n -- '[Php_CsFixerDiff] Output variable reference interference';

            return 100;
        fi

        declare -n Php_CsFixerDiff_outputVariableReference="$__outputReference";
        declare -n Php_CsFixerDiff_outputVariableReferenceStates="${__outputReference}States";
        declare -n Php_CsFixerDiff_outputVariableReferenceDiffs="${__outputReference}Diffs";
        Php_CsFixerDiff_outputVariableReference=();
        Php_CsFixerDiff_outputVariableReferenceStates=();
        Php_CsFixerDiff_outputVariableReferenceDiffs=();
    fi

    # Main
    # --------------------------------

    UI_GapPrint;

    if [[ ! -f "$__phpCsFixerExecutableFilepath" ]];
    then
        O -np :2 -t 'e' -f $'No PhpCsFixer found: \'%s\'' -- "$__phpCsFixerExecutableFilepath";

        return 1;
    fi

    if [[ "$__changed" == 0 && "${#__filepaths[@]}" == 0 ]];
    then
        "$__phpCsFixerExecutableFilepath" fix --dry-run -v --diff;

        return;
    fi

    declare gitBranch="$__gitBranch";

    if [[ "$gitBranch" == '' ]];
    then
        gitBranch="$( Git_PrintBranch; )";
    fi

    if [[ "$__gitBranchDestination" == '' ]];
    then
        O -np 1:2 -f $'No destination branch provided for \'diff\' with \'%s\'' -- "$gitBranch";

        return 1;
    fi

    declare changedFilepaths=();
    readarray -t changedFilepaths < <( Git_PrintDiff -ns "$gitBranch" -d "$__gitBranchDestination"; );

    if (( ${#changedFilepaths[@]} == 0 ));
    then
        O -np 1:2 -f $'Branches: \'%s\' == \'%s\'' -- "$gitBranch" "$__gitBranchDestination";

        return 0;
    fi

    O -nnp 1:2 -f $'Branches: \'%s\' <> \'%s\'' -- "$gitBranch" "$__gitBranchDestination";

    declare filepaths=( "${__filepaths[@]}" );

    if [[ "${#filepaths[@]}" != 0 ]];
    then
        O -np :2 -f $'Total items count to process (options): %s' -- "${#filepaths[@]}";
    else
        declare filepaths=( "${changedFilepaths[@]}" );

        O -np :2 -f $'Total items count to process (git): %s' -- "${#filepaths[@]}";
    fi

    O -nnp 1 -F '# ' -- "$( R -c 80 -- '-'; )";
    declare itemStates=();
    declare itemFilepaths=();
    declare itemDiffs=();
    declare itemTimes=();
    declare fileCountTotal="${#filepaths[@]}";
    declare Php_CsFixerDiff_diffResults;
    declare Php_CsFixerDiff_diffResultsStdOut;
    # shellcheck disable=SC2034
    declare Php_CsFixerDiff_diffResultsStdErr;
    declare filepathIndex;
    declare filepathPhpIndex=0;
    declare issuesFoundCount=0;

    for (( filepathIndex = 0; filepathIndex < fileCountTotal; filepathIndex++ ));
    do
        declare itemFilepath="${filepaths[$filepathIndex]}";
        declare itemBasename; itemBasename="$( basename "$itemFilepath"; )";

        if [[ "${itemBasename##*\.}" != 'php' ]];
        then
            continue;
        fi

        Time_Diff -s -- 'php_file_diff_process_start';

        O -p :2 -f "[ %${#fileCountTotal}s ] [ %${#fileCountTotal}s found ] Processing: '%s'" -- \
            "$(( filepathPhpIndex + 1 ))" "$issuesFoundCount" "$itemFilepath";

        declare filepathPhpIndex="$(( filepathPhpIndex + 1 ))";

        if [[ ! -f "$itemFilepath" ]];
        then
            itemStates+=( -1 );
            itemFilepaths+=( '' );
            itemDiffs+=( '' );
            declare Php_CsFixerDiff_timeDiff;
            Time_Diff -dfo Php_CsFixerDiff_timeDiff -- 'php_file_diff_process_start';
            itemTimes+=( "${Php_CsFixerDiff_timeDiff[0]}" );
            O -nf ' (%sms)' -- "${itemTimes[@]: -1}";

            continue;
        fi

        declare Php_CsFixerDiff_shellOptions;
        Shell_Options -sro Php_CsFixerDiff_shellOptions;
        set +e;
        # shellcheck disable=SC2034
        declare Php_CsFixerDiff_diffResults;

        # Single quote re-escape?
        Shell_Execute -o Php_CsFixerDiff_diffResults -- \
            "'${__phpCsFixerExecutableFilepath}' fix --dry-run --diff -- '${itemFilepath}'";

        declare exitCode="$?";
        Shell_Options -lf "$Php_CsFixerDiff_shellOptions";
        unset Php_CsFixerDiff_shellOptions;
        declare Php_CsFixerDiff_timeDiff;
        Time_Diff -dfo Php_CsFixerDiff_timeDiff -- 'php_file_diff_process_start';
        itemTimes+=( "${Php_CsFixerDiff_timeDiff[0]}" );

        if [[ "$exitCode" == 0 ]];
        then
            O -nf ' (%sms)' -- "${itemTimes[@]: -1}";
            itemStates+=( 0 );
            itemFilepaths+=( '' );
            itemDiffs+=( '' );

            continue;
        fi

        itemStates+=( "$exitCode" );
        itemFilepaths+=( "$itemFilepath" );
        itemDiffs+=( "${Php_CsFixerDiff_diffResultsStdOut[0]}" );
        issuesFoundCount="$(( issuesFoundCount + 1 ))";
        O -nf ' (%sms) [!]' -- "${itemTimes[@]: -1}";
    done

    unset Php_CsFixerDiff_diffResults Php_CsFixerDiff_diffResultsStdOut Php_CsFixerDiff_diffResultsStdErr;
    declare fileNotFoundCount; fileNotFoundCount="$( Misc_ArrayItemsCount '-1' "${itemStates[@]}" )";
    declare issuesNotFoundCount; issuesNotFoundCount="$( Misc_ArrayItemsCount '0' "${itemStates[@]}" )";
    O -nnp 1 -F '# ' -- "$( R -c 80 -- '-'; )";

    if (( fileCountTotal - fileNotFoundCount == issuesNotFoundCount ));
    then
        O -np :2 -t 's' -f $'All items passed successfully';

        O -nnp :2 -t 'n' -f $'Total: %s%s' -- \
            "$(( fileCountTotal - fileNotFoundCount ))" \
            "$( (( fileNotFoundCount > 0 )) && printf -- ' (%s not found)' "$fileNotFoundCount" )";

        return 0;
    fi

    declare tableItems=();
    declare filepathIndex;

    for (( filepathIndex = 0; filepathIndex < ${#itemFilepaths[@]}; filepathIndex++ ));
    do
        declare itemState="${itemStates[$filepathIndex]}";

        if (( itemState <= 0 ));
        then
            continue;
        fi

        declare itemFilepath="${itemFilepaths[$filepathIndex]}";
        declare itemStateSymbol='?';

        case "$itemState" in
            '4')
                declare itemStateSymbol='x'; # Syntax
            ;;
            '8')
                declare itemStateSymbol='~'; # Style
            ;;
        esac

        tableItems+=( "$(( filepathIndex + 1 ))" "$itemStateSymbol" "${itemTimes[$filepathIndex]}" "${#itemDiffs[$filepathIndex]}" "$itemFilepath" );
    done

    O -cn;
    UI_PrintTable -c 5 -- 'Index' 'State' 'Time (ms)' 'Diff Length' 'Filepath' "${tableItems[@]}";

    O -nnp 1 -F '# ' -- "$( R -c 80 -- '-'; )";
    O -nnp :2 -f $'Branches: \'%s\' <> \'%s\'' -- "$gitBranch" "$__gitBranchDestination";
    O -np :2 -f $'Total items: %s items%s' -- "$(( fileCountTotal - fileNotFoundCount ))" "$( (( fileNotFoundCount > 0 )) && printf -- ' (%s not found)' "$fileNotFoundCount" )";
    O -np :3 -f $'Syntax (x): %s' -- "$( Misc_ArrayItemsCount '4' "${itemStates[@]}" )";
    O -nnp :4 -f $'Style (~): %s' -- "$( Misc_ArrayItemsCount '8' "${itemStates[@]}" )";

    if [[ "$__outputReference" != '' ]];
    then
        # shellcheck disable=SC2034
        Php_CsFixerDiff_outputVariableReference=( "${itemFilepaths[@]}" );
        # shellcheck disable=SC2034
        Php_CsFixerDiff_outputVariableReferenceStates=( "${itemStates[@]}" );
        # shellcheck disable=SC2034
        Php_CsFixerDiff_outputVariableReferenceDiffs=( "${itemDiffs[@]}" );

        return 0;
    fi
}

Php_CsFixerWrite()
{
    # Options
    # --------------------------------

    declare args; Options args \
        '!?-e;-f' \
        "$@" \
    || return $?;

    declare __phpCsFixerExecutableFilepath="${args[0]}";
    declare __force="${args[1]}";
    declare __filepaths=( "${args[@]:2}" );

    # Main
    # --------------------------------

    UI_GapPrint;

    if [[ ! -f "$__phpCsFixerExecutableFilepath" ]];
    then
        O -nnp :2 -t 'e' -f $'No PhpCsFixer found: \'%s\'' -- "$__phpCsFixerExecutableFilepath";

        return 1;
    fi

    if [[ "${#__filepaths[@]}" == 0 ]];
    then
        O -nnp :2 -t 'e' -- $'No file provided to process';

        return 1;
    fi

    declare fileCountTotal="${#__filepaths[@]}";
    declare filepathIndex;
    O -nnf 'Total %s' -- "$fileCountTotal";
    Misc_ArrayP -ke -- "${__filepaths[@]}";
    O -n;

    for (( filepathIndex = 0; filepathIndex < ${#__filepaths[@]}; filepathIndex+=2 ));
    do
        declare filepath="${__filepaths[$((fileCountTotal / 2 + filepathIndex / 2))]}";
        declare state="${__filepaths[$((filepathIndex / 2))]}";

        printf -- 'Fix (%s)? %s\n' "$state" "$filepath";

#        "$__phpCsFixerExecutableFilepath" fix --dry-run --diff -- "$filepath";
#        declare exitCode="$?";
#        itemStates+=( "$exitCode" );
#
#        if [[ "$exitCode" != 0 ]];
#        then
#            itemIssues+=( "$exitCode" "$filepath" );
#        fi
    done

#    declare argsTemp=();
#    readarray -O "${#argsTemp[@]}" -t argsTemp < <( ! (( __write > 0 )) && printf -- '--dry-run'; );
}
