#! /usr/bin/env bash

# Initials
# ----------------------------------------------------------------

declare _sourceFilepath; _sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}"; )"; readonly _sourceFilepath;
declare _sourceDirpath; _sourceDirpath="$( dirname -- "$_sourceFilepath"; )"; readonly _sourceDirpath;

[[ ! -f "$_sourceFilepath" || ! -d "$_sourceDirpath" ]] && exit 99;

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

    _verifyChecksum "$_sourceFilepath" "$_sourceDirpath";
) || {
    printf -- $'Failed to self-verify file integrity: \'%s\'.\n' "$_sourceFilepath" >&2;

    exit 98;
}

# Libraries
# ----------------------------------------------------------------

for SHELL_LIBS_DIRPATH in \
    "${_sourceDirpath}/../lib" \
    "${_sourceDirpath}/lib" \
    "${SHELL_LIBS_DIRPATH:-$_sourceDirpath}";
do
    [[ -d "$SHELL_LIBS_DIRPATH" ]] && break;
done

{
    # shellcheck disable=SC1091
    [[ -d "${SHELL_LIBS_DIRPATH-}" ]] && export SHELL_LIBS_DIRPATH &&
    { [[ -v SHELL_LIB_OPTIONS ]] || . "${SHELL_LIBS_DIRPATH}/options.lib.sh"; } &&
    { [[ -v SHELL_LIB_MISC ]] || . "${SHELL_LIBS_DIRPATH}/misc.lib.sh"; } &&
    { [[ -v SHELL_LIB_PHP ]] || . "${SHELL_LIBS_DIRPATH}/php.lib.sh"; } &&
    [[
        "${SHELL_LIBS_INTEGRITY-1}" == 0 ||
        '4ae5b061799db1f2114c68071e8e0dc4da416976c282166efdc6c557f27a304e' == "${SHELL_LIB_OPTIONS%%\:*}" &&
        '280ebccb12f72aa800a1571bd2419185fc197b76565cfae5fae1acbc8bcd18a0' == "${SHELL_LIB_MISC%%\:*}" &&
        '0b73061766bc18412fbc6cb672fbc1fe5e6df5bcdf3675d7eb595ffd9c4edbaa' == "${SHELL_LIB_PHP%%\:*}"
    ]]
} || {
    printf -- $'Failed to source libraries to \'%s\' from directory \'%s\'.\n' \
        "$_sourceFilepath" "$SHELL_LIBS_DIRPATH" 1>&2;

    exit 97;
}

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Functions
# ----------------------------------------------------------------

_generateDirChecksum()
{
    declare __dirpath; __dirpath="$( readlink -fn -- "${1:-$_sourceDirpath}" )";
    declare __filenameRegex="${2:-.*}";
    shift 2;

    # --------------------------------

    if [[ ! -d "$__dirpath" || ! -x "$__dirpath" ]];
    then
        printf -- $' [ - ] Failed to generate checksums. No such available directory: \'%s\'.\n' \
            "$__dirpath";

        return 1;
    fi

    printf -- $' [ * ] Generating SHA256 checksums in directory: \'%s\'.\n' "$__dirpath";
    printf -- $' [   ] Filename regex: \'%s\'.\n' "$__filenameRegex";

    pushd -- "$__dirpath" > '/dev/null' \
        || return 1;

    declare filepaths=();

    readarray -t -- filepaths < <(
        find . -mindepth 1 -maxdepth 1 -regex "$__filenameRegex" \
            -exec readlink -f -- {} \;;
    );

    declare filepathsCount=${#filepaths[@]};

    if (( filepathsCount == 0 ));
    then
        printf -- $' [ - ] Failed to generate checksums. No files found.\n';

        popd > '/dev/null' \
            || return 1;

        return 1;
    fi

    printf -- $' [   ] Found %s file(s) total:\n\n' "$filepathsCount";

    declare filepathsIndexPadding="${#filepathsCount}";
    declare filepathIndex;
    declare filepath;

    for (( filepathIndex = 0; filepathIndex < filepathsCount; filepathIndex++ ));
    do
        declare filepath="${filepaths[$filepathIndex]}";
        declare filename; filename="$( basename -- "$filepath" )";
        declare checksumFilepath="${filename}.sha256sum";

        if ! sha256sum -b -- "$filename" > "$checksumFilepath";
        then
            printf -- $' [ - ] Failed to generate checksum for file: \'%s\'.\n' "$filepath";

            popd > '/dev/null' \
                || return 1;

            return 1;
        fi

        declare checksumValue; checksumValue="$( cut -d ' ' -f 1 -- "$checksumFilepath"; )";

        # shellcheck disable=SC2059
        printf -- $"  [ %${filepathsIndexPadding}s/%s ] '%s' - '%s'.\n" \
            "$(( filepathIndex + 1 ))" "$filepathsCount" "$checksumValue" "$checksumFilepath";
    done

    printf '\n';

    popd > '/dev/null' \
        || return 1;

    printf -- $' [ + ] Generated checksums in directory: \'%s\'.\n' "$__dirpath";

    return 0;
}

# Main
# ----------------------------------------------------------------

_main()
{
    declare __dirpath; __dirpath="${1:-${_sourceDirpath}/../lib}";

    # --------------------------------

    printf '\n';
    # _generateDirChecksum "$__dirpath" '.+\.sh$';

    find "$_sourceDirpath" \
            -iregex '.*\.sh$' \
            -execdir bash -c $'printf -- "// Directory: \'%s\'\n" "$( pwd -P; )"; sha256sum -b -- "$1" | tee -- "${1}.sha256sum";' - {} \;;

    find "$__dirpath" \
            -iregex '.*\.sh$' \
            -execdir bash -c $'printf -- "// Directory: \'%s\'\n" "$( pwd -P; )"; sha256sum -b -- "$1" | tee -- "${1}.sha256sum";' - {} \;;

    printf '\n';
}

_main "$@";