# syntax = docker/dockerfile:1

# Pin uv and distroless for reproducibility
ARG RUNTIME_IMAGE=gcr.io/distroless/cc-debian12:latest@sha256:329e54034ce498f9c6b345044e8f530c6691f99e94a92446f68c0adf9baa8464

FROM ghcr.io/astral-sh/uv:0.10.8@sha256:88234bc9e09c2b2f6d176a3daf411419eb0370d450a08129257410de9cfafd2a AS uv

# Builder uses Debian for glibc compatibility with distroless runtime
FROM debian:bookworm-slim AS appbuilder

ENV PYTHONDONTWRITEBYTECODE=1
ENV DEBIAN_FRONTEND=noninteractive

COPY --from=uv /uv /usr/local/bin/uv

# Install Python version specified in .python-version
WORKDIR /app
COPY .python-version ./
RUN uv python install --install-dir /opt/python

# Install dependencies (separate step for layer caching)
COPY pyproject.toml uv.lock ./
RUN uv venv --python /opt/python/cpython-$(cat .python-version)-linux-*/bin/python3 .venv && \
    uv sync --frozen --no-dev --no-install-project

# Install the project itself (non-editable so it's fully contained in the venv)
COPY secure_python/ /app/secure_python
RUN uv sync --frozen --no-dev --no-editable

# Clean up test/doc cruft from both Python install and venv
RUN find /opt/python .venv -depth \
    \( \
    \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
    -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) \
    \) -exec rm -rf '{}' +

# Install and gather shared libs not included in distroless cc (zlib, OpenMP)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends zlib1g libgomp1 && \
    mkdir -p /opt/libs && \
    cp -L /lib/*-linux-gnu/libz.so.1 /lib/*-linux-gnu/libgomp.so.1 /opt/libs/

# RUNTIME - Google Distroless (cc variant includes libstdc++ for native extensions)
FROM ${RUNTIME_IMAGE} AS runtime

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV LD_LIBRARY_PATH=/opt/libs

# Append non-root app user (preserve distroless's existing root/nobody/nonroot)
COPY <<passwd /etc/passwd
root:x:0:0:root:/root:/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/sbin/nologin
nonroot:x:65532:65532:nonroot:/home/nonroot:/sbin/nologin
app:x:10001:10001:app:/app:/sbin/nologin
passwd
COPY <<group /etc/group
root:x:0:
nobody:x:65534:
tty:x:5:
staff:x:50:
nonroot:x:65532:
app:x:10001:
group

# Copy shared libs, Python install, and app venv
COPY --from=appbuilder /opt/libs/ /opt/libs/
COPY --from=appbuilder --link /opt/python /opt/python
WORKDIR /app
COPY --from=appbuilder --chown=10001:10001 /app/.venv .venv

USER app
ENV PATH="/app/.venv/bin:$PATH"

ENTRYPOINT ["python3", "-m", "secure_python.hello"]
