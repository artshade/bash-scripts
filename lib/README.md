# Bash General Libraries

## "`Options`"

"`Options`" library may be used to process [indexed options](https://www.gnu.org/software/bash/manual/html_node/Shell-Scripts.html) passed to a function or script.
A successful result is set to a [named variable](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameters.html) ("`${reference}`") and represents an ordered array with processed options containing arguments based on option patterns provided respectively.

Library filepath: `./options.lib.sh`.

### Function Parameters

```bash
Options \
    ${resultVariableReference} \
    [${switches}] \
    [${validations},...] \
    [${replacements},...] \
    ${pattern} \
    "$@";
```

### Basic Example

```bash
example()
{
    declare args; Options args '?--abc;?-d;-e;-f' "$@";
    declare -p "args";
    unset args;
}

example 1 --abc '2 3' 4 5 -d 6 -ee 7 8 -- -f 9;
```

### Features

---

#### Switches

Switches alter behavior of option processing.

| Switch Index | Default | Description                                                                   |
|--------------|---------|-------------------------------------------------------------------------------|
| 1            | 1       | "Show error message on option parse fail"                                     |
| 2            | 0       | "Set global option count variable (`${reference}C`)"                          |
| 3            | 0       | "Set global option total count variable (`${reference}T`)"                    |
| 4            | 0       | "Arguments with prefix `-`"                                                   |
| 5            | 0       | "Options without prefix `-`"                                                  |
| 6            | 1       | "Combined short options with a leading '=' character and joined argument"     |
| 7            | 1       | "Options combined with values"                                                |
| 8            | 1       | "Combined short options"                                                      |
| 9            | 1       | "Empty arguments"                                                             |
| 10           | 1       | "Empty values"                                                                |
| 11           | 1       | "Arguments prefixed with `-` character"                                       |
| 12           | 1       | "Arguments right after `=` character prefixed with `-` character"             |
| 13           | 1       | "Option argument RegEx rule count must be less or equal option pattern count" |
| 14           | 0       | "Skip to the next pattern after the first argument occurrence"                |
| 15           | 0       | "Skip to the next pattern after the first flag occurrence"                    |
| 16           | 1       | "Prefix `-` character while splitting short options"                          |
| 17           | 1       | "Show error message more verbose details"                                     |

#### Validation and Replacement

Both validation and replacement of flag and parameter options are supported based on conditions and [Perl regex features](https://www.regular-expressions.info/perl.html).

##### Validation

Option pattern prefix: `/`.  
Rule syntax: `'/${scope}${modes}/${regex}'`.

> |     | Rule         | Scope                     | Condition                                   |
> |-----|--------------|---------------------------|---------------------------------------------|
> | 1.1 | `/3?/[a-z]+` | Option at index 3         | May be empty; non-empty must match `[a-z]+`. |
> | 1.2 | `/2/[a-z]+`  | Option at index 2         | Must not be empty; must match `[a-z]+`.      |
> | 1.3 | `/1?`        | Option at index 1         | May be empty.                               |
> | 1.4 | `/0`         | Option at index 0         | Must not be empty.                          |
> | 1.5 | `/?/[a-z]+`  | All options without rules | May be empty; non-empty must match `[a-z]+`. |
> | 1.6 | `/[a-z]+`    | All options without rules | Must not be empty; must match `[a-z]+`.      |
> | 1.7 | `/?`         | All options without rules | May be empty.                               |
> | 1.8 | `/`          | All options without rules | Must not be empty                           |

##### Replacement

Option pattern prefix: `//`.  
Rule syntax: `'//${scope}${modes}/${regex}' 'replacement'`.

> |     | Rule                  | Scope                     | Condition                  |
> |-----|-----------------------|---------------------------|----------------------------|
> | 2.1 | `//3?/[a-z]+ 'value'` | Option at index 3         | Unset or matches `[a-z]+`. |
> | 2.2 | `//2/[a-z]+ 'value'`  | Option at index 2         | Matches `[a-z]+`.          |
> | 2.3 | `//1? 'value'`        | Option at index 1         | Unset or empty.            |
> | 2.4 | `//0 'value'`         | Option at index 0         | Empty.                     |
> | 2.5 | `//?/[a-z]+ 'value'`  | All options without rules | Unset or matches `[a-z]+`. |
> | 2.6 | `///[a-z]+ 'value'`   | All options without rules | Matches `[a-z]+`.          |
> | 2.7 | `//? 'value'`         | All options without rules | Unset or empty.            |
> | 2.8 | `// 'value'`          | All options without rules | Empty.                     |

> [!NOTE]
>
> 1. Replacements are literal currently, and do not support regex capture groups.
> 2. Rule `2.6` has prefix `///` due to how validation rule operates on `//[a-z]+` and sets regex `/[a-z]+`.

### Environment Variables

| Exit Status       | Values   | Default | Description      |
|-------------------|----------|---------|------------------|
| LIB_OPTIONS_DEBUG | `[01]`   | 0       | Enable debugging |

### Exit Statuses

| Exit Status | Description                                                         |
|-------------|---------------------------------------------------------------------|
| 1           | "Pattern duplicate"                                                 |
| 2           | "Encountered value prefixed with `-` character"                     |
| 3           | "Encountered empty argument"                                        |
| 4           | "Unknown option"                                                    |
| 5           | "Encountered pattern not prefixed with `-`"                         |
| 6           | "Empty pattern"                                                     |
| 7           | "Encountered value for flag"                                        |
| 8           | "Argument not found"                                                |
| 9           | "Encountered value prefixed with `-` character after `=` character" |
| 10          | "Too many switches"                                                 |
| 11          | "Encountered option combined with its possible value"               |
| 12          | "Encountered empty value for flag after `=` character"              |
| 13          | "Encountered `--` pattern"                                          |
| 14          | "Too few function arguments"                                        |
| 15          | "Required option not found"                                         |
| 16          | "Invalid validation expression"                                     |
| 17          | "Validation expression duplicate"                                   |
| 18          | "Validation rule count overflow"                                    |
| 19          | "Invalid argument"                                                  |
| 20          | "Empty pattern variant"                                             |
| 21          | "Encountered `-` option"                                            |
| 22          | "Output variable reference interference"                            |
| 23          | "Replacement rule count overflow"                                   |
| 24          | "Replacement rule index overflow"                                   |
| 25          | "Replacement expression duplicate"                                  |
| 26          | "Invalid replacement expression"                                    |
| 27          | "Invalid rule format"                                               |
| 28          | "Invalid replacement for flag"                                      |

### Examples

---

#### Example 1

```bash
#! /usr/bin/env bash

set -eu;

# Initials
# ----------------------------------------------------------------

declare _sourceFilepath; _sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )"; readonly _sourceFilepath;
declare _sourceDirpath; _sourceDirpath="$( dirname -- "$_sourceFilepath" 2> '/dev/null'; )"; readonly _sourceDirpath;

[[ ! -f "$_sourceFilepath" || ! -d "$_sourceDirpath" ]] && exit 99;

# Libraries
# ----------------------------------------------------------------

{ [[ -d "${_sourceDirpath}/lib" ]] && export SHELL_LIBS_DIRPATH="${_sourceDirpath}/lib"; [[ -d "${SHELL_LIBS_DIRPATH-}" ]]; } || exit 98;

# shellcheck disable=SC1091
[[ "${SHELL_LIB_OPTIONS:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/options.lib.sh" && [[ "${SHELL_LIB_OPTIONS:+s}" != '' ]] || exit 97; };

# ----------------------------------------------------------------
# ////////////////////////////////////////////////////////////////

main()
{
    # Options 
    # --------------------------------

    declare args argsC; Options args '11' '/' \
        '//?/[a-z]+' '' \
        '?-a;?-b;?-c;-d' \
        "$@" \
    || return $?;

    declare __oA="${args[0]}";
    declare __oB="${args[1]}";
    declare __oC="${args[2]}";
    declare __oD="${args[3]}";
    declare __items=( "${args[@]:4}" );
    unset args;

    # ----------------

    printf -- '\n';
    printf -- $' - oA (%s): \'%s\'\n' "${argsC[0]}" "$__oA";
    printf -- $' - oB (%s): \'%s\'\n' "${argsC[1]}" "$__oB";
    printf -- $' - oC (%s): \'%s\'\n' "${argsC[2]}" "$__oC";
    printf -- $' - oD (%s): \'%s\'\n' "${argsC[3]}" "$__oD";
    printf -- '\n';

    if [[ "${#__items[@]}" == 0 ]];
    then
        return 0;
    fi

    printf -- $' Items:\n';
    printf -- $'- \'%s\'\n' "${__items[@]}";
    printf -- '\n';

    return 0;
}

main "$@";
```
