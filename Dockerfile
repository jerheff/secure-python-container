# syntax = docker/dockerfile:1

# Set the base image to build off of
ARG image=public.ecr.aws/amazonlinux/amazonlinux:2022.0.20220728.1@sha256:bc662315d5d88bc38832fe6f1223df1c99580ade96e41d09935967f248778987
# Set the desired version of python to use
ARG pythonversion=3.10.6

# BUILDER - installs sytem packages for compilation
FROM ${image} as builder
# Install pyenv installation and python build requirements
RUN --mount=type=cache,target=/var/cache/dnf \
    dnf install -y \
    git tar findutils patch \
    make gcc zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel


# PYTHONBUILDER - creates the desired version of python
FROM builder as pythonbuilder
ENV PYTHONDONTWRITEBYTECODE=1

# Install pyenv
RUN curl https://pyenv.run | bash
ENV PATH /root/.pyenv/bin:$PATH

# Install the desired version of python
ARG pythonversion
RUN pyenv install ${pythonversion} -v && \
    pyenv global ${pythonversion} && \
    pyenv rehash && \
    find /root/.pyenv/versions/ -depth \
    \( \
    \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
    -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) \
    \) -exec rm -rf '{}' +

ENV PATH /root/.pyenv/versions/${pythonversion}/bin:$PATH


# APPBUILDER - creates the application virtual environment
FROM pythonbuilder as appbuilder
ARG pythonversion
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONOPTIMIZE=2

# Setup poetry
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m ensurepip --upgrade && \
    pip3 install --no-compile -U pip poetry

WORKDIR /app
# Create the venv for the project
COPY pyproject.toml poetry.lock ./
RUN --mount=type=cache,target=/root/.cache/pypoetry \
    poetry config virtualenvs.in-project true && \
    poetry env use ${pythonversion} && \
    poetry install --no-dev --remove-untracked -n && \
    find .venv -depth \
    \( \
    \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
    -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) \
    \) -exec rm -rf '{}' + && \
    chmod +x .venv/bin/*


# RUNTIME - creates the runtime environment
FROM ${image} as runtime
ARG pythonversion

ENV PYTHONDONTWRITEBYTECODE=1

RUN dnf -y install shadow-utils && \
    dnf -y clean all && \
    rm -rf /var/cache/* && \
    rm -rf /var/lib/dnf/* && \
    rm -rf /var/lib/rpm/* && \
    rm -rf /var/log

RUN groupadd -r app && useradd --no-log-init -r -g app app
# USER app


# Copy over the compiled Python install over
COPY --from=pythonbuilder --link /root/.pyenv/versions/ /root/.pyenv/versions/

# Copy over the app venv
WORKDIR /app
COPY --from=appbuilder --link /app/.venv .venv
ENV PATH=/app/.venv/bin:$PATH



# ENTRYPOINT [ "python3" ]