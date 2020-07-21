FROM ubuntu:18.04

RUN apt-get -y update && apt-get install make sudo software-properties-common locales -y
COPY . /root/.dotfiles
WORKDIR /root/.dotfiles
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen

CMD ["/bin/bash"]
