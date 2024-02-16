#! /usr/bin/env bash

# Initials
# ----------------------------------------------------------------

declare _sourceFilepath; _sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}"; )"; readonly _sourceFilepath;
declare _sourceDirpath; _sourceDirpath="$( dirname -- "$_sourceFilepath"; )"; readonly _sourceDirpath;

[[ ! -f "$_sourceFilepath" || ! -d "$_sourceDirpath" ]] && exit 99;

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
    _generateDirChecksum "$__dirpath" '.+\.sh$';
    printf '\n';
}

_main "$@";