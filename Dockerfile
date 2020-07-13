FROM ubuntu:18.04

RUN apt-get -y update && apt-get install make sudo software-properties-common -y
COPY . /root/.dotfiles
WORKDIR /root/.dotfiles

CMD ["/bin/bash"]
