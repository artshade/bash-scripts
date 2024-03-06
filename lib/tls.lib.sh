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

declare _TLS_sourceFilepath; _TLS_sourceFilepath="$( readlink -fn -- "${BASH_SOURCE[0]:-$0}" 2> '/dev/null'; )"; readonly _TLS_sourceFilepath;
declare _TLS_sourceDirpath; _TLS_sourceDirpath="$( dirname -- "$_TLS_sourceFilepath" 2> '/dev/null'; )"; readonly _TLS_sourceDirpath;

[[ ! -f "$_TLS_sourceFilepath" || ! -d "$_TLS_sourceDirpath" ]] && exit 99;

# Libraries
# ----------------------------------------------------------------

export SHELL_LIBS_DIRPATH="$_TLS_sourceDirpath"; [[ -d "$SHELL_LIBS_DIRPATH" ]] || exit 98;

# shellcheck disable=SC1091
[[ "${SHELL_LIB_OPTIONS:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/options.lib.sh" && [[ "${SHELL_LIB_OPTIONS:+s}" != '' ]] || exit 97; };
# shellcheck disable=SC1091
[[ "${SHELL_LIB_MISC:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/misc.lib.sh" && [[ "${SHELL_LIB_MISC:+s}" != '' ]] || exit 97; };
# shellcheck disable=SC1091
[[ "${SHELL_LIB_UI:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/ui.lib.sh" && [[ "${SHELL_LIB_UI:+s}" != '' ]] || exit 97; };
# shellcheck disable=SC1091
[[ "${SHELL_LIB_TEMPLATE:+s}" == '' ]] && { . "${SHELL_LIBS_DIRPATH}/template.lib.sh" && [[ "${SHELL_LIB_TEMPLATE:+s}" != '' ]] || exit 97; };

# shellcheck disable=SC2034
declare -r SHELL_LIB_TLS="$_TLS_sourceFilepath";

# Functions
# ----------------------------------------------------------------

TLS_SSLGenerateConfig()
{
    # --------------------------------
    # Options
    # --------------------------------

    declare args; _options args '/' \
        '!?-o;!?-t;!?-c;!?--ca-subject-o;!?--ca-subject-ou;!?--ca-subject-cn;!?--subject-cn;!?--subject-c;!?--subject-st;!?--subject-l;!?--subject-o;!?--subject-ou;!?--subject-ea' \
        "$@" \
    || return $?;

    declare __outputVariableReferenceName="${args[0]}";
    declare __tlsConfigTemplateDirpath="${args[1]}";
    declare __tlsConfigDirpath="${args[2]}";
    declare __tlsRootCASubjectOrganizationName="${args[3]}";
    declare __tlsRootCASubjectOrganizationUnitName="${args[4]}";
    declare __tlsRootCASubjectCommonName="${args[5]}";
    declare __tlsSubjectCommonName="${args[6]}";
    declare __tlsSubjectCountryName="${args[7]}";
    declare __tlsSubjectStateOrProvinceName="${args[8]}";
    declare __tlsSubjectLocalityName="${args[9]}";
    declare __tlsSubjectOrganizationName="${args[10]}";
    declare __tlsSubjectOrganizationUnitName="${args[11]}";
    declare __tlsSubjectEmailAddress="${args[12]}";

    # --------------------------------

    if [[ "$__outputVariableReferenceName" == 'TLS_SSLGenerateConfig_outputVariableReference' ]];
    then
        Misc_PrintF -v 1 -t 'f' -nf $'[TLS_SSLGenerateConfig] Output variable reference interference: \'%s\'' -- "$( Misc_ArrayJoin -- "$@" )";

        return 100;
    fi

    declare -n TLS_SSLGenerateConfig_outputVariableReference="$__outputVariableReferenceName";
    TLS_SSLGenerateConfig_outputVariableReference=();

    # --------------------------------
    # Main
    # --------------------------------
    # Locations
    # ----------------

    declare configCATemplateFilepath="${__tlsConfigTemplateDirpath}/openssl_ca.cnf.template";
    declare configTemplateFilepath="${__tlsConfigTemplateDirpath}/openssl.cnf.template";

    if [[ ! -f "$configCATemplateFilepath" || ! -f "$configTemplateFilepath" ]];
    then
        printf -- $'Could not generate TLS config files (no such template) in \'%s\'\n' "$__tlsConfigTemplateDirpath";

        return 1;
    fi

    declare tlsAlternateNames="$__tlsSubjectCommonName";

    if [[ "$__tlsSubjectCommonName" =~ ^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)$ ]];
    then
        declare tlsAlternateNames; tlsAlternateNames="$( printf -- 'DNS.1 = %s\nIP.1 = %s' "$__tlsSubjectCommonName" "$__tlsSubjectCommonName"; )";
    elif [[ "$__tlsSubjectCommonName" != '' ]];
    then
        declare tlsAlternateNames; tlsAlternateNames="$( printf -- 'DNS.1 = %s\nDNS.2 = \*.%s' "$__tlsSubjectCommonName" "$__tlsSubjectCommonName"; )";
    else
        printf -- 'Could not generate TLS config files (no common name set for TLS/SSL (e.g. FQDN or IPv4 address))\n';

        return 1;
    fi

    declare configCAFilepath="${__tlsConfigDirpath}/openssl_ca.cnf";
    declare configFilepath="${__tlsConfigDirpath}/openssl.cnf";

    printf -- 'Generating TLS/SSL config files\n';

    mkdir -p "$__tlsConfigDirpath";

    cp "$configCATemplateFilepath" "$configCAFilepath";
    printf -- '- ';

    Template_ValuesSet "${__tlsConfigDirpath}/openssl_ca.cnf" \
        'countryName' "$__tlsSubjectCountryName" \
        'stateOrProvinceName' "$__tlsSubjectStateOrProvinceName" \
        'localityName' "$__tlsSubjectLocalityName" \
        'organizationName' "$__tlsRootCASubjectOrganizationName" \
        'organizationUnitName' "$__tlsRootCASubjectOrganizationUnitName" \
        'commonName' "$__tlsRootCASubjectCommonName" \
        'emailAddress' "$__tlsSubjectEmailAddress";

    cp "$configTemplateFilepath" "$configFilepath";
    printf -- '- ';

    Template_ValuesSet "${__tlsConfigDirpath}/openssl.cnf" \
        'countryName' "$__tlsSubjectCountryName" \
        'stateOrProvinceName' "$__tlsSubjectStateOrProvinceName" \
        'localityName' "$__tlsSubjectLocalityName" \
        'organizationName' "$__tlsSubjectOrganizationName" \
        'organizationUnitName' "$__tlsSubjectOrganizationUnitName" \
        'commonName' "$__tlsSubjectCommonName" \
        'emailAddress' "$__tlsSubjectEmailAddress" \
        'alternateNames' "$tlsAlternateNames";

    # shellcheck disable=SC2034
    TLS_SSLGenerateConfig_outputVariableReference=(
        "$configCAFilepath"
        "$configFilepath"
    );
}

TLS_SSLGenerate()
{
    # --------------------------------
    # Options
    # --------------------------------

    declare args; _options args \
        '/4/^(?:0|[1-9][0-9]*)$' \
        '//4?' 256 \
        '!?-o;!?-p;!?-t;!?-c;?-P;!?--ca-subject-o;!?--ca-subject-ou;!?--ca-subject-cn;!?--subject-cn;!?--subject-c;!?--subject-st;!?--subject-l;!?--subject-o;!?--subject-ou;!?--subject-ea;-S;-r' \
        "$@" \
    || return $?;

    declare __outputVariableReferenceName="${args[0]}";
    declare __tlsRootCAKeyPassword="${args[1]}";
    declare __tlsConfigTemplateDirpath="${args[2]}";
    declare __tlsConfigDirpath="${args[3]}";
    declare __tlsRootCAKeyPasswordGenerateLength="${args[4]}";
    declare __tlsRootCASubjectOrganizationName="${args[5]}";
    declare __tlsRootCASubjectOrganizationUnitName="${args[6]}";
    declare __tlsRootCASubjectCommonName="${args[7]}";
    declare __tlsSubjectCommonName="${args[8]}";
    declare __tlsSubjectCountryName="${args[9]}";
    declare __tlsSubjectStateOrProvinceName="${args[10]}";
    declare __tlsSubjectLocalityName="${args[11]}";
    declare __tlsSubjectOrganizationName="${args[12]}";
    declare __tlsSubjectOrganizationUnitName="${args[13]}";
    declare __tlsSubjectEmailAddress="${args[14]}";
    declare __isTlsRootCAKeyPasswordSave="${args[15]}";
    declare __removeExisting="${args[16]}";

    # --------------------------------

    if [[ "$__outputVariableReferenceName" == 'TLS_SSLGenerate_outputVariableReference' ]];
    then
        Misc_PrintF -v 1 -t 'f' -nf $'[TLS_SSLGenerate] Output variable reference interference: \'%s\'' -- "$( Misc_ArrayJoin -- "$@" )";

        return 100;
    fi

    declare -n TLS_SSLGenerate_outputVariableReference="$__outputVariableReferenceName";
    TLS_SSLGenerate_outputVariableReference=();

    if [[ "$__tlsRootCAKeyPassword" == '' ]]
    then
        if (( __tlsRootCAKeyPasswordGenerateLength < 32 || __tlsRootCAKeyPasswordGenerateLength > 512 ));
        then
            printf -- $'Invalid TLS root CA key password generate length (32 <= x <= 512)\n';

            return 1;
        fi

        declare __tlsRootCAKeyPassword; __tlsRootCAKeyPassword="$( Misc_RandomString "$__tlsRootCAKeyPasswordGenerateLength"; )";
    fi

    # --------------------------------
    # Main
    # --------------------------------
    # Locations
    # ----------------

    declare tlsSSLConfigDirpath="${__tlsConfigDirpath}/config";
    declare tlsCADirpath="${__tlsConfigDirpath}/ca";
    declare tlsCAPrivateDirpath="${tlsCADirpath}/private";
    declare tlsCACertsDirpath="${tlsCADirpath}/certs";
    declare tlsHostDirpath="${__tlsConfigDirpath}/hosts/${__tlsSubjectCommonName}";
    declare tlsPrivateDirpath="${tlsHostDirpath}/private";
    declare tlsCertsDirpath="${tlsHostDirpath}/certs";
    declare tlsRequestDirpath="${tlsHostDirpath}/reqs";

    # Keys

    declare tlsRootCAPrivateKeyFilepath="${tlsCAPrivateDirpath}/root_ca-pk.pem";
    declare hostPrivateKeyFilepath="${tlsPrivateDirpath}/pk.pem";

    # Certificates

    declare hostX509CertFilepath="${tlsCertsDirpath}/c.pem";
    declare hostX509CertSignedFilepath="${tlsCertsDirpath}/sc.pem";

    # Certificate requests

    declare tlsCertRequestFilepath="${tlsRequestDirpath}/c.csr";

    # Passwords

    declare tlsRootCAPrivateKeyPasswordsFilepath="${tlsCADirpath}/.secret";

    # ----------------
    # Pre-start
    # ----------------

    if [[ -f "$hostPrivateKeyFilepath" && -f "$hostX509CertSignedFilepath" ]];
    then
        if [[ "$__removeExisting" == 0 ]];
        then
            TLS_SSLGenerate_outputVariableReference=(
                "$hostPrivateKeyFilepath"
                "$hostX509CertSignedFilepath"
            );

            return 0;
        fi

        if ! rm "$hostPrivateKeyFilepath";
        then
            printf -- $'Failed to remove the existing host private key: \'%s\'\n' "$hostPrivateKeyFilepath" >&2;

            return 1;
        elif ! rm "$hostX509CertSignedFilepath";
        then
            printf -- $'Failed to remove the existing signed certificate: \'%s\'\n' "$hostX509CertSignedFilepath" >&2;

            return 1;
        fi
    fi

    # ----------------
    # Generate
    # ----------------

    mkdir -p \
        "$tlsSSLConfigDirpath" \
        "$tlsCAPrivateDirpath" \
        "$tlsCACertsDirpath" \
        "$tlsPrivateDirpath" \
        "$tlsCertsDirpath" \
        "$tlsRequestDirpath";

    declare TLS_SSLGenerate_sslConfigs;

    TLS_SSLGenerateConfig -o TLS_SSLGenerate_sslConfigs \
        -t "$__tlsConfigTemplateDirpath" \
        -c "$tlsSSLConfigDirpath" \
        --ca-subject-o "$__tlsRootCASubjectOrganizationName" \
        --ca-subject-ou "$__tlsRootCASubjectOrganizationUnitName" \
        --ca-subject-cn "$__tlsRootCASubjectCommonName" \
        --subject-cn "$__tlsSubjectCommonName" \
        --subject-c "$__tlsSubjectCountryName" \
        --subject-st "$__tlsSubjectStateOrProvinceName" \
        --subject-l "$__tlsSubjectLocalityName" \
        --subject-o "$__tlsSubjectOrganizationName" \
        --subject-ou "$__tlsSubjectOrganizationUnitName" \
        --subject-ea  "$__tlsSubjectEmailAddress";

    declare caSubjectNameEscaped; caSubjectNameEscaped="$( Misc_Regex -is '\s' -r '_' "$__tlsRootCASubjectCommonName" 2> '/dev/null'; )";
    declare caSubjectNameEscaped; caSubjectNameEscaped="$( Misc_Regex -is '[^0-9A-Za-z_]' -r '' "$caSubjectNameEscaped" 2> '/dev/null'; )";
    # declare subjectNameTrimmed; subjectNameTrimmed="$( Misc_Regex -is '\s' -r '_' "$__tlsSubjectCommonName" 2> '/dev/null'; )";
    # declare subjectNameTrimmed; subjectNameTrimmed="$( Misc_Regex -is '[^0-9A-Za-z_]' -r '' "$subjectNameTrimmed" 2> '/dev/null'; )";
    declare currentDatetime; currentDatetime="$( date -u '+%Y%m%d_%H%M%S_Z'; )";
    declare caRandomValue; caRandomValue="$( Misc_RandomString -l 8; )";
    declare tlsRootCACertFilepath; tlsRootCACertFilepath="${tlsCACertsDirpath}/root_ca-cert-${caSubjectNameEscaped}-$( printf -- '%s' "${currentDatetime}_${caRandomValue}"; ).pem";
    # declare tlCertFilepath; tlCertFilepath="${tlsCertsDirpath}/root_ca-cert-${subjectNameTrimmed}-$( printf -- '%s' "${currentDatetime}_${caRandomValue}"; ).pem";

    declare tlsRootCAConfigFilepath="${TLS_SSLGenerate_sslConfigs[0]}";
    declare tlsCertConfigFilepath="${TLS_SSLGenerate_sslConfigs[1]}";

    printf -- '\nGenerating TLS/SSL files\n';

    declare tlsRootCAKeyPasswordTempFilepath; tlsRootCAKeyPasswordTempFilepath="$( mktemp; )";
    printf -- '%s' "$__tlsRootCAKeyPassword" > "$tlsRootCAKeyPasswordTempFilepath";

    # Generate a root certificate authority (CA) certificate

    printf -- $' [1/6] Generating root CA RSA key\n';
    openssl genpkey -aes-256-cbc -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -pass "file:${tlsRootCAKeyPasswordTempFilepath}" -out "$tlsRootCAPrivateKeyFilepath"; # Root CA Key
    printf -- $' [2/6] Generating root CA x509 certificate\n';
    openssl req -x509 -sha256 -new -nodes -days 365 -key "$tlsRootCAPrivateKeyFilepath" -passin "file:${tlsRootCAKeyPasswordTempFilepath}" -config "$tlsRootCAConfigFilepath" -out "$tlsRootCACertFilepath"; # Root CA Certificate

    # Generate a certificate (passwordless)

    printf -- $' [3/6] Generating RSA key\n';
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$hostPrivateKeyFilepath"; # Key
    printf -- $' [4/6] Generating x509 certificate\n';
    openssl req -x509 -sha256 -new -nodes -days 365 -config "$tlsCertConfigFilepath" -key "$hostPrivateKeyFilepath" -out "$hostX509CertFilepath"; # Certificate
    printf -- $' [5/6] Generating x509 certificate request\n';
    openssl x509 -x509toreq -in "$hostX509CertFilepath" -signkey "$hostPrivateKeyFilepath" -out "$tlsCertRequestFilepath"; # Certificate request

    # Sign the certificate with the root CA certificate

    printf -- $' [6/6] Generating x509 certificate signed by CA\n';

    openssl x509 -req -sha256 -days 365 \
        -extensions req_ext -extfile "$tlsCertConfigFilepath" \
        -CAcreateserial -CA "$tlsRootCACertFilepath" -CAkey "$tlsRootCAPrivateKeyFilepath" -passin "file:${tlsRootCAKeyPasswordTempFilepath}" \
        -in "$tlsCertRequestFilepath" \
        -out "$hostX509CertSignedFilepath";

    if [[ "$__isTlsRootCAKeyPasswordSave" != 0 ]];
    then
        # shellcheck disable=SC2094
        {
            # If file exists and not empty
            if [[ -s "$tlsRootCAPrivateKeyPasswordsFilepath" ]];
            then
                # Add a new line (to keep it more neat probably ^^")
                printf -- '\n';
            fi

            printf -- $'# Root CA Subject: \'%s\'\n' "$__tlsRootCASubjectCommonName";
            printf -- $'# Private Key: \'%s\'\n' "$tlsRootCAPrivateKeyFilepath";
            printf -- $'# Date: \'%s\'\n\n' "$( date -u '+%F_%T_Z'; )";
            cat -- "$tlsRootCAKeyPasswordTempFilepath";
            printf -- '\n';
        } \
            >> "$tlsRootCAPrivateKeyPasswordsFilepath";

        O -nf $' [ ! ] Stored root CA private key password in \'%s\'' -- "$tlsRootCAPrivateKeyPasswordsFilepath";
    fi

    rm "$tlsRootCAKeyPasswordTempFilepath";

    if [[
        ! -f "$tlsRootCAPrivateKeyFilepath" ||
        ! -f "$tlsRootCACertFilepath" ||
        ! -f "$hostPrivateKeyFilepath" ||
        ! -f "$hostX509CertFilepath" ||
        ! -f "$hostX509CertSignedFilepath"
    ]];
    then
        printf -- $'TLS generation failed (missing file)\n';

        return 1;
    fi

    # shellcheck disable=SC2034
    TLS_SSLGenerate_outputVariableReference=(
        "$__tlsRootCAKeyPassword"
        "$tlsRootCAPrivateKeyFilepath"
        "$tlsRootCACertFilepath"
        "$hostPrivateKeyFilepath"
        "$hostX509CertFilepath"
        "$hostX509CertSignedFilepath"
        "$( { [[ "$__isTlsRootCAKeyPasswordSave" != 0 ]] && printf -- '%s' "$tlsRootCAPrivateKeyPasswordsFilepath"; } || :; )"
    );

    return 0;
}

TLS_X509Preview()
{
    declare tlsX509CertFilepath="$1";

    if [[ ! -f "$tlsX509CertFilepath" ]];
    then
        return 1;
    fi

    # openssl x509 -text -noout -in "$tlsX509CertFilepath" | grep -A10 'X509';
    openssl x509 -text -noout -in "$tlsX509CertFilepath";
}
