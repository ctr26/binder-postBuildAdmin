
FROM buildpack-deps:bionic

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -qq update &&     apt-get -qq install --yes --no-install-recommends locales > /dev/null &&     apt-get -qq purge &&     apt-get -qq clean &&     rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen &&     locale-gen

ENV LC_ALL en_US.UTF-8

ENV LANG en_US.UTF-8

ENV LANGUAGE en_US.UTF-8

ENV SHELL /bin/bash

ARG NB_USER

ARG NB_UID

ENV USER ${NB_USER}

ENV HOME /home/${NB_USER}

RUN groupadd         --gid ${NB_UID}         ${NB_USER} &&     useradd         --comment "Default user"         --create-home         --gid ${NB_UID}         --no-log-init         --shell /bin/bash         --uid ${NB_UID}         ${NB_USER}

RUN wget --quiet -O - https://deb.nodesource.com/gpgkey/nodesource.gpg.key |  apt-key add - &&     DISTRO="bionic" &&     echo "deb https://deb.nodesource.com/node_14.x $DISTRO main" >> /etc/apt/sources.list.d/nodesource.list &&     echo "deb-src https://deb.nodesource.com/node_14.x $DISTRO main" >> /etc/apt/sources.list.d/nodesource.list

RUN apt-get -qq update &&     apt-get -qq install --yes --no-install-recommends        less        nodejs        unzip        > /dev/null &&     apt-get -qq purge &&     apt-get -qq clean &&     rm -rf /var/lib/apt/lists/*

EXPOSE 8888

ENV APP_BASE /srv

ENV NPM_DIR ${APP_BASE}/npm

ENV NPM_CONFIG_GLOBALCONFIG ${NPM_DIR}/npmrc

ENV CONDA_DIR ${APP_BASE}/conda

ENV NB_PYTHON_PREFIX ${CONDA_DIR}/envs/notebook

ENV KERNEL_PYTHON_PREFIX ${NB_PYTHON_PREFIX}

ENV PATH ${NB_PYTHON_PREFIX}/bin:${CONDA_DIR}/bin:${NPM_DIR}/bin:${PATH}

ENV NB_ENVIRONMENT_FILE="/tmp/environment.py-3.7.lock"

COPY --chown=${NB_USER}:${NB_USER} *environment.py-3.7.lock ${NB_ENVIRONMENT_FILE}

COPY --chown=${NB_USER}:${NB_USER} *activate_conda.sh /etc/profile.d/activate-conda.sh

RUN chmod +x /etc/profile.d/activate-conda.sh

COPY --chown=${NB_USER}:${NB_USER} *environment.yml /tmp/environment.yml

COPY --chown=${NB_USER}:${NB_USER} *install_miniforge.sh /tmp/install-miniforge.bash

RUN chmod +x /tmp/install-miniforge.bash

RUN mkdir -p ${NPM_DIR} && chown -R ${NB_USER}:${NB_USER} ${NPM_DIR}

USER ${NB_USER}

RUN npm config --global set prefix ${NPM_DIR}

USER root

RUN TIMEFORMAT='time: %3R' bash -c 'time /tmp/install-miniforge.bash' && rm /tmp/install-miniforge.bash ${NB_ENVIRONMENT_FILE}

ARG REPO_DIR=${HOME}

ENV REPO_DIR ${REPO_DIR}


WORKDIR ${REPO_DIR}

RUN chown ${NB_USER}:${NB_USER} ${REPO_DIR}


ENV PATH ${HOME}/.local/bin:${REPO_DIR}/.local/bin:${PATH}


ENV CONDA_DEFAULT_ENV ${KERNEL_PYTHON_PREFIX}


COPY --chown=${USER}:${USER} .binder/environment.yml ${REPO_DIR}/.binder/environment.yml

COPY --chown=${USER}:${USER} . ${REPO_DIR}

RUN chmod +x "${REPO_DIR}/.binder/postBuildAdmin" && "${REPO_DIR}/.binder/postBuildAdmin"

USER ${NB_USER}


RUN TIMEFORMAT='time: %3R' bash -c 'time mamba env update -p ${NB_PYTHON_PREFIX} -f ".binder/environment.yml" && time mamba clean --all -f -y && mamba list -p ${NB_PYTHON_PREFIX} '

LABEL repo2docker.ref="None"

LABEL repo2docker.repo="local"

LABEL repo2docker.version="2021.01.0"


# COPY --chown=${USER}:${USER} . {REPO_DIR}

USER ${NB_USER}

RUN chmod +x .binder/postBuild && "${REPO_DIR}/.binder/postBuild"

RUN chmod +x "${REPO_DIR}/.binder/start"
ENV R2D_ENTRYPOINT "${REPO_DIR}/.binder/start"
# COPY /repo2docker-entrypoint /usr/local/bin/repo2docker-entrypoint
# ENTRYPOINT ["/usr/local/bin/repo2docker-entrypoint"]
CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]