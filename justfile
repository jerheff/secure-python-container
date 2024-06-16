set dotenv-load

# IMAGE := 'al2022-python:latest'
IMAGE := 'jerheff/test-secure-python:latest'
PYTHON_VERSION := "3.11.9"

default:
    @just --list

setup:
    pyenv local {{PYTHON_VERSION}}
    poetry install --sync

lock:
    poetry lock --no-update
    poetry install --sync

autoupdate:
    poetry lock
    poetry install --sync

build-local:
    docker buildx build --build-arg PYTHON_VERSION='{{PYTHON_VERSION}}' -t {{IMAGE}} --load .

build-push:
    docker buildx build --build-arg PYTHON_VERSION='{{PYTHON_VERSION}}' --platform linux/amd64,linux/arm64 -t {{IMAGE}} --push .

run:
    docker run --rm -it {{IMAGE}}

run-shell:
    docker run --rm -it --entrypoint "/bin/bash" {{IMAGE}}

build-run: build-local && run

setup-mac-dev:
    brew install cmake libomp