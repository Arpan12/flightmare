FROM ubuntu:18.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# ---------------------------------------------------------
# SYSTEM DEPENDENCIES
# ---------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg2 lsb-release \
    build-essential cmake git wget sudo \
    python3 python3-dev python3-pip python3-tk \
    libeigen3-dev libopencv-dev \
    freeglut3-dev mesa-common-dev libglu1-mesa-dev libglew-dev \
    libsdl2-dev libxxf86vm-dev xvfb \
    libzmq3-dev libzmqpp-dev \
    libgoogle-glog-dev libgflags-dev \
    pybind11-dev \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# ADD ROS REPOSITORY + KEY
# ---------------------------------------------------------
RUN echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" \
    > /etc/apt/sources.list.d/ros1-latest.list

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-key F42ED6FBAB17C654

# ---------------------------------------------------------
# INSTALL ROS MELODIC (ONLY ONCE)
# ---------------------------------------------------------
RUN apt-get update && apt-get install -y \
    ros-melodic-desktop-full \
    python-rosdep python-rosinstall python-rosinstall-generator python-wstool \
    python-catkin-tools \
    ros-melodic-rviz

# ---------------------------------------------------------
# FIX YAML-CPP VERSION (Flightmare NEEDS 0.5.x)
# ---------------------------------------------------------
RUN apt-get remove -y libyaml-cpp-dev && \
    apt-get install -y libyaml-cpp-dev=0.5.2-4ubuntu1

# ---------------------------------------------------------
# ROSDEP INIT
# ---------------------------------------------------------
RUN rosdep init || true
RUN rosdep update

# ---------------------------------------------------------
# SOURCE ROS FOR ALL FUTURE BASH COMMANDS
# ---------------------------------------------------------
RUN echo "source /opt/ros/melodic/setup.bash" >> /root/.bashrc

# ---------------------------------------------------------
# CREATE USER
# ---------------------------------------------------------
ARG USERNAME=ubuntu
ARG USER_UID=1000
ARG USER_GID=1000

RUN useradd -m -u $USER_UID -g $USER_GID -s /bin/bash $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER $USERNAME
WORKDIR /home/$USERNAME

# ---------------------------------------------------------
# CLONE FLIGHTMARE & REPOS
# ---------------------------------------------------------
RUN git clone https://github.com/Arpan12/flightmare.git

WORKDIR /home/$USERNAME/flightmare/flightros/src
RUN git clone https://github.com/catkin/catkin_simple.git
RUN git clone https://github.com/ethz-asl/eigen_catkin.git
RUN git clone https://github.com/ethz-asl/rotors_simulator.git
RUN git clone https://github.com/uzh-rpg/rpg_quadrotor_common.git
RUN git clone https://github.com/uzh-rpg/rpg_quadrotor_control.git

# ---------------------------------------------------------
# BUILD FLIGHTLIB FIRST
# ---------------------------------------------------------
WORKDIR /home/$USERNAME/flightmare/flightlib

RUN rm -rf build && mkdir build && cd build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc)

# ---------------------------------------------------------
# INSTALL flightlib + flightrl (Python APIs)
# ---------------------------------------------------------
RUN pip3 install -e /home/$USERNAME/flightmare/flightlib
RUN pip3 install -e /home/$USERNAME/flightmare/flightrl

# ---------------------------------------------------------
# BUILD FLIGHTROS
# ---------------------------------------------------------
WORKDIR /home/$USERNAME/flightmare/flightros
RUN rosdep install --from-paths src --ignore-src -r -y || true

RUN source /opt/ros/melodic/setup.bash && \
    catkin init && \
    catkin config --extend /opt/ros/melodic && \
    catkin build flightros -DBUILD_SAMPLES=ON

# ---------------------------------------------------------
# FINAL IMAGE STAGE
# ---------------------------------------------------------
FROM base AS dev_containers_target_stage2
