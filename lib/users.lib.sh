#! /usr/bin/env bash

set -eu;

# Initials
# ----------------------------------------------------------------

declare _Users_sourceFilepath; _Users_sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )"; readonly _Users_sourceFilepath;
declare _Users_sourceDirpath; _Users_sourceDirpath="$( dirname -- "$_Users_sourceFilepath" 2> '/dev/null'; )"; readonly _Users_sourceDirpath;

[[ ! -f "$_Users_sourceFilepath" || ! -d "$_Users_sourceDirpath" ]] && exit 99;

# Libraries
# ----------------------------------------------------------------

export SHELL_LIBS_DIRPATH="$_Users_sourceDirpath"; [[ -d "$SHELL_LIBS_DIRPATH" ]] || exit 98;

# shellcheck disable=SC1091
[[ "${SHELL_LIB_OPTIONS:+s}" == '' ]] && { source "${SHELL_LIBS_DIRPATH}/options.lib.sh" && [[ "${SHELL_LIB_OPTIONS:+s}" != '' ]] || exit 97; };
# shellcheck disable=SC1091
[[ "${SHELL_LIB_UI:+s}" == '' ]] && { source "${SHELL_LIBS_DIRPATH}/ui.lib.sh" && [[ "${SHELL_LIB_UI:+s}" != '' ]] || exit 97; };

# shellcheck disable=SC2034
declare -r SHELL_LIB_USERS="$_Users_sourceFilepath";

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Print general User and environment information from a non-interacive login shell.
Users_PrintUserInfo()
{
    # Options
    # ------------------------------

    declare args; _options args \
        '/0/^(?:0|[1-9][0-9]*)$' \
        '!?--uid:-u' \
        "$@" \
    || return $?;

    declare __uid="${args[0]}";
    unset args;

    # Main
    # ------------------------------

    declare tempFile; tempFile="$( mktemp; )";

    tee -- "$tempFile" > '/dev/null' <<EOF
#! /usr/bin/env bash

# Show some general information about a User
main()
{
    printf -- $'\n  User: \n';
    printf -- $'    %s\n' \$( id; ) "Home: '\${HOME}'";
    printf -- $'\n  Shell:\n';
    printf -- $'    Options: \'%s\'\n' "\$-";
    printf -- $'    Login: %s\n' "\$( shopt -q login_shell && printf -- 'true' || printf -- 'false'; )";
    printf -- '\n-----\\\\ [1/3] Shell Variables \n\n';
    set;
    printf -- '\n-----/\n';
    printf -- '\n-----\\\\ [2/3] Environment Variables \n\n';
    env;
    printf -- '\n-----/\n\n';
    printf -- '\n-----\\\\ [3/3] User Home Files (%s) \n\n' "\$HOME";
    ls -la -- "\$HOME";
    printf -- '\n-----/\n';
    printf -- '\n';
}

main "\$@";
EOF

    chmod +rx -- "$tempFile";
    Shell_ExecuteAs -lu "$__uid" -f "$tempFile";
    rm "$tempFile";

    return 0;
}

Users_AddUser()
{
    # Options
    # ------------------------------

    declare args; _options args \
        '/0/^(?:0|[1-9][0-9]*)$' \
        '/1/^(?:0|[1-9][0-9]*)$' \
        '//5?' '/bin/bash' \
        '!?--uid:-u;!?--gid:-g;!?--username:-U;?--groupname:-G;?--groups:-a;?--user-shell:-s;?--user-password:-p;--skeletons:-H' \
        "$@" \
    || return $?;

    declare __uid="${args[0]}";
    declare __gid="${args[1]}";
    declare __userName="${args[2]}";
    declare __groupName="${args[3]}";
    declare __userGroups="${args[4]}";
    declare __userShell="${args[5]}";
    declare __userPassword="${args[6]}";
    declare __userSkeletons="${args[7]}";
    unset args;

    # Main
    # ------------------------------

    if [[ "$( id -u "$__uid" 2> '/dev/null'; )" == "$__uid" ]];
    then
        O -p :2 -t i -nf $'User already exists: \'%s\' (UID %s)' -- \
            "$( id -un "$__uid"; )" "$__uid";
    else
        declare groupName="$__groupName";

        if [[ "$groupName" == '' ]];
        then
            declare groupName="$__userName";
        fi

        groupadd -g "$__gid" -- "$groupName";

        declare userAddOptions=();

        # If "skel" files are not required
        if (( __userSkeletons == 0 ));
        then
            userAddOptions+=( '-k' '/dev/null' );
        fi

        useradd -Nmu "$__uid" \
            -g "$__gid" \
            -G "$__userGroups" \
            -s "$__userShell" \
            "${userAddOptions[@]}" \
            -- "$__userName";

        O -p :2 -t s -nf $'Added user \'%s\' (%s:%s): \'%s\'' -- \
            "$__userName" "$__uid" "$__gid" "$( id -- "$__uid"; )";
    fi

    if [[ ! -d "/home/${__userName}" ]];
    then
        O -p :2 -t e -nf $'User \'%s\' (%s:%s) home directory does not exist.' -- \
            "$__userName" "$__uid" "$__gid";

        return 1;
    fi

    if [[ "$__userPassword" != '' ]];
    then
        printf -- '%s' "${__userName}:${__userPassword}" | chpasswd;

        O -p :2 -t w -nf $'Set User local password: \'%s\'' -- \
            "$__userPassword";
    fi

    Shell_ExecuteAs -u "$__uid" -- ls -la /etc/profile;
    Shell_ExecuteAs -u "$__uid" -- cat /etc/profile;
    Shell_ExecuteAs -u "$__uid" -- ls -la /etc/profile.d;
    Shell_ExecuteAs -u "$__uid" -- cat /etc/bash.bashrc;

    # set -x;

    # echo Test 1
    # Shell_ExecuteAs -u "$__uid" -c 'id; env; echo "$-";' -- "123";

    # echo Test 2
    # Shell_ExecuteAs -u "$__uid" -- id\; env\; nvm \|\|:;

    # echo Test 3
    # Users_PrintUserInfo -u "$__uid";

    # exit 1;

    return 0;
}
