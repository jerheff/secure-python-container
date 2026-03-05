set dotenv-load

IMAGE := 'jerheff/test-secure-python:latest'

default:
    @just --list

setup:
    uv python install
    uv sync

lock:
    uv lock
    uv sync

autoupdate:
    uv lock --upgrade
    uv sync

build-local:
    docker buildx build -t {{IMAGE}} --load .

build-push:
    docker buildx build --platform linux/amd64,linux/arm64 -t {{IMAGE}} --push .

run:
    docker run --rm -it {{IMAGE}}

# No shell available in distroless — use debug image to troubleshoot
run-debug:
    docker run --rm -it --entrypoint "/busybox" gcr.io/distroless/cc-debian12:debug sh

build-run: build-local && run

trivy:
    trivy image {{IMAGE}}

dive:
    dive {{IMAGE}}
