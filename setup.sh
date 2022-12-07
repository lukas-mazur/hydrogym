#!/usr/bin/env bash


# module load toolchain/foss/2021b
# module load devel/Autoconf/2.71-GCCcore-11.2.0
# module load devel/Automake/1.16.4-GCCcore-11.2.0
# module load devel/Autotools/20210726-GCCcore-11.2.0
# module load lang/Python/3.9.6-GCCcore-11.2.0-bare
# module load lang/Bison/3.7.6-GCCcore-11.2.0
# module load lang/flex/2.6.4-GCCcore-11.2.0
# module load devel/CMake/3.22.1-GCCcore-11.2.0
# module load mpi/OpenMPI/4.1.2-GCC-11.2.0
# 
# export CC=$(which mpicc)
# export CXX=$(which mpicxx)



if [ -z $1 ]; then
        echo "Usage:"
        echo "  bash ./setup.sh <INSTALL_PATH> [options]"
        echo ""
        echo "Options:"
        echo "  -c    Build firedrake-complex"
        exit 0
fi


if [[ $2 == "-c" ]]; then
    BUILDNAME="firedrake-complex"
    BUILDOPTION="--complex"
else
    BUILDNAME="firedrake"
    BUILDOPTION=""
fi

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
INSTALL_PATH=$(dirname $(readlink -f $1))/$(basename $1)
mkdir -p ${INSTALL_PATH}/
cd $INSTALL_PATH

curl -O https://raw.githubusercontent.com/firedrakeproject/firedrake/master/scripts/firedrake-install

PETSC_CONFIGURE_OPTIONS='--download-fftw=1' python3 firedrake-install --no-package-manager --disable-ssh --remove-build-files --pip-install scipy  --venv-name=${BUILDNAME} ${BUILDOPTION} --mpicc $(which mpicc) --mpicxx $(which mpicxx) --mpif90 $(which mpif90) --mpiexec $(which mpiexec) --honour-pythonpath

export LD_LIBRARY_PATH=${INSTALL_PATH}/${BUILDNAME}/src/petsc/default/lib/:$LD_LIBRARY_PATH

FIREDRAKE_VENV=${INSTALL_PATH}/${BUILDNAME}


bash -c ". ${FIREDRAKE_VENV}/bin/activate; firedrake-update --documentation-dependencies --tinyasm --slepc --install thetis --install gusto --install icepack --install irksome --install femlium" 
bash -c ". ${FIREDRAKE_VENV}/bin/activate && pip install --upgrade pip setuptools"
bash -c ". ${FIREDRAKE_VENV}/bin/activate && pip install -e ${REPO_PATH}"
bash -c ". ${FIREDRAKE_VENV}/bin/activate && pip install -r ${REPO_PATH}/missing_requirements.txt"
bash -c ". ${FIREDRAKE_VENV}/bin/activate && pip install -r ${REPO_PATH}/requirements.txt"
bash -c ". ${FIREDRAKE_VENV}/bin/activate && jupyter nbextension enable --py widgetsnbextension --sys-prefix"

