# syntax = docker/dockerfile:1

# Set the base image to build off of
ARG BASE_IMAGE=public.ecr.aws/amazonlinux/amazonlinux:2023.4.20240611.0@sha256:e96baa46e2effb0f69d488007bde35a7d01d7fc2ec9f4e1cd65c59846c01775e

# BUILDER - installs sytem packages for compilation
FROM ${BASE_IMAGE} as builder
# Install pyenv installation and python build requirements
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf install -y \
    git tar findutils patch \
    make gcc zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel wget


FROM builder as dumb-init-builder

RUN wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64
RUN chmod +x /usr/local/bin/dumb-init

# PYTHONBUILDER - creates the desired version of python
FROM builder as pythonbuilder
ENV PYTHONDONTWRITEBYTECODE=1

# Install pyenv
RUN curl https://pyenv.run | bash
ENV PATH /root/.pyenv/bin:$PATH

# Set the desired version of python to use
ARG PYTHON_VERSION

RUN pyenv install ${PYTHON_VERSION} -v && \
    pyenv global ${PYTHON_VERSION} && \
    pyenv rehash && \
    find /root/.pyenv/versions/ -depth \
    \( \
    \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
    -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) \
    \) -exec rm -rf '{}' +

ENV PATH /root/.pyenv/versions/${PYTHON_VERSION}/bin:$PATH
RUN pip install --upgrade pip setuptools


# APPBUILDER - creates the application virtual environment
FROM pythonbuilder as appbuilder
ARG PYTHON_VERSION
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONOPTIMIZE=2

# Setup poetry
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m ensurepip --upgrade && \
    pip3 install --no-compile -U poetry

WORKDIR /app
# Create the venv for the project
COPY pyproject.toml poetry.lock ./
RUN --mount=type=cache,target=/root/.cache/pypoetry \
    poetry config virtualenvs.in-project true && \
    poetry env use ${PYTHON_VERSION} && \
    poetry install --without=dev --sync -n && \
    find .venv -depth \
    \( \
    \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
    -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) \
    \) -exec rm -rf '{}' + && \
    chmod +x .venv/bin/*


# RUNTIME - creates the runtime environment
FROM ${BASE_IMAGE} as runtime

ENV PYTHONDONTWRITEBYTECODE=1

RUN dnf -y install shadow-utils && \
    dnf -y clean all && \
    rm -rf /var/cache/* && \
    rm -rf /var/log

# Copy over dumb-init
COPY --from=dumb-init-builder /usr/local/bin/dumb-init /usr/local/bin/

# Copy over the compiled Python install over
COPY --from=pythonbuilder --link /root/.pyenv/versions/ /root/.pyenv/versions/

# Copy over the app venv
WORKDIR /app
COPY --from=appbuilder --link /app/.venv .venv
ENV PATH=/app/.venv/bin:$PATH

# Copy over the source code
COPY  secure_python /app/secure_python
ENV PATH=/app:$PATH

# Create and use a non-root user
RUN groupadd -r app && useradd --no-log-init -r -g app app

# Switch to the non-root user
USER app

# ENTRYPOINT [ "python3", "-m", "secure_python.hello"]


# ENTRYPOINT [ "python3" ]
# CMD [ "-m", "secure_python.hello" ]


ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD [ "python3", "-m", "secure_python.hello"]