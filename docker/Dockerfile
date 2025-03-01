FROM firedrakeproject/firedrake-env:latest AS hydrogym

USER root
RUN apt-get upgrade && apt-get update && \
        apt-get install -y libhdf5-dev libxcursor-dev libxinerama1 texlive

USER firedrake
WORKDIR /home/firedrake

# Install Firedrake and components
RUN curl -O https://raw.githubusercontent.com/firedrakeproject/firedrake/master/scripts/firedrake-install
# RUN bash -c "PETSC_CONFIGURE_OPTIONS='--download-fftw=1 --with-scalar-type=complex' python3 firedrake-install --no-package-manager --disable-ssh --remove-build-files --pip-install scipy"
RUN bash -c "PETSC_CONFIGURE_OPTIONS='--download-fftw=1' python3 firedrake-install --no-package-manager --disable-ssh --remove-build-files --pip-install scipy"
ENV VENV=/home/firedrake/firedrake

# Install the complex version of firedrake (not differentiable, but useful for stability analysis)
RUN bash -c "PETSC_CONFIGURE_OPTIONS='--download-fftw=1' python3 firedrake-install --no-package-manager --disable-ssh --remove-build-files --pip-install scipy --complex --venv-name=firedrake-complex"
ENV VENV_COMPLEX=/home/firedrake/firedrake-complex

RUN bash -c ". $VENV/bin/activate; firedrake-update --documentation-dependencies --tinyasm --slepc --install thetis --install gusto --install icepack --install irksome --install femlium"
RUN bash -c ". $VENV_COMPLEX/bin/activate; firedrake-update --documentation-dependencies --tinyasm --slepc --install thetis --install gusto --install icepack --install irksome --install femlium"
# ENV PATH="$VENV/bin:/home/firedrake/.local/bin:$PATH"

# Install dependencies
RUN bash -c ". $VENV/bin/activate && pip install --upgrade pip setuptools"
RUN bash -c ". $VENV_COMPLEX/bin/activate && pip install --upgrade pip setuptools"

# RUN sudo pip3 git+https://github.com/barkm/torch-fenics.git@master

# Install hydrogym package
COPY --chown=firedrake hydrogym /home/hydrogym
COPY --chown=firedrake setup.py /home/hydrogym
COPY --chown=firedrake requirements.txt /home/hydrogym
RUN bash -c ". $VENV/bin/activate && pip install -e /home/hydrogym"
RUN bash -c ". $VENV_COMPLEX/bin/activate && pip install -e /home/hydrogym"

# Install an iPython kernel for firedrake (https://github.com/firedrakeproject/firedrake/blob/master/docker/Dockerfile.jupyter)
#  TODO: THIS SHOULD BE IN AN EXTERNAL FILE...
RUN bash -c ". $VENV/bin/activate && pip install -r /home/hydrogym/requirements.txt"
RUN bash -c ". $VENV_COMPLEX/bin/activate && pip install -r /home/hydrogym/requirements.txt"
RUN bash -c ". $VENV/bin/activate && jupyter nbextension enable --py widgetsnbextension --sys-prefix"
RUN bash -c ". $VENV_COMPLEX/bin/activate && jupyter nbextension enable --py widgetsnbextension --sys-prefix"

# python -m pip install torch --extra-index-url https://download.pytorch.org/whl/cpu

# Final configuration
ENV OMP_NUM_THREADS=1
WORKDIR /home
CMD ["/bin/bash"]