FROM ubuntu:18.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

# -------------------------------------
# System dependencies
# -------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    python3 python3-dev python3-pip \
    libeigen3-dev \
    libopencv-dev \
    freeglut3-dev \
    mesa-common-dev \
    libglu1-mesa-dev \
    libglew-dev \
    libsdl2-dev \
    libxxf86vm-dev \
    xvfb \
    wget \
    sudo \
    libzmq3-dev \
    libzmqpp-dev \
    python3-tk \
    pybind11-dev \
    && rm -rf /var/lib/apt/lists/*

# -------------------------------------
# Python dependencies
# -------------------------------------
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel

RUN pip3 install --no-cache-dir \
    pybind11==2.4.3 \
    scikit-build \
    numpy==1.19.5 \
    pillow==8.2.0

RUN cmake --version

# -------------------------------------
# Create non-root user
# -------------------------------------
RUN useradd -ms /bin/bash ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ubuntu
WORKDIR /home/ubuntu

# -------------------------------------
# Flightmare local mount will happen later
# -------------------------------------
# EXPECTING YOU TO MOUNT YOUR FLIGHTMARE FOLDER AT RUNTIME
ENV FLIGHTMARE_PATH="/home/ubuntu/flightmare"
ENV PATH="$FLIGHTMARE_PATH:$PATH"

FROM base AS dev_containers_target_stage
