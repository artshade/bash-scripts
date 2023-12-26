#! /usr/bin/env bash

set -eu;

# Initials
# ----------------------------------------------------------------

declare _Shell_sourceFilepath; _Shell_sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )"; readonly _Shell_sourceFilepath;
declare _Shell_sourceDirpath; _Shell_sourceDirpath="$( dirname -- "$_Shell_sourceFilepath" 2> '/dev/null'; )"; readonly _Shell_sourceDirpath;

[[ ! -f "$_Shell_sourceFilepath" || ! -d "$_Shell_sourceDirpath" ]] && exit 99;

# Libraries
# ----------------------------------------------------------------

export SHELL_LIBS_DIRPATH="$_Shell_sourceDirpath"; [[ -d "$SHELL_LIBS_DIRPATH" ]] || exit 98;

# shellcheck disable=SC1091
[[ "${SHELL_LIB_OPTIONS:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/options.lib.sh" && [[ "${SHELL_LIB_OPTIONS:+s}" != '' ]] || exit 97; };
# shellcheck disable=SC1091
[[ "${SHELL_LIB_MISC:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/misc.lib.sh" && [[ "${SHELL_LIB_MISC:+s}" != '' ]] || exit 97; };

# shellcheck disable=SC2034
declare -r SHELL_LIB_SHELL="$_Shell_sourceFilepath";

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

# Variables Private
# ----------------------------------------------------------------
# Arrays
# --------------------------------

declare -A _Shell_shellOptionsStorage=();

# Functions
# ----------------------------------------------------------------

Shell_Options()
{
    # Options
    # --------------------------------

    declare args; Options args \
        '?-o;?-i;-s;-l;-k;-p;-f;-r;-R;-F;--forget-all' \
        "$@" \
    || return $?;

    declare __ref="${args[0]}";
    declare __options="${args[1]}";
    declare __store="${args[2]}";
    declare __load="${args[3]}";
    declare __printKeys="${args[4]}";
    declare __printOptions="${args[5]}";
    declare __forget="${args[6]}";
    declare __random="${args[7]}";
    declare __reset="${args[8]}";
    declare __force="${args[9]}";
    declare __forgetAll="${args[10]}";
    declare __keys=( "${args[@]:11}" );
    unset args;

    # ----------------

    if [[ "$__ref" != '' ]];
    then
        if [[ "$__ref" == 'Shell_Options_refOut' ]];
        then
            Misc_PrintF -n -- '[Shell_Options] Output variable reference interference';

            return 100;
        fi

        unset Shell_Options_refOut;
        declare -n Shell_Options_refOut="$__ref";
        Shell_Options_refOut=();
    fi

    # Main
    # --------------------------------
    # If reset (unset) all shell options
    # ----------------

    if [[ "$__reset" != 0 ]];
    then
        declare optionsFiltered="${-/i}";
        declare optionsFiltered="${optionsFiltered/s}";
        declare optionIndex;

        for (( optionIndex = 0; optionIndex < ${#optionsFiltered}; optionIndex++ ));
        do
            set "+${optionsFiltered:$optionIndex:1}" 2> '/dev/null';
        done

        if [[ "$__options" != '' ]];
        then
            set "-${__options}";
        fi

        return 0;
    fi

    if (( __forgetAll > 0 ));
    then
        _Shell_shellOptionsStorage=();

        return 0;
    fi

    # If print keys and/or options
    # ----------------

    if [[ "$__printKeys" != 0 || "$__printOptions" != 0 ]];
    then
        if [[ ${#_Shell_shellOptionsStorage[@]} = 0 ]];
        then
            return 1;
        fi

        declare key;

        for key in "${!_Shell_shellOptionsStorage[@]}";
        do
            if [[ "$__printKeys" != 0 ]];
            then
                if [[ "$__ref" != '' ]];
                then
                    Shell_Options_refOut+=( "$key" );
                else
                    printf -- '%s:' "$key";
                fi
            fi

            if [[ "$__printOptions" != 0 ]];
            then
                if [[ "$__ref" != '' ]];
                then
                    Shell_Options_refOut+=( "${_Shell_shellOptionsStorage["$key"]}" );
                else
                    printf -- '%s' "${_Shell_shellOptionsStorage["$key"]}";
                fi
            fi

            if [[ "$__ref" == '' ]];
            then
                printf $'\n';
            fi
        done

        return 0;
    fi

    # If store in random key
    # ----------------

    declare options="$-";

    if [[ "$__options" != '' ]];
    then
        declare options="$__options";
    fi

    if [[ "$__random" != 0 ]];
    then
        if [[ "$__ref" == '' ]];
        then
            return 2;
        fi

        declare key; key="$( Misc_RandomString -l 10; )";

        while [[ -v "_Shell_shellOptionsStorage[${key}]" ]];
        do
            declare key; key="$( Misc_RandomString -l 10; )";
        done

        _Shell_shellOptionsStorage["$key"]="$options";
        Shell_Options_refOut=( "$key" );

        return 0;
    fi

    # Process options
    # ----------------

    declare keys=( "${__keys[@]}" );

    if [[ ${#keys[@]} == 0 ]];
    then
        keys=( 0 );
    fi

    # If only print certain stored options
    if [[ "$__load" == 0 && "$__forget" == 0 && "$__store" == 0 ]];
    then
        declare keyIndex;

        for (( keyIndex = 0; keyIndex < ${#keys[@]}; keyIndex++ ));
        do
            declare key="${keys[$keyIndex]}";

            if [[ ! -v "_Shell_shellOptionsStorage[${key}]" ]];
            then
                printf -- $'Could not print stored shell options (no such key exists): \'%s\'\n' "$key";

                return 1;
            fi

            if [[ "$__ref" != '' ]];
            then
                Shell_Options_refOut+=( "$( printf -- '%s:%s\n' "$key" "${_Shell_shellOptionsStorage["$key"]}"; )" );
            else
                printf -- '%s:%s\n' "$key" "${_Shell_shellOptionsStorage["$key"]}";
            fi
        done

        return 0;
    fi

    # Load stored and/or forget stored and/or store previous/current

    declare keyIndex;

    for (( keyIndex = 0; keyIndex < ${#keys[@]}; keyIndex++ ));
    do
        declare key="${keys[$keyIndex]}";

        if [[ "$key" == '' ]];
        then
            printf -- $'Could not process shell options (empty key)\n';

            return 1;
        fi

        if [[ "$__load" != 0 ]];
        then
            if [[ ! -v "_Shell_shellOptionsStorage[${key}]" ]];
            then
                printf -- $'Could not load stored shell options (no such key exists): \'%s\'\n' "$key";

                return 1;
            fi

            Shell_Options -R;
            declare optionsFiltered="${_Shell_shellOptionsStorage["$key"]/i}";
            declare optionsFiltered="${optionsFiltered/s}";
            set "-${optionsFiltered}";
        fi

        if [[ "$__forget" != 0 ]];
        then
            if [[ ! -v "_Shell_shellOptionsStorage[${key}]" ]];
            then
                printf -- $'Could not forget stored shell options (no such key exists): \'%s\'\n' "$key";

                return 1;
            fi

            # @see https://www.shellcheck.net/wiki/SC2184
            unset '_Shell_shellOptionsStorage["$key"]';

            continue;
        fi

        if [[ "$__store" != 0 ]];
        then
            if [[ -v "_Shell_shellOptionsStorage[${key}]" && "$__force" == 0 ]];
            then
                printf -- $'Could not store shell options (key already exists): \'%s\'\n' "$key";

                return 1;
            fi

            _Shell_shellOptionsStorage["$key"]="$options";
        fi
    done

    return 0;
}

# @copyright madmurphy (partially)
# @see https://stackoverflow.com/a/59592881/5113030
#
Shell_Execute()
{
    # Options
    # --------------------------------

    declare args; Options args \
        '?-o' \
        "$@" \
    || return $?;

    declare __ref="${args[0]}";
    declare __scripts=( "${args[@]:1}" );

    unset args;

    # ----------------

    if [[ "$__ref" != '' ]];
    then
        if [[
            "$__ref" == 'Shell_Execute_refOut' ||
            "$__ref" == 'Shell_Execute_refOutStdOut' ||
            "$__ref" == 'Shell_Execute_refOutStdErr'
        ]];
        then
            Misc_PrintF -n -- '[Shell_Execute] Output variable reference interference';

            return 100;
        fi

        declare -n Shell_Execute_refOut="$__ref";
        declare -n Shell_Execute_refOutStdOut="${__ref}StdOut";
        declare -n Shell_Execute_refOutStdErr="${__ref}StdErr";
        Shell_Execute_refOut=();
        Shell_Execute_refOutStdOut=();
        Shell_Execute_refOutStdErr=();
    fi

    # Main
    # --------------------------------

    if [[ ${#__scripts[@]} == 0 ]];
    then
        O -nt 'f' $'No script declared to start process';

        return 1;
    fi

    declare scriptIndex;

    for (( scriptIndex = 0; scriptIndex < ${#__scripts[@]}; scriptIndex++ ));
    do
        declare script="${__scripts[scriptIndex]}";
        declare Shell_Execute_shellOptionsTemp;
        Shell_Options -sro Shell_Execute_shellOptionsTemp;
        set +e;
        declare stdoutTemp;
        declare stderrTemp;

        {
            IFS=$'\n' read -rd '' stdoutTemp;
            IFS=$'\n' read -rd '' stderrTemp;

            Shell_Execute_refOutStdOut+=( "$stdoutTemp" );
            Shell_Execute_refOutStdErr+=( "$stderrTemp" );

            (
                declare exitCode;
                IFS=$'\n' read -rd '' exitCode;

                return "$exitCode";
            );
        } < <(
            (
                printf '\0%s\0%d\0' "$(
                    (
                        (
                            (
                                {
                                    bash -c "${script} & wait -- \$!";
                                    printf '%s\n' "$?" 1>&3-;
                                } | tr -d '\0' 1>&4-;
                            ) 4>&2- 2>&1- | tr -d '\0' 1>&4-;
                        ) 3>&1- | exit "$( cat; )";
                    ) 4>&1-;
                )" "$?" 1>&2;
            ) 2>&1;
        );

        declare exitCode="$?";
        Shell_Execute_refOut+=( "$exitCode" );
        Shell_Options -lf "$Shell_Execute_shellOptionsTemp";

        # O -nt 'd' -f $'Code %s/%s execution ended%s: code %s; stdout length: %s; stderr length: %s.' \
        #     "$(( scriptIndex + 1 ))" "${#__scripts[@]}" \
        #     "$( [ "${#__scripts[@]}" != 1 ] && printf ' (raw; %s of %s)' "$((scriptIndex + 1))" "${#__scripts[@]}" )" \
        #     "$exitCode" \
        #     "${#stdoutTemp}" \
        #     "${#stderrTemp}";
    done

    # If a single script was executed
    if [[ ${#__scripts[@]} == 1 ]];
    then
        return "${Shell_Execute_refOut[0]}";
    fi

    # If any exit status code is not 0
    if [[ "$( Misc_ArrayItemsCount '0' "${Shell_Execute_refOut[@]}" )" != "${#__scripts[@]}" ]];
    then
        return 1;
    fi

    return 0;
}

# Execute shell, shell command, or command as UID and/or GID.
#
# @todo Should we add Bash option '-i' for "interactive"?
#
# 'sudo -i' - Resets Shell options, sets User to their HOME directory also etc.
# 'bash -l' - Loads User profile files (e.g. ~/.profile) etc.
#
# > -i, --login - Run the shell specified by the target user's password database entry as a login shell. This means that login-specific resource
# > files such as .profile, .bash_profile, or .login will be read by the shell.  If a command is specified, it is passed to the shell as a simple
# > command using the -c option.  The command and any arguments are concatenated, separated by spaces, after escaping each character (including
# > white space) with a backslash (‘\’) except for alphanumerics, underscores, hyphens, and dollar signs.  If no command is specified, an interactive
# > shell is executed.  sudo attempts to change to that user's home directory before running the shell.  The command is run with an environment
# > similar to the one a user would receive at log in.  Note that most shells behave differently when a command is specified as compared to an
# > interactive session; consult the shell's manual for details.  The Command environment section in the sudoers(5) manual documents how the -i
# > option affects the environment in which a command is run when the sudoers policy is in use.
# Source: `man sudo` (`v1.9.9`)
#
# > l - Make bash act as if it had been invoked as a login shell...
# > A login shell is one whose first character of argument zero is a -, or one started with the --login option...
# > When bash is invoked as an interactive login shell, or as a non-interactive shell with the --login option, it first reads and executes commands
# > from the file /etc/profile, if that file  exists. After  reading that file, it looks for ~/.bash_profile, ~/.bash_login, and ~/.profile, in
# > that order, and reads and executes commands from the first one that exists and is readable.
# Source: `man bash` (`v5.1.16`)
#
# Please beware of "profile" and "rc" files.
#
# > The behaviour, in short, is as follows:
# >
# > - bash started as an interactive login shell: reads ~/.profile
# > - bash started as an interactive non-login shell: reads ~/.bashrc...
# >
# > Some explanation of the terminology:
# >
# > - An interactive shell is a shell with which you can interact, that means you can type commands in it. Most shells you will
# >   use are interactive shells.
# > - A non-interactive shell is a shell with which you cannot interact. Shell scripts run inside non-interactive shells.
# > - A login shell is the shell which is started when you login to your system.
# > - A non-login shell is a shell which is started after the login process...
# >
# > If bash is started as a login shell it will first look for `~/.bash_profile` before looking for `~/.profile`. If bash finds
# > `~/.bash_profile` then it will not read `~/.profile`.
#
# Source: https://askubuntu.com/a/132319/449016
# @see http://www.gnu.org/software/bash/manual/bashref.html#Bash-Startup-Files
#
# When a User is created via `useradd` or `adduser` for example, depending on the shell (i.e. `-s`),
# corresponding "skeleton" ("skel") files may be created in the Home directory of the User (e.g. copied from "/etc/skel").
# For example, in case of User `shell` set to '/bin/bash', "~/.bashrc" file may be created in the directory.
# Yet, if shell of new User is '/sbin/nologin', no such file should be created.
#
# > ~/.profile: executed by the command interpreter for login shells.
# > This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# > exists.
# > see /usr/share/doc/bash/examples/startup-files for examples.
# > the files are located in the bash-doc package.
# Source: `~/.profile`.
#
# > ~/.bashrc: executed by bash(1) for non-login shells.
# > see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# > for examples
# >
# > If not running interactively, don't do anything...
# Source: `~/.bashrc`.
#
# > Traditionally, when you log into a Unix system, the system would start one program for you. That program is a shell, i.e.,
# > a program designed to start other programs. It's a command line shell: you start another program by typing its name.
# > The default shell, a Bourne shell, reads commands from ~/.profile when it is invoked as the login shell.
# >
# > Bash is a Bourne-like shell. It reads commands from ~/.bash_profile when it is invoked as the login shell, and if that file
# > doesn't exist¹, it tries reading ~/.profile instead.
# >
# > You can invoke a shell directly at any time, for example by launching a terminal emulator inside a GUI environment. If the
# > shell is not a login shell, it doesn't read ~/.profile. When you start bash as an interactive shell (i.e., not to run a
# > script), it reads ~/.bashrc (except when invoked as a login shell, then it only reads ~/.bash_profile or ~/.profile.
#
# Source: https://superuser.com/questions/183870/difference-between-bashrc-and-bash-profile
#
# > The issue is that Terminal creates login shells, and Bash login shells only run the login startup script, not ~/.bashrc.
# > However, the solution isn't to simply place your .bashrc content into the login startup file, because these two files are
# > intended to perform different types of setup. Instead, the canonical setup for Bash is to have your ~/.bash_profile source
# > your ~/.bashrc at some appropriate point in the script (usually last).
#
# Source: https://apple.stackexchange.com/questions/12993/why-doesnt-bashrc-run-automatically#comment264198_13014
#
# @see https://www.computernetworkingnotes.com/linux-tutorials/how-to-change-default-umask-permission-in-linux.html
# @see https://askubuntu.com/questions/971836/at-what-point-is-the-bashrc-file-created
# @see https://unix.stackexchange.com/questions/38175/difference-between-login-shell-and-non-login-shell
# @see https://serverfault.com/questions/392551/what-is-the-difference-between-sudo-i-and-sudo-bash-l
# @see https://unix.stackexchange.com/questions/418979/sudo-u-not-getting-path-appended-in-home-profile
# @see https://unix.stackexchange.com/questions/35338/su-vs-sudo-s-vs-sudo-i-vs-sudo-bash
# @see https://unix.stackexchange.com/questions/129143/what-is-the-purpose-of-bashrc-and-how-does-it-work
# @see https://unix.stackexchange.com/questions/119627/why-are-interactive-shells-on-osx-login-shells-by-default/119675#119675
# @see https://superuser.com/questions/183870/difference-between-bashrc-and-bash-profile
#
Shell_ExecuteAs() {
    # Options
    # --------------------------------

    declare args argsC; Options args '11' \
        '/0/^(?:0|[1-9][0-9]*)$' \
        '/1/^(?:0|[1-9][0-9]*)$' \
        '/5' \
        '//5?' '/bin/bash' \
        '!?--uid:-u;?--gid:-g;?--command:-c;?--script:-s;?--file:-f;?--shell:-S;--login:-l' \
        "$@" \
    || return $?;

    declare __uid="${args[0]}";
    declare __gid="${args[1]}";
    declare __command="${args[2]}";
    declare __scriptFilepath="${args[3]}";
    declare __filepath="${args[4]}";
    declare __shell="${args[5]}";
    declare __login="${args[6]}";
    declare __items=( "${args[@]:7}" );
    unset args;

    # ----------------

    # @todo Remove the explicit group setting. `sudo` sets the primary by default.
    if [[ "$__gid" == '' ]];
    then
        declare __gid="$__uid";
    fi

    # Main
    # --------------------------------

    declare sudoCommandOptions=();
    declare commandOptions=();

#    # If "login"
#    if (( __login ));
#    then
#        sudoCommandOptions+=( '-i' );
#    fi

    # If shell command
    if (( argsC[2] ));
    then
        # echo 'Shell command';

        # If shell is not available
        if [[ ! -x "$__shell" ]];
        then
            return 2;
        fi

#        sudoCommandOptions+=( '-s' "$__shell" );
        commandOptions+=( "$__shell" );

        if (( __login ));
        then
            sudoCommandOptions+=( '-i' );
            commandOptions+=( '-l' );
        fi

        commandOptions+=( '-c' "$__command" "$__shell" "${__items[@]}" );
        # set -x;

        sudo -nHu "#${__uid}" -g "#${__gid}" "${sudoCommandOptions[@]}" -- "${commandOptions[@]}" || \
            return $?;

        # set +x;

        return 0;
    fi

    unset argsC;

    # If script or any file
    if [[ "$__scriptFilepath" != '' || "$__filepath" != '' ]];
    then
        # If shell script
        if [[ "$__scriptFilepath" != '' ]];
        then
            # echo 'File: Script';

            # If script or shell is not available
            if [[ ! -f "$__scriptFilepath" || ! -x "$__shell" ]];
            then
                return 2;
            fi

            sudoCommandOptions+=( '-s' "$__shell" );
            commandOptions+=( "$__shell" );

            if (( __login ));
            then
                commandOptions+=( '-l' );
            fi

            commandOptions+=( -- "$__scriptFilepath" "${__items[@]}" );
        else
            # echo 'File: Other';

            # If file is not available
            if [[ ! -f "$__filepath" ]];
            then
                return 2;
            fi

            commandOptions+=( "$__filepath" "${__items[@]}" );
        fi

        # set -x;

        sudo -nHu "#${__uid}" -g "#${__gid}" "${sudoCommandOptions[@]}" -- "${commandOptions[@]}" || \
            return $?;

        # set +x;

        return 0;
    fi

    # Set of commands (temporary script)

    # echo 'Set of shell commands';
    # set -x;

    # If shell is not available
    if [[ ! -x "$__shell" ]];
    then
        return 2;
    fi

    sudoCommandOptions+=( '-s' "$__shell" );
#    commandOptions+=( "$__shell" );

#    if (( __login ));
#    then
#        commandOptions+=( '-l' );
#    fi

    declare tempFilepath; tempFilepath="$( mktemp; )";

    {
#         printf -- '%s\n\n' '#! /usr/bin/env bash' > "$tempFilepath";
        printf -- '#! %s\n\n' "$__shell";
        printf -- '%s ' "${__items[@]}";
        printf -- '\n';
    } \
        > "$tempFilepath";

    sudo chown -- "${__uid}:${__gid}" "$tempFilepath";
    sudo chmod -- 700 "$tempFilepath";

    ls -la -- "$tempFilepath";
    sudo cat -- "$tempFilepath";

    commandOptions+=( "$tempFilepath" );

    declare exitCode=0;
    # set -x;

    sudo -nHu "#${__uid}" -g "#${__gid}" "${sudoCommandOptions[@]}" -- "${commandOptions[@]}" || \
        declare exitCode="$?";

    # set +x;

    sudo rm -f -- "$tempFilepath";

    return "$exitCode";
}
