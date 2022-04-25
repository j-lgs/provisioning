FROM ubuntu:jammy

RUN \
    apt-get update && apt-get install -y openssh-server sudo docker docker-compose python-pip python3-docker && rm -rf /var/lib/apt/lists/* && \
    useradd -rm -d /home/ansible -s /bin/bash -g root -G sudo,docker -u 1000 ansible && \
    echo 'ansible:ansible' | chpasswd && service ssh start

EXPOSE 22

COPY root /
CMD ["/usr/sbin/container-init"]
