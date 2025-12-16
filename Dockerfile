FROM nvidia/cudagl:11.4.2-devel-ubuntu18.04 AS base

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
    nano \
    bzip2 ca-certificates \
    libegl1-mesa-dev libgl1-mesa-dev \
    libx11-dev libxcursor-dev libxinerama-dev \
    libxrandr-dev libxi-dev \
    mesa-utils-extra \
    libzmq3-dev \
    libzmqpp-dev \
    libyaml-cpp-dev \
    python3-tk \
    pybind11-dev \
    libgoogle-glog-dev libgflags-dev \
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
    python-catkin-pkg python-catkin-pkg-modules \
    python-rosdep python-rosinstall \
    python-rosinstall-generator python-wstool \
    ros-melodic-octomap-msgs ros-melodic-octomap ros-melodic-octomap-ros ros-melodic-octomap-server \
    python-catkin-tools


# Install ROS Melodic
RUN apt-get update && \
    apt-get install -y curl gnupg2 lsb-release

# Add ROS package repository
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu bionic main" > /etc/apt/sources.list.d/ros-latest.list' && \
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -

RUN apt-get remove -y libyaml-cpp-dev && \
        apt-get install -y libyaml-cpp-dev=0.5.2-4ubuntu1
    
RUN apt-get update && \
    apt-get install -y ros-melodic-desktop-full python-rosdep python-rosinstall python-rosinstall-generator python-wstool build-essential ros-melodic-rviz


# Initialize rosdep
RUN rosdep init || true
RUN rosdep update

# Auto-source ROS on container start
RUN echo "source /opt/ros/melodic/setup.bash" >> /root/.bashrc



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

# ---------- micromamba ----------
ENV MAMBA_ROOT_PREFIX=/opt/micromamba
ENV PATH=/opt/micromamba/bin:$PATH

RUN curl -L https://micro.mamba.pm/api/micromamba/linux-64/latest \
    | tar -xvj -C /usr/local/bin --strip-components=1 bin/micromamba

# ---------- habitat env ----------
RUN micromamba create -y -n habitat \
    python=3.9 \
    cmake=3.14.0 \
    habitat-sim=0.3.3 \
    opencv \
    -c conda-forge -c aihabitat \
    && micromamba clean --all --yes

# ---------- auto-activate ----------
SHELL ["/bin/bash", "-c"]
RUN echo "micromamba activate habitat" >> ~/.bashrc

# -------------------------------------
# Create non-root user
# -------------------------------------
RUN useradd -ms /bin/bash ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers


# Create user only if it does not already exist
ARG USERNAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN if ! id -u $USERNAME >/dev/null 2>&1; then \
      groupadd -f --gid $USER_GID $USERNAME && \
      useradd --uid $USER_UID --gid $USER_GID -m $USERNAME; \
    fi \
    && apt-get update \
    && apt-get install -y sudo \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME

USER $USERNAME
WORKDIR /home/$USERNAME


RUN ls

RUN git clone https://github.com/Arpan12/flightmare.git

WORKDIR /home/$USERNAME/flightmare/flightros/src
RUN git clone https://github.com/catkin/catkin_simple.git
RUN git clone https://github.com/ethz-asl/eigen_catkin.git
RUN git clone https://github.com/ethz-asl/rotors_simulator.git
RUN git clone https://github.com/uzh-rpg/rpg_quadrotor_common.git
RUN git clone https://github.com/uzh-rpg/rpg_quadrotor_control.git

# -------------------------------------
# Flightmare local mount will happen later
# -------------------------------------
# EXPECTING YOU TO MOUNT YOUR FLIGHTMARE FOLDER AT RUNTIME
ENV FLIGHTMARE_PATH="/home/ubuntu/flightmare"
ENV PATH="$FLIGHTMARE_PATH:$PATH"


WORKDIR /home/$USERNAME/flightmare/flightlib
RUN rm -rf build && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc)

# Back to flightros
WORKDIR /home/$USERNAME/flightmare/flightros
RUN rosdep install --from-paths src --ignore-src -r -y || true

SHELL ["/bin/bash", "-c"]

RUN source /opt/ros/melodic/setup.bash && \
    catkin init && \
    catkin config --extend /opt/ros/melodic && \
    catkin build flightros -DBUILD_SAMPLES=ON

# ------------------------------------- # Install flightlib # ------------------------------------- # 
RUN cd /home/ubuntu/flightmare/flightlib && \ 
pip3 install -e . 
# # ------------------------------------- # # Install flightrl # # ------------------------------------- # 
RUN cd /home/ubuntu/flightmare/flightrl && \ 
pip3 install -e .



FROM base AS dev_containers_target_stage2


##TO create an image
# docker build -t flightmare:latest .

# ##To run the image
#docker run --network=host -it flightmare:latest /bin/bash
# xhost +local:root

#docker run -it   --gpus all   --privileged   --network=host   -e DISPLAY=$DISPLAY   -v /tmp/.X11-unix:/tmp/.X11-unix   -v $HOME/.Xauthority:/root/.Xauthority   -v $HOME/Projects/flightmare:/home/ubuntu/flightmare -e NVIDIA_DRIVER_CAPABILITIES=all   -e NVIDIA_VISIBLE_DEVICES=all   --name flightmare_gpu2   flightmare:latest   bash

# Commands to run inside the container
#sudo chown -R ubuntu:ubuntu /home/ubuntu/flightmare

# to connect VS code with the container, open VS code. Pres F1. attach to running container and select the running flightmare container name you get from docker ps command