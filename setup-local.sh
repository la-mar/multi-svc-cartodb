#!/bin/bash
SCRIPT_NAME=$0
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# These are used to git checkout each submodule to specific tags. Once the
# submodules are checked out to version tags, your docker-compose builds will
# include the appropriately versioned code.
CARTO_PGEXT_VERSION="${CARTO_PGEXT_VERSION:-0.26.1}"
CARTO_WINDSHAFT_VERSION="${CARTO_WINDSHAFT_VERSION:-7.0.0}"
CARTO_CARTODB_VERSION="${CARTO_CARTODB_VERSION:-v4.26.1}"
CARTO_SQLAPI_VERSION="${CARTO_SQLAPI_VERSION:-3.0.0}"
CARTO_DATASVCS_API_CLIENT_VERSION="${CARTO_DATASVCS_CLIENT_VERSION:-0.26.2-client}"
CARTO_DATASVCS_API_SERVER_VERSION="${CARTO_DATASVCS_SERVER_VERSION:-0.35.1-server}"
CARTO_DATASVCS_VERSION="${CARTO_DATASVCS_VERSION:-cdb_geocoder-v0.0.1rc2}"

ALL_MODULES="PGEXT WINDSHAFT CARTODB SQLAPI DATASVCS_API_CLIENT "
ALL_MODULES+="DATASVCS_API_SERVER DATASVCS"

CARTO_PGEXT_SUBMODULE_PATH="${SCRIPT_DIR}/docker/postgis/cartodb-postgresql"
CARTO_WINDSHAFT_SUBMODULE_PATH="${SCRIPT_DIR}/docker/windshaft/Windshaft-cartodb"
CARTO_CARTODB_SUBMODULE_PATH="${SCRIPT_DIR}/docker/cartodb/cartodb"
CARTO_SQLAPI_SUBMODULE_PATH="${SCRIPT_DIR}/docker/sqlapi/CartoDB-SQL-API"
CARTO_DATASVCS_API_CLIENT_SUBMODULE_PATH="${SCRIPT_DIR}/docker/postgis/dataservices-api-client"
CARTO_DATASVCS_API_SERVER_SUBMODULE_PATH="${SCRIPT_DIR}/docker/postgis/dataservices-api-server"
CARTO_DATASVCS_SUBMODULE_PATH="${SCRIPT_DIR}/docker/postgis/data-services"

# These values are used to set up the dev user on the cartodb instance.
# CARTO_DEFAULT_USER corresponds to SUBDOMAIN in the create_dev_user script.
CARTO_DEFAULT_USER="${CARTO_DEFAULT_USER:-developer}"
CARTO_DEFAULT_PASS="${CARTO_DEFAULT_PASS:-abc123def}"
CARTO_DEFAULT_EMAIL="${CARTO_DEFAULT_EMAIL:-username@example.com}"

SET_CHECKOUTS="no"
GENERATE_CERT="no"
QUIET=no
GITQUIET=""
HORIZONTAL_LINE="\n$(printf '=%.0s' {1..79})\n\n"

function display_help() {
    local help_text=""
    IFS='' read -r -d '' help_text <<EOF

Usage: $SCRIPT_NAME [--set-submodule-versions] [--generate-ssl-cert]

Purpose: Sets the following values in the .env file docker-compose uses to
         merge environment values into the docker-compose.yml file during the
         pre-processing steps for builds.

    CARTO_PGEXT_VERSION                 ($CARTO_PGEXT_VERSION)
    CARTO_WINDSHAFT_VERSION             ($CARTO_WINDSHAFT_VERSION)
    CARTO_CARTODB_VERSION               ($CARTO_CARTODB_VERSION)
    CARTO_SQLAPI_VERSION                ($CARTO_SQLAPI_VERSION)
    CARTO_DATASVCS_API_CLIENT_VERSION   ($CARTO_DATASVCS_API_CLIENT_VERSION)
    CARTO_DATASVCS_API_SERVER_VERSION   ($CARTO_DATASVCS_API_SERVER_VERSION)
    CARTO_DATASVCS_VERSION              ($CARTO_DATASVCS_VERSION)
    CARTO_DEFAULT_USER                  ($CARTO_DEFAULT_USER)
    CARTO_DEFAULT_PASS                  ($CARTO_DEFAULT_PASS)
    CARTO_DEFAULT_EMAIL                 ($CARTO_DEFAULT_EMAIL)

    If the --set-submodule-versions flag is present, resets the
    submodule directories to the version tags in those variables. You'll need
    to do that at least one time prior to running docker-compose build for
    the first time.

    Note that the .env file is excluded from version control, as you may
    want to experiment with local alterations to it. You can alter it directly,
    though be aware that it may be overwritten by this script--probably best
    to have the script write it, and supply test values to the script by
    environment variable.

    If the --generate-ssl-cert flag is present, generates localhost.crt and
    localhost.key files in ./docker/router/ssl, which are used to allow the
    nginx reverse proxy in the router container to serve self-signed requests
    over HTTPS.

Flags:
    --set-submodule-versions   - For all submodules in the project,
                                 pull from master, then re-checkout
                                 to the version tag listed in the script.
    --generate-ssl-cert        - Creates .crt and .key files for the nginx
                                 router container to use for signing localhost.
    -q|--quiet                 - Display no output.

EOF

    printf "$help_text"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            display_help
            exit 0
            ;;
        --set-submodule-versions)
            shift
            SET_CHECKOUTS=yes
            ;;
        --generate-ssl-cert)
            shift
            GENERATE_CERT=yes
            ;;
        -q|--quiet)
            shift
            QUIET=yes
            GITQUIET=" -q "
            ;;
        *)
            break
            ;;
    esac
