set dotenv-load

# IMAGE := 'al2022-python:latest'
IMAGE := 'jerheff/test-secure-python:latest'

default:
    @just --list

lock:
    poetry lock --no-update
    poetry install --remove-untracked

build-local:
    docker buildx build -t {{IMAGE}} --load .

build-push:
    docker buildx build --platform linux/amd64,linux/arm64 -t {{IMAGE}} --push .

run:
    docker run --rm -it {{IMAGE}}

build-run: build-local && run

setup-mac-dev:
    brew install cmake libomp