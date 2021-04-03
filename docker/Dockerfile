FROM ubuntu:20.04

RUN apt-get -y update && apt-get install -y make cmake sudo software-properties-common curl
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y locales git vim zsh python3-dev python3-pip tmux \
    && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG=en_US.UTF-8
RUN useradd -ms /bin/bash frank
USER frank
COPY --chown=frank . /home/frank/.dotfiles
WORKDIR /home/frank/.dotfiles

CMD ["/bin/bash"]
