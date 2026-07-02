FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        ccache \
        cmake \
        git \
        libssl-dev \
        ninja-build \
        pkg-config \
        python3 \
        scons \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

ENV CCACHE_DIR=/work/local_dependencies/.ccache
