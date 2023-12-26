#! /usr/bin/env bash

set -eu;

# Initials
# ----------------------------------------------------------------

declare _Docker_sourceFilepath; _Docker_sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )"; readonly _Docker_sourceFilepath;
declare _Docker_sourceDirpath; _Docker_sourceDirpath="$( dirname -- "$_Docker_sourceFilepath" 2> '/dev/null'; )"; readonly _Docker_sourceDirpath;

[[ ! -f "$_Docker_sourceFilepath" || ! -d "$_Docker_sourceDirpath" ]] && exit 99;

# Libraries
# ----------------------------------------------------------------

export SHELL_LIBS_DIRPATH="$_Docker_sourceDirpath"; [[ -d "$SHELL_LIBS_DIRPATH" ]] || exit 98;

# shellcheck disable=SC1091
[[ "${SHELL_LIB_OPTIONS:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/options.lib.sh" && [[ "${SHELL_LIB_OPTIONS:+s}" != '' ]] || exit 97; };
# shellcheck disable=SC1091
[[ "${SHELL_LIB_MISC:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/misc.lib.sh" && [[ "${SHELL_LIB_MISC:+s}" != '' ]] || exit 97; };

# shellcheck disable=SC2034
declare -r SHELL_LIB_DOCKER="$_Docker_sourceFilepath";

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

Docker_ContainerId()
{

    # Options
    # --------------------------------

    declare args; Options args \
        '--service:-s;--running:-r' \
        "$@" \
    || return $?;

    declare __service="${args[0]}";
    declare __running="${args[1]}";
    declare __items=( "${args[@]:2}" );

    # Main
    # --------------------------------

    # shellcheck disable=SC2124
    declare containerName="${__items[@]:0:1}";

    if [[ "$containerName" == '' ]];
    then
        return 2;
    fi

    declare dockerCommandOptions=( '-a' );

    if (( __running ));
    then
        dockerCommandOptions+=( --filter 'status=running' );
    fi

    declare containerId;

    if (( __service ));
    then
        declare containerId; containerId="$(
            docker compose ps "${dockerCommandOptions[@]}" --format 'table {{.ID}} {{.Service}}' | tail -n +2 \
                | grep -- "\s${containerName}\$" \
                | cut -d ' ' -f 1 || \
                return 1;
        )";

        if [[ ! "$containerId" =~ ^[0-9a-f]{64}$ ]];
        then
            return 1;
        fi

        printf '%s' "$containerId";

        return 0;
    fi

    declare containerId; containerId="$(
        docker ps --no-trunc "${dockerCommandOptions[@]}" --format 'table {{.ID}} {{.Names}}' | tail -n +2 \
            | grep -- "\s${containerName}\$" \
            | cut -d ' ' -f 1 || \
            return 1;
    )";

    if [[ ! "$containerId" =~ ^[0-9a-f]{64}$ ]];
    then
        return 1;
    fi

    printf '%s' "$containerId";

    return 0;
}

Docker_ContainerName()
{
    # Options
    # --------------------------------

    declare args; Options args \
        '--service:-s;--running:-r' \
        "$@" \
    || return $?;

    declare __service="${args[0]}";
    declare __running="${args[1]}";
    declare __items=( "${args[@]:2}" );

    # Main
    # --------------------------------

    # shellcheck disable=SC2124
    declare containerId="${__items[@]:0:1}";

    if [[ ! "$containerId" =~ ^[0-9a-f]{64}$ ]];
    then
        return 2;
    fi

    declare dockerCommandOptions=( '-a' );

    if (( __running ));
    then
        dockerCommandOptions+=( --filter 'status=running' );
    fi

    declare containerName;

    if (( __service ));
    then
        declare containerName; containerName="$(
            docker compose ps "${dockerCommandOptions[@]}" --format 'table {{.ID}} {{.Service}}' | tail -n +2 \
                | grep -- "^${containerId}\s" \
                | sed -e 's/^.*\s//' || \
                return 1;
        )";

        if [[ "$containerName" == '' ]];
        then
            return 1;
        fi

        printf '%s' "$containerName";

        return 0;
    fi

    declare containerName; containerName="$(
        docker ps --no-trunc "${dockerCommandOptions[@]}" --format 'table {{.ID}} {{.Names}}' | tail -n +2 \
            | grep -- "^${containerId}\s" \
            | sed -e 's/^.*\s//' || \
            return 1;
    )";

    if [[ "$containerName" == '' ]];
    then
        return 1;
    fi

    printf '%s' "$containerName";

    return 0;
}

