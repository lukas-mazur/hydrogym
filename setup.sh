#!/usr/bin/env bash


if [ -z $1 ]; then
        echo "Usage:"
        echo "  bash ./setup.sh <INSTALL_PATH> [options]"
        echo ""
        echo "Options:"
        echo "  --complex                 Build firedrake-complex"
        echo "  --use-preinstalled-mpi    Use preinstalled MPI version" 
        echo "                            (Make sue that mpicc, mpicxx, mpif90, mpiexec are defined)"
        exit 0
fi

BUILDNAME="firedrake"
BUILDOPTION=""

args=$(getopt -o ep: -l complex,use-preinstalled-mpi -n "$0" -- "$@") || exit

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--complex) BUILDNAME="firedrake-complex"; BUILDOPTION="--complex"; shift 1;;
        -m|--use-preinstalled-mpi) BUILDOPTION="--mpicc $(which mpicc) --mpicxx $(which mpicxx) --mpif90 $(which mpif90) --mpiexec $(which mpiexec) ${BUILDOPTION}"; shift 1;;
        *) ARG1=$1; shift;;
    esac
done


echo "Building ${BUILDNAME}"

python_available="False"
if [[ "$(python3 -V)" =~ "Python 3" ]]; then
    python_available=$(echo "import sys; print(sys.version_info.minor >= 7)" | python3)
fi
if [[ "$python_available" == "False" ]]; then
    echo "Error: Python version >= 3.7 required."
    exit 0
fi

REPO_PATH=$(dirname $(readlink -f $0))
INSTALL_PATH=$(dirname $(readlink -f $ARG1))/$(basename $ARG1)
mkdir -p ${INSTALL_PATH}/
cd $INSTALL_PATH

curl -O https://raw.githubusercontent.com/firedrakeproject/firedrake/master/scripts/firedrake-install

PETSC_CONFIGURE_OPTIONS='--download-fftw=1' python3 firedrake-install --no-package-manager --disable-ssh --remove-build-files --pip-install scipy  --venv-name=${BUILDNAME} ${BUILDOPTION} --honour-pythonpath

export LD_LIBRARY_PATH=${INSTALL_PATH}/${BUILDNAME}/src/petsc/default/lib/:$LD_LIBRARY_PATH

FIREDRAKE_VENV=${INSTALL_PATH}/${BUILDNAME}


bash -c ". ${FIREDRAKE_VENV}/bin/activate; firedrake-update --documentation-dependencies --tinyasm --slepc --install thetis --install gusto --install icepack --install irksome --install femlium" 
bash -c ". ${FIREDRAKE_VENV}/bin/activate && pip install --upgrade pip setuptools"
bash -c ". ${FIREDRAKE_VENV}/bin/activate && pip install -e ${REPO_PATH}"
bash -c ". ${FIREDRAKE_VENV}/bin/activate && pip install -r ${REPO_PATH}/missing_requirements.txt"
bash -c ". ${FIREDRAKE_VENV}/bin/activate && pip install -r ${REPO_PATH}/requirements.txt"
bash -c ". ${FIREDRAKE_VENV}/bin/activate && jupyter nbextension enable --py widgetsnbextension --sys-prefix"

