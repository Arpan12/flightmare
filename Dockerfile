FROM ubuntu:18.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

# -------------------------------------
# System dependencies
# -------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg2 \
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
# Install dependency so "lsb_release -sc" works
RUN apt-get update && apt-get install -y lsb-release

# Add ROS repo correctly
RUN sh -c "echo 'deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main' \
    > /etc/apt/sources.list.d/ros1-latest.list"

# Add ROS key
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 \
    --recv-key F42ED6FBAB17C654


# Install ROS Melodic
RUN apt-get update && apt-get install -y ros-melodic-desktop-full
RUN echo "source /opt/ros/melodic/setup.bash" >> /etc/bash.bashrc

# ROS Tools for Catkin Workspaces 
RUN apt-get update && apt-get install -y \
    python3-catkin-pkg python3-catkin-pkg-modules \
    python3-rosdep python3-rosinstall \
    python3-rosinstall-generator python3-wstool \
    python3-catkin-tools



# Initialize rosdep
RUN rosdep init && rosdep update


# Install catkin_simple
RUN git clone https://github.com/catkin/catkin_simple /tmp/catkin_simple && \
    cp -r /tmp/catkin_simple /opt/ros/melodic/share/catkin_simple && \
    rm -rf /tmp/catkin_simple

    
# -------------------------------------
# Python dependencies
# -------------------------------------
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel

RUN pip3 install --no-cache-dir \
    pybind11==2.4.3 \
    scikit-build \
    numpy==1.18.5 \
    pillow==8.2.0 \
    tensorflow==1.15.5

RUN pip3 install ruamel.yaml==0.15.100 --force-reinstall


RUN cmake --version

# -------------------------------------
# Create non-root user
# -------------------------------------
RUN useradd -ms /bin/bash ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ubuntu
WORKDIR /home/ubuntu

RUN git clone https://github.com/Arpan12/flightmare.git
# -------------------------------------
# Flightmare local mount will happen later
# -------------------------------------
# EXPECTING YOU TO MOUNT YOUR FLIGHTMARE FOLDER AT RUNTIME
ENV FLIGHTMARE_PATH="/home/ubuntu/flightmare"
ENV PATH="$FLIGHTMARE_PATH:$PATH"

# ------------------------------------- # Install flightlib # ------------------------------------- # 
RUN cd /home/ubuntu/flightmare/flightlib && \ 
pip3 install --no-cache-dir . 
# # ------------------------------------- # # Install flightrl # # ------------------------------------- # 
RUN cd /home/ubuntu/flightmare/flightrl && \ 
pip3 install --no-cache-dir .


FROM base AS dev_containers_target_stage2


##TO create an image
# docker build -t flightmare:latest .

# ##To run the image
#docker run --network=host -it flightmare:latest /bin/bash
# xhost +local:root

# docker run -it --rm \
#   --network=host \
#   --gpus all \
#   --env="DISPLAY=$DISPLAY" \
#   --env="QT_X11_NO_MITSHM=1" \
#   --env="XDG_RUNTIME_DIR=/tmp/runtime-ubuntu" \
#   -v /tmp/.X11-unix:/tmp/.X11-unix \
#   -v $HOME/.Xauthority:/home/ubuntu/.Xauthority \
#   -v $HOME/Projects/flightmare:/home/ubuntu/flightmare \
#   --privileged \
#   --name flightmare_dev \
#   flightmare:latest \
#   /bin/bash

# Commands to run inside the container
#sudo chown -R ubuntu:ubuntu /home/ubuntu/flightmare

# to connect VS code with the container, open VS code. Pres F1. attach to running container and select the running flightmare container name you get from docker ps command