done

function echo_if_unquiet() {
    if [ "$QUIET" != "yes" ]; then
        printf "$1"
    fi
}

IFS='' read -r -d '' vstrings <<EOF

Current version strings for Carto submodules:
    Carto PostgreSQL Extension: $CARTO_PGEXT_VERSION
    Carto Windshaft:            $CARTO_WINDSHAFT_VERSION
    Carto SQLAPI:               $CARTO_SQLAPI_VERSION
    CartoDB:                    $CARTO_CARTODB_VERSION
    Dataservices API (client)   $CARTO_DATASVCS_API_CLIENT_VERSION
    Dataservices API (server)   $CARTO_DATASVCS_API_SERVER_VERSION
    Dataservices                $CARTO_DATASVCS_VERSION

EOF

echo_if_unquiet "$vstrings"

IFS='' read -r -d '' dot_env_lines <<EOF
CARTO_PGEXT_VERSION=$CARTO_PGEXT_VERSION
CARTO_WINDSHAFT_VERSION=$CARTO_WINDSHAFT_VERSION
CARTO_SQLAPI_VERSION=$CARTO_SQLAPI_VERSION
CARTO_CARTODB_VERSION=$CARTO_CARTODB_VERSION
CARTO_DATASVCS_API_CLIENT_VERSION=$CARTO_DATASVCS_API_CLIENT_VERSION
CARTO_DATASVCS_API_SERVER_VERSION=$CARTO_DATASVCS_API_SERVER_VERSION
CARTO_DATASVCS_VERSION=$CARTO_DATASVCS_VERSION
CARTO_DEFAULT_USER=$CARTO_DEFAULT_USER
CARTO_DEFAULT_PASS=$CARTO_DEFAULT_PASS
CARTO_DEFAULT_EMAIL=$CARTO_DEFAULT_EMAIL
EOF

echo "$dot_env_lines" > ${SCRIPT_DIR}/.env

if [[ $GENERATE_CERT = "yes" ]]; then
    echo_if_unquiet "Generating SSL .crt and .key files in docker/router/ssl...\n"

    cert_output=$(openssl req -x509 \
    -out docker/router/ssl/wildcard-localhost.crt \
    -keyout docker/router/ssl/wildcard-localhost.key \
    -newkey rsa:2048 -nodes -sha256 \
    -subj '/CN=*.localhost.lan' -extensions EXT -config <( \
    printf "[dn]\nCN=*.localhost.lan\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:*.localhost.lan\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth") 2>&1)

    echo_if_unquiet "Completed generating SSL .crt and .key files.\n"

    chmod 644 docker/router/ssl/wildcard-localhost.crt
    chmod 640 docker/router/ssl/wildcard-localhost.key
fi

if [[ "$SET_CHECKOUTS" = "yes" ]]; then
    # Going to turn off warnings about detached head, but should be able to
    # set it back to the global value if there is one at the end of the script.
    CURRENT_DETACHED_HEAD_ADVICE=$(git config --global --get advice.detachedHead)
    git config --global advice.detachedHead false

    echo_if_unquiet "Setting checkouts to current version strings...\n"

    git --git-dir=${SCRIPT_DIR}/.git submodule update $GITQUIET --init --recursive
    git --git-dir=${SCRIPT_DIR}/.git pull $GITQUIET --recurse-submodules
    for module in $ALL_MODULES
    do
        version_key="CARTO_${module}_VERSION"
        path_key="CARTO_${module}_SUBMODULE_PATH"
        eval version='$'$version_key
        eval path='$'$path_key

        echo_if_unquiet "$HORIZONTAL_LINE"
        echo_if_unquiet "Module $module:\n\n"
        echo_if_unquiet "Checking out tag '$version' in $path:\n\n"
        if [[ $QUIET != "yes" ]]; then set -x; fi
        git --git-dir=$path/.git checkout $GITQUIET $version
        if [[ $QUIET != "yes" ]]; then { set +x; } 2>/dev/null; fi
    done

    if [[ -n $CURRENT_DETACHED_HEAD_ADVICE ]]; then
        git config --global advice.detachedHead "$CURRENT_DETACHED_HEAD_ADVICE"
    else
        git config --global --unset advice.detachedHead
    fi
fi
