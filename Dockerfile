FROM archlinux/base

RUN pacman -Syu --noconfirm
RUN pacman -S git gcc make tar wget gtk3 python-gobject vte3 --noconfirm

WORKDIR /opt/
RUN git clone https://github.com/nim-lang/Nim.git
WORKDIR /opt/Nim/
RUN sh build_all.sh
ENV PATH="/opt/Nim/bin:${PATH}"

ADD . /opt/nimBF2142Unlocker
WORKDIR /opt/nimBF2142Unlocker/
ENV PATH="/root/.nimble:${PATH}"
RUN nimble install -d
RUN nimble release