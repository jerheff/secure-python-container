# syntax = docker/dockerfile:1

# Set the base image to build off of
ARG image=public.ecr.aws/amazonlinux/amazonlinux:2022.0.20220728.1
# Set the desired version of python to use
ARG pythonversion=3.10.6

# BUILDER
FROM ${image} as builder
# Install pyenv installation and python build requirements
RUN dnf install -y git tar findutils patch make gcc zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel


# PYENV installation
FROM builder as pyenv 

# Install pyenv
RUN curl https://pyenv.run | bash
ENV PATH /root/.pyenv/bin:$PATH

# PYTHON compilation
FROM pyenv as python
ARG pythonversion

# Install the desired version of python
RUN pyenv install ${pythonversion}
ENV PATH /root/.pyenv/versions/${pythonversion}/bin:$PATH

# BASE image setup
FROM ${image} as base
ARG pythonversion

# Copy the compiled Python install over to the base image
COPY --from=python /root/.pyenv/versions/ /root/.pyenv/versions/

# APP venv setup
FROM python as app
ARG pythonversion
# Setup poetry
RUN --mount=type=cache,target=/root/.cache/pip python3 -m ensurepip --upgrade && pip3 install -U pip poetry

WORKDIR /app
# Create the venv for the project
COPY pyproject.toml poetry.lock ./
RUN --mount=type=cache,target=/root/.cache/pypoetry poetry config virtualenvs.in-project true && poetry env use ${pythonversion} && poetry install --no-dev --remove-untracked -n

# RUNTIME creation
FROM base as runtime

WORKDIR /app
COPY --from=app /app/.venv .venv
ENV PATH=/app/.venv/bin:$PATH

ENTRYPOINT [ "python3" ]