Docker_IsContainer()
{
    # Options
    # --------------------------------

    declare args; Options args \
        '--running:-r;--service:-s;--name:-n' \
        "$@" \
    || return $?;

    declare __running="${args[0]}";
    declare __service="${args[1]}";
    declare __name="${args[2]}";
    declare __items=( "${args[@]:3}" );

    # Main
    # --------------------------------

    # shellcheck disable=SC2124
    declare container="${__items[@]:0:1}";

    if [[ "$container" == '' ]];
    then
        return 2;
    fi

    declare containerCommandOptions=();

    if (( __running ));
    then
        containerCommandOptions+=( '-r' );
    fi

    if (( __service ));
    then
        containerCommandOptions+=( '-s' );
    fi

    if (( __name ));
    then
        if Docker_ContainerId "${containerCommandOptions[@]}" -- "$container" &> '/dev/null';
        then
            return 0;
        fi

        return 1;
    fi

    if Docker_ContainerName "${containerCommandOptions[@]}" -- "$container" &> '/dev/null';
    then
        return 0;
    fi

    return 1;
}

# @todo Add support for creating containers/services (e.g. option '--create:-N').
Docker_Execute()
{
    # Options
    # --------------------------------

    declare args; Options args \
        '/0' \
        '/2/^(?:0|[1-9][0-9]*)(?:\:(?:0|[1-9][0-9]*))?$' \
        '/3' \
        '/4' \
        '//2?' '0:0' \
        '//6?' '/bin/bash' \
        '?--container:-n;?--service:-N;?--user:-u;?--command:-c;?--script:-s;?--file:-f;?--shell:-S;?--env:-e;--login:-l;--run:-r;--build:-b' \
        "$@" \
    || return $?;

    declare __containerName="${args[0]}";
    declare __serviceName="${args[1]}";
    declare __user="${args[2]}";
    declare __command="${args[3]}";
    declare __scriptFilepath="${args[4]}";
    declare __filepath="${args[5]}";
    declare __shell="${args[6]}";
    declare __environmentVariablesRef="${args[7]}";
    declare __login="${args[8]}";
    declare __run="${args[9]}";
    declare __build="${args[10]}";
    declare __items=( "${args[@]:11}" );

    # Main
    # --------------------------------

    declare isService=0;
    declare name;

    if [[ "$__serviceName" != '' ]];
    then
        declare isService=1;
        declare name="$__serviceName";
    else
        # @todo Add support for running containers based on image.
        #
        # If trying to run a container based on image (not a service).
        if (( __run ));
        then
            return 2;
        fi

        declare name="$__containerName";
    fi

    # If both container and service name are set or both unset
    if [[  "$name" == '' ]];
    then
        return 2;
    fi

    # User
    # ----------------

    declare execOptions=(
        '-u' "$__user"
    );

    # Container (target)
    # ----------------

    declare container="$name";
    declare isContainerCommandOptions=();

    if (( isService ));
    then
        # 'docker-compose' accepts service names only.
        isContainerCommandOptions+=( '-sn' );
    fi

    if ! Docker_IsContainer "${isContainerCommandOptions[@]}" -- "$name";
    then
        return 1;
    fi

    declare containerId='';
    declare serviceName='';

    if (( isService ));
    then
        declare serviceName="$name";
    else
        declare containerId="$name";
    fi

    if [[ "$containerId" == '' ]];
    then
        declare containerId; containerId="$( Docker_ContainerId -s -- "$name" || :; )";

        if [[ "$containerId" == '' ]];
        then
            return 1;
        fi
    else
        declare serviceName; serviceName="$( Docker_ContainerName -s -- "$name" || :; )";

        if [[ "$serviceName" == '' ]];
        then
            return 1;
        fi
    fi

    # Environment variables
    # ----------------

    if [[ "$__environmentVariablesRef" != '' ]];
    then
        declare -n envVarsRef="$__environmentVariablesRef";

        if ! Misc_IsVarOfType 'assoc_array' envVarsRef;
        then
            O -np :2 -t e -f $'Invalid environment variables reference: \'%s\'' -- "$__environmentVariablesRef";

            return 2;
        fi

        declare envVarName;

        for envVarName in "${!envVarsRef[@]}";
        do
            declare envVarValue="${envVarsRef[$envVarName]}";
            execOptions+=( '-e' "${envVarName}=${envVarValue}" );
        done
    fi

    # Docker or Docker Compose
    # ----------------

    declare mainCommand=( 'docker' );

    if (( isService ));
    then
        declare mainCommand+=( 'compose' );
    fi

    # "exec" (in running) or "run" (create a new)
    # ----------------

    declare execName;

    if Docker_IsContainer -r -- "$containerId";
    then
        mainCommand+=( 'exec' );

        if (( isService ));
        then
            declare execName="$serviceName";
        else
            declare execName="$containerId";
        fi
    else
        if (( ! __run || ! isService ));
        then
            return 1;
        fi

        mainCommand+=( 'run' );

        # If auto-remove started container
        if (( __run > 1 ));
        then
            mainCommand+=( '--rm' '--service-ports' '--use-aliases' ); # '--name' "$serviceName"
        fi

        if (( __build ));
        then
            mainCommand+=( '--build' );
        fi

        declare execName="$serviceName";
    fi

    # Command (shell command, script or file, or set of commands (temporary script))
    # ----------------

    declare shellOptions; shellOptions=();

    # If shell command
    if [[ "$__command" != '' ]];
    then
#        # If shell is not available
#        if [[ ! -x "$__shell" ]];
#        then
#            return 2;
#        fi

        shellOptions+=( "$__shell" );

        if (( __login ));
        then
            shellOptions+=( '-l' );
        fi

        # The reason of the option "shell" after command:
        # > -c - Read and execute commands from the first non-option argument command_string, then exit.
        # > If there are arguments after the command_string, the first argument is assigned to $0 and
        # > any remaining arguments are assigned to the positional parameters. The assignment to $0 sets
        # > the name of the shell, which is used in warning and error messages.
        # Source: `man bash`
        shellOptions+=( '-c' "$__command" "$__shell" "${__items[@]}" );

        "${mainCommand[@]}" "${execOptions[@]}" -- "$execName" "${shellOptions[@]}" || \
            return $?;

        return 0;
    fi

    # @todo Add support for non-service containers (i.e. mountable scripts/files).
    #
    # If script or any file
    # @see https://docs.docker.com/engine/reference/commandline/cp
    #
    if [[ "$__scriptFilepath" != '' || "$__filepath" != '' ]];
    then
        if (( ! isService ));
        then
            return 2;
        fi

        declare commandOptions; commandOptions=();
        declare filepath;
        declare scriptFile=0;
        declare randomFilename; randomFilename="$( Misc_RandomString -l 16; )";
        declare tempFilepath="/tmp/${randomFilename}";

        # If shell script
        if [[ "$__scriptFilepath" != '' ]];
        then
            # If script or shell is not available
            if [[ ! -f "$__scriptFilepath" ]]; # || ! -x "$__shell"
            then
                return 2;
            fi

            declare scriptFile=1;
            declare filepath="$__scriptFilepath";

            # docker cp or docker compose cp
            # or (-v) for running?

#            execOptions+=( '-v' "${__scriptFilepath}:/tmp/" );

#            sudoCommandOptions+=( '-s' "$__shell" );
            shellOptions+=( "$__shell" );

            if (( __login ));
            then
                shellOptions+=( '-l' );
            fi

            shellOptions+=( -- );
            commandOptions+=( "$tempFilepath" "${__items[@]}" );
        else
            # If file is not available
            if [[ ! -f "$__filepath" ]];
            then
                return 2;
            fi

            declare filepath="$__filepath";
            commandOptions+=( "$tempFilepath" "${__items[@]}" );
        fi

        docker compose cp -- "$filepath" "${serviceName}:${tempFilepath}";
        docker compose exec -u '0:0' -- "$serviceName" '/bin/bash' -c 'chown -- "$2" "$1" && chmod -- o+x "$1"; cat "$1"; ls -la "$1";' - "$tempFilepath" "$__user";
        docker compose exec "${execOptions[@]}" -- "$serviceName" "${shellOptions[@]}" "${commandOptions[@]}";

#        sudo -nHu "#${__uid}" -g "#${__gid}" "${sudoCommandOptions[@]}" -- "${commandOptions[@]}" || \
#            return $?;

        # set +x;

        return 0;
    fi

    # Set of commands

    "${mainCommand[@]}" "${execOptions[@]}" -- "$serviceName" "${__items[@]}" || \
        return $?;

    return 0;
}
