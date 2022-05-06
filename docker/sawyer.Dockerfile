FROM osrf/ros:kinetic-desktop-full-xenial

# Set default shell
SHELL ["/bin/bash", "-c"]

# System installations
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654 && \
    apt-get update && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    software-properties-common \
    bash-completion \
    build-essential \
    git \
    apt-transport-https \
    ca-certificates \
    make \
    automake \
    autoconf \
    libtool \
    pkg-config \
    python \
    libxau-dev \
    libxdmcp-dev \
    libxext-dev \
    libx11-dev \
    x11proto-gl-dev \
    doxygen \
    tmux \
    sudo \
    locales \
    htop \
    wget  && \
    locale-gen en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/*

# nvidia-docker2 OpenGL
COPY --from=nvidia/opengl:1.0-glvnd-runtime-ubuntu16.04 \
    /usr/local/lib/x86_64-linux-gnu \
    /usr/local/lib/x86_64-linux-gnu
COPY --from=nvidia/opengl:1.0-glvnd-runtime-ubuntu16.04 \
    /usr/local/share/glvnd/egl_vendor.d/10_nvidia.json \
    /usr/local/share/glvnd/egl_vendor.d/10_nvidia.json

RUN echo '/usr/local/lib/x86_64-linux-gnu' >> /etc/ld.so.conf.d/glvnd.conf && \
    ldconfig && \
    echo '/usr/local/$LIB/libGL.so.1' >> /etc/ld.so.preload && \
    echo '/usr/local/$LIB/libEGL.so.1' >> /etc/ld.so.preload
ENV NVIDIA_VISIBLE_DEVICES \
    ${NVIDIA_VISIBLE_DEVICES:-all}
ENV NVIDIA_DRIVER_CAPABILITIES \
    ${NVIDIA_DRIVER_CAPABILITIES:+$NVIDIA_DRIVER_CAPABILITIES,}graphics

# Add new user
RUN useradd --system --create-home --home-dir /home/user --shell /bin/bash --gid root --groups sudo --uid 1000 --password user@123 user && \ 
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Environment variables
ENV LANG=en_US.UTF-8 \
    USER=user \
    UID=1000 \
    HOME=/home/user \
    QT_X11_NO_MITSHM=1
USER $USER
WORKDIR $HOME
# custom Bash prompt
RUN { echo && echo "PS1='\[\e]0;\u \w\a\]\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\] \\\$ '" ; } >> .bashrc

# tmux config
ADD --chown=user:1000 https://raw.githubusercontent.com/kanishkaganguly/dotfiles/master/tmux/.tmux.bash.conf $HOME/.tmux.conf

# ROS setup
RUN sudo apt-get update && \
    sudo apt-get install -y --no-install-recommends --allow-unauthenticated \
    python-catkin-tools \
    ros-kinetic-moveit-*

# Setup ROS workspace directory
RUN mkdir -p $HOME/workspace/src && \
    catkin init --workspace $HOME/workspace/ && \
    cd $HOME/workspace/src

# Set up ROS
RUN source /opt/ros/kinetic/setup.bash && \
    cd ${HOME}/workspace && \
    catkin_make && \
    source $HOME/workspace/devel/setup.bash

# Install Intera SDK Dependencies
RUN sudo apt-get install -y --no-install-recommends --allow-unauthenticated \
    git-core \
    python-argparse \
    python-wstool \
    python-vcstools \
    python-rosdep \
    ros-kinetic-control-msgs \
    ros-kinetic-joystick-drivers \
    ros-kinetic-xacro \
    ros-kinetic-tf2-ros \
    ros-kinetic-rviz \
    ros-kinetic-cv-bridge \
    ros-kinetic-actionlib \
    ros-kinetic-actionlib-msgs \
    ros-kinetic-dynamic-reconfigure \
    ros-kinetic-trajectory-msgs \
    ros-kinetic-rospy-message-converter

# Install Intera Robot SDK
RUN cd $HOME/workspace/src && \
    wstool init . && \
    git clone https://github.com/RethinkRobotics/sawyer_robot.git && \
    wstool merge sawyer_robot/sawyer_robot.rosinstall && \
    wstool update && \
    source /opt/ros/kinetic/setup.bash && \
    cd $HOME/workspace && \
    catkin_make && \
    cp $HOME/workspace/src/intera_sdk/intera.sh $HOME/workspace

# Installing MoveIt Sawyer
RUN cd $HOME/workspace/ && \
    ./intera.sh && \
    cd $HOME/workspace/src && \
    wstool merge https://raw.githubusercontent.com/RethinkRobotics/sawyer_moveit/master/sawyer_moveit.rosinstall && \
    wstool update && \
    source /opt/ros/kinetic/setup.bash && \
    cd $HOME/workspace && \
    catkin_make

# Installing Gazebo Sawyer
RUN sudo apt-get install -y --no-install-recommends --allow-unauthenticated \
    gazebo7 \
    ros-kinetic-qt-build \
    ros-kinetic-gazebo-ros-control \
    ros-kinetic-gazebo-ros-pkgs \
    ros-kinetic-ros-control \
    ros-kinetic-control-toolbox \
    ros-kinetic-realtime-tools \
    ros-kinetic-ros-controllers \
    ros-kinetic-xacro \
    python-wstool \
    ros-kinetic-tf-conversions \
    ros-kinetic-kdl-parser \
    ros-kinetic-sns-ik-lib && \
    cd $HOME/workspace/src/ && \
    git clone https://github.com/RethinkRobotics/sawyer_simulator.git && \
    wstool merge sawyer_simulator/sawyer_simulator.rosinstall && \
    wstool update && \
    source /opt/ros/kinetic/setup.bash && \
    cd $HOME/workspace && \
    catkin_make


# Set up working directory and bashrc
WORKDIR ${HOME}/workspace/
RUN echo 'source /opt/ros/kinetic/setup.bash' >> $HOME/.bashrc && \
    echo 'source $HOME/workspace/devel/setup.bash' >> $HOME/.bashrc
CMD /bin/bash
