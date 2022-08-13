set dotenv-load

IMAGE := 'al2022-python:latest'

default:
    @just --list

lock:
    poetry lock --no-update
    poetry install --remove-untracked

build:
    docker buildx build -t {{IMAGE}} --load .

run:
    docker run --rm -it {{IMAGE}}

build-run: build && run

setup-mac-dev:
    brew install cmake libomp