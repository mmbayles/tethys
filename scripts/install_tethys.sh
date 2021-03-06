#!/bin/bash

USAGE="USAGE: . install_tethys.sh [options]\n
\n
OPTIONS:\n
    -t, --tethys-home <PATH>            Path for tethys home directory. Default is ~/tethys.\n
    -a, --allowed-host <HOST>           Hostname or IP address on which to serve tethys. Default is 127.0.0.1.\n
    -p, --port <PORT>                   Port on which to serve tethys. Default is 8000.\n
    -b, --branch <BRANCH_NAME>          Branch to checkout from version control. Default is 'master'.\n
    -c, --conda-home <PATH>             Path where Miniconda will be installed, or to an existing installation of Miniconda. Default is \${TETHYS_HOME}/miniconda.\n
    -n, --conda-env-name <NAME>         Name for tethys conda environment. Default is 'tethys'.
    --python-version <PYTHON_VERSION>   Main python version to install tethys environment into (2 or 3). Default is 2.\n
    --db-username <USERNAME>            Username that the tethys database server will use. Default is 'tethys_default'.\n
    --db-password <PASSWORD>            Password that the tethys database server will use. Default is 'pass'.\n
    --db-port <PORT>                    Port that the tethys database server will use. Default is 5436.\n
    -S, --superuser <USERNAME>          Tethys super user name. Default is 'admin'.\n
    -E, --superuser-email <EMAIL>       Tethys super user email. Default is ''.\n
    -P, --superuser-pass <PASSWORD>     Tethys super user password. Default is 'pass'.\n
    --install-docker                    Flag to include Docker installation as part of the install script (Linux only).\n
    --install-docker-only               Flag to skip the Tethys installation and only install run the Docker installation. Tethys must already be installed (Linux only).\n
    --docker-options <OPTIONS>          Command line options to pass to the 'tethys docker init' call if --install-docker is used. Default is \"'-d'\".\n
    -x                                  Flag to turn on shell command echoing.\n
    -h, --help                          Print this help information.\n
"

print_usage ()
{
    echo -e ${USAGE}
    exit
}
set -e  # exit on error

# Set platform specific default options
if [ "$(uname)" = "Linux" ]
then
    LINUX_DISTRIBUTION=$(lsb_release -is) || LINUX_DISTRIBUTION=$(python -c "import platform; print(platform.linux_distribution(full_distribution_name=0)[0])")
    # convert to lower case
    LINUX_DISTRIBUTION=${LINUX_DISTRIBUTION,,}
    MINICONDA_URL="https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh"
    BASH_PROFILE=".bashrc"
    resolve_relative_path ()
    {
        local __path_var="$1"
        eval $__path_var="'$(readlink -f $2)'"
    }
elif [ "$(uname)" = "Darwin" ]  # i.e. MacOSX
then
    MINICONDA_URL="https://repo.continuum.io/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"
    BASH_PROFILE=".bash_profile"
    resolve_relative_path ()
    {
        local __path_var="$1"
        eval $__path_var="'$(python -c "import os; print(os.path.abspath('$2'))")'"
    }
else
    echo $(uname) is not a supported operating system.
    exit
fi

# Set default options
ALLOWED_HOST='127.0.0.1'
TETHYS_HOME=~/tethys
TETHYS_PORT=8000
TETHYS_DB_USERNAME='tethys_default'
TETHYS_DB_PASSWORD='pass'
TETHYS_DB_PORT=5436
CONDA_ENV_NAME='tethys'
PYTHON_VERSION='2'
BRANCH='master'

TETHYS_SUPER_USER='admin'
TETHYS_SUPER_USER_EMAIL=''
TETHYS_SUPER_USER_PASS='pass'

DOCKER_OPTIONS='-d'

# parse command line options
set_option_value ()
{
    local __option_key="$1"
    value="$2"
    if [[ $value == -* ]]
    then
        print_usage
    fi
    eval $__option_key="$value"
}
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -t|--tethys-home)
    set_option_value TETHYS_HOME "$2"
    shift # past argument
    ;;
    -a|--allowed-host)
    set_option_value ALLOWED_HOST "$2"
    shift # past argument
    ;;
    -p|--port)
    set_option_value TETHYS_PORT "$2"
    shift # past argument
    ;;
    -b|--branch)
    set_option_value BRANCH "$2"
    shift # past argument
    ;;
    -c|--conda-home)
    set_option_value CONDA_HOME "$2"
    shift # past argument
    ;;
    -n|--conda-env-name)
    set_option_value CONDA_ENV_NAME "$2"
    shift # past argument
    ;;
    --python-version)
    set_option_value PYTHON_VERSION "$2"
    shift # past argument
    ;;
    --db-username)
    set_option_value TETHYS_DB_USERNAME "$2"
    shift # past argument
    ;;
    --db-password)
    set_option_value TETHYS_DB_PASS "$2"
    shift # past argument
    ;;
    --db-port)
    set_option_value TETHYS_DB_PORT "$2"
    shift # past argument
    ;;
    -S|--superuser)
    set_option_value TETHYS_SUPER_USER "$2"
    shift # past argument
    ;;
    -E|--superuser-email)
    set_option_value TETHYS_SUPER_USER_EMAIL "$2"
    shift # past argument
    ;;
    -P|--superuser-pass)
    set_option_value TETHYS_SUPER_USER_PASS "$2"
    shift # past argument
    ;;
    --install-docker)
    if [ "$(uname)" = "Linux" ]
    then
        INSTALL_DOCKER="true"
    else
        echo Automatic installation of Docker is not supported on $(uname). Ignoring option $key.
    fi
    ;;
    --install-docker-only)
    if [ "$(uname)" = "Linux" ]
    then
        INSTALL_DOCKER="true"
        SKIP_TETHYS_INSTALL="true"
    else
        echo Automatic installation of Docker is not supported on $(uname). Ignoring option $key.
    fi
    ;;
    --docker-options)
    set_option_value DOCKER_OPTIONS "$2"
    shift # past argument
    ;;
    -x)
    ECHO_COMMANDS="true"
    ;;
    -h|--help)
    print_usage
    ;;
    *) # unknown option
    echo Ignoring unrecognized option: $key
    ;;
esac
shift # past argument or value
done

# resolve relative paths
resolve_relative_path TETHYS_HOME ${TETHYS_HOME}

# set CONDA_HOME relative to TETHYS_HOME if not already set
if [ -z ${CONDA_HOME} ]
then
    CONDA_HOME="${TETHYS_HOME}/miniconda"
else
    resolve_relative_path CONDA_HOME ${CONDA_HOME}
fi



if [ -n "${ECHO_COMMANDS}" ]
then
    set -x # echo commands as they are executed
fi


if [ -z "${SKIP_TETHYS_INSTALL}" ]
then
    echo "Starting Tethys Installation..."

    mkdir -p "${TETHYS_HOME}"

    # install miniconda
    # first see if Miniconda is already installed
    if [ -f "${CONDA_HOME}/bin/activate" ]
    then
        echo "Using existing Miniconda installation..."
    else
        echo "Installing Miniconda..."
        wget ${MINICONDA_URL} -O "${TETHYS_HOME}/miniconda.sh" || (echo -using curl instead; curl ${MINICONDA_URL} -o "${TETHYS_HOME}/miniconda.sh")
        pushd ./
        cd "${TETHYS_HOME}"
        bash miniconda.sh -b -p "${CONDA_HOME}"
        popd
    fi
    export PATH="${CONDA_HOME}/bin:$PATH"

    # clone Tethys repo
    echo "Cloning the Tethys Platform repo..."
    conda install --yes git
    git clone https://github.com/tethysplatform/tethys.git "${TETHYS_HOME}/src"
    cd "${TETHYS_HOME}/src"
    git checkout ${BRANCH}

    # create conda env and install Tethys
    echo "Setting up the ${CONDA_ENV_NAME} environment..."
    conda env create -n ${CONDA_ENV_NAME} -f "environment_py${PYTHON_VERSION}.yml"
    . activate ${CONDA_ENV_NAME}
    python setup.py develop

    # only pass --allowed-hosts option to gen settings command if it is not the default
    if [ ${ALLOWED_HOST} != "127.0.0.1" ]
    then
        ALLOWED_HOST_OPT="--allowed-host ${ALLOWED_HOST}"
    fi
    tethys gen settings -d "${TETHYS_HOME}/src/tethys_apps" ${ALLOWED_HOST_OPT} --db-username ${TETHYS_DB_USERNAME} --db-password ${TETHYS_DB_PASSWORD} --db-port ${TETHYS_DB_PORT}

    # Setup local database
    echo "Setting up the Tethys database..."
    initdb  -U postgres -D "${TETHYS_HOME}/psql/data"
    pg_ctl -U postgres -D "${TETHYS_HOME}/psql/data" -l "${TETHYS_HOME}/psql/logfile" start -o "-p ${TETHYS_DB_PORT}"
    echo "Waiting for databases to startup..."; sleep 10
    psql -U postgres -p ${TETHYS_DB_PORT} --command "CREATE USER ${TETHYS_DB_USERNAME} WITH NOCREATEDB NOCREATEROLE NOSUPERUSER PASSWORD '${TETHYS_DB_PASSWORD}';"
    createdb -U postgres -p ${TETHYS_DB_PORT} -O ${TETHYS_DB_USERNAME} ${TETHYS_DB_USERNAME} -E utf-8 -T template0

    # Initialze Tethys database
    tethys manage syncdb
    echo "from django.contrib.auth.models import User; User.objects.create_superuser('${TETHYS_SUPER_USER}', '${TETHYS_SUPER_USER_EMAIL}', '${TETHYS_SUPER_USER_PASS}')" | python manage.py shell
    pg_ctl -U postgres -D "${TETHYS_HOME}/psql/data" stop
    . deactivate

    # Create environment activate/deactivate scripts
    ACTIVATE_DIR="${CONDA_HOME}/envs/${CONDA_ENV_NAME}/etc/conda/activate.d"
    DEACTIVATE_DIR="${CONDA_HOME}/envs/${CONDA_ENV_NAME}/etc/conda/deactivate.d"
    mkdir -p "${ACTIVATE_DIR}" "${DEACTIVATE_DIR}"
    ACTIVATE_SCRIPT="${ACTIVATE_DIR}/tethys-activate.sh"
    DEACTIVATE_SCRIPT="${DEACTIVATE_DIR}/tethys-deactivate.sh"

    echo "export TETHYS_HOME='${TETHYS_HOME}'" >> "${ACTIVATE_SCRIPT}"
    echo "export TETHYS_PORT='${TETHYS_PORT}'" >> "${ACTIVATE_SCRIPT}"
    echo "export TETHYS_DB_PORT='${TETHYS_DB_PORT}'" >> "${ACTIVATE_SCRIPT}"
    echo "alias tethys_start_db='pg_ctl -U postgres -D \"\${TETHYS_HOME}/psql/data\" -l \"\${TETHYS_HOME}/psql/logfile\" start -o \"-p \${TETHYS_DB_PORT}\"'" >> "${ACTIVATE_SCRIPT}"
    echo "alias tstartdb=tethys_start_db" >> "${ACTIVATE_SCRIPT}"
    echo "alias tethys_stop_db='pg_ctl -U postgres -D \"\${TETHYS_HOME}/psql/data\" stop'" >> "${ACTIVATE_SCRIPT}"
    echo "alias tstopdb=tethys_stop_db" >> "${ACTIVATE_SCRIPT}"
    echo "alias tms='tethys manage start -p ${ALLOWED_HOST}:\${TETHYS_PORT}'" >> "${ACTIVATE_SCRIPT}"
    echo "echo 'Starting Tethys Database Server...'" >> "${ACTIVATE_SCRIPT}"
    echo "pg_ctl -U postgres -D \"\${TETHYS_HOME}/psql/data\" -l \"\${TETHYS_HOME}/psql/logfile\" start -o \"-p \${TETHYS_DB_PORT}\"" >> "${ACTIVATE_SCRIPT}"

    echo "echo 'Stopping Tethys Database Server...'" >> "${DEACTIVATE_SCRIPT}"
    echo "pg_ctl -U postgres -D \"\${TETHYS_HOME}/psql/data\" stop" >> "${DEACTIVATE_SCRIPT}"
    echo "unset TETHYS_HOME" >> "${DEACTIVATE_SCRIPT}"
    echo "unset TETHYS_PORT" >> "${DEACTIVATE_SCRIPT}"
    echo "unset TETHYS_DB_PORT" >> "${DEACTIVATE_SCRIPT}"
    echo "unalias tethys_start_db" >> "${DEACTIVATE_SCRIPT}"
    echo "unalias tstartdb" >> "${DEACTIVATE_SCRIPT}"
    echo "unalias tethys_stop_db" >> "${DEACTIVATE_SCRIPT}"
    echo "unalias tstopdb" >> "${DEACTIVATE_SCRIPT}"
    echo "unalias tms" >> "${DEACTIVATE_SCRIPT}"

    echo "# Tethys Platform" >> ~/${BASH_PROFILE}
    echo "alias t='. ${CONDA_HOME}/bin/activate ${CONDA_ENV_NAME}'" >> ~/${BASH_PROFILE}

    echo "Tethys installation complete!"
    echo
    echo "NOTE: to enable the new alias 't' which activates the tethys environment you must run '. ~/${BASH_PROFILE}'"

fi

# Install Docker (if flag is set)
set +e  # don't exit on error anymore

installation_warning(){
    echo "WARNING: installing docker on $1 is not officially supported by the Tethys install script. Attempting to install with $2 script."
}

finalize_docker_install(){
    sudo groupadd docker
    sudo gpasswd -a ${USER} docker
    . ${CONDA_HOME}/bin/activate ${CONDA_ENV_NAME}
    sg docker -c "tethys docker init ${DOCKER_OPTIONS}"
    . deactivate
    echo "Docker installation finished!"
    echo "You must re-login for Docker permissions to be activated."
    echo "(Alternatively you can run 'newgrp docker')"
}

ubuntu_debian_docker_install(){
    if [ "${LINUX_DISTRIBUTION}" != "ubuntu" ] && [ ${LINUX_DISTRIBUTION} != "debian" ]
    then
        installation_warning ${LINUX_DISTRIBUTION} "Ubuntu"
    fi

    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
    curl -fsSL https://download.docker.com/linux/${LINUX_DISTRIBUTION}/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/${LINUX_DISTRIBUTION} $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce

    finalize_docker_install
}

centos_docker_install(){
    if [ "${LINUX_DISTRIBUTION}" != "centos" ]
    then
        installation_warning ${LINUX_DISTRIBUTION} "CentOS"
    fi

    sudo yum -y install yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum makecache fast
    sudo yum -y install docker-ce
    sudo systemctl start docker
    sudo systemctl enable docker

    finalize_docker_install
}

fedora_docker_install(){
    if [ "${LINUX_DISTRIBUTION}" != "fedora" ]
    then
        installation_warning ${LINUX_DISTRIBUTION} "Fedora"
    fi

    sudo dnf -y install -y dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf makecache fast
    sudo dnf -y install docker-ce
    sudo systemctl start docker
    sudo systemctl enable docker

    finalize_docker_install
}

if [ -n "${LINUX_DISTRIBUTION}" -a "${INSTALL_DOCKER}" = "true" ]
then
    # prompt for sudo
    echo "Docker installation requires some commands to be run with sudo. Please enter password:"
    sudo echo "Installing Docker..."

    case ${LINUX_DISTRIBUTION} in
        debian)
            ubuntu_debian_docker_install
        ;;
        ubuntu)
            ubuntu_debian_docker_install
        ;;
        centos)
            centos_docker_install
        ;;
        redhat)
            centos_docker_install
        ;;
        fedora)
            fedora_docker_install
        ;;
        *)
            echo "Automated Docker installation on ${LINUX_DISTRIBUTION} is not supported. Please see https://docs.docker.com/engine/installation/ for more information on installing Docker."
        ;;
    esac
fi

on_exit(){
    set +e
    set +x
}
trap on_exit EXIT
