FROM debian:latest

# set environment variables for tzdata
ARG TZ=America/New_York
ENV TZ=${TZ}

ARG DEBIAN_FRONTEND=noninteractive

# --- Core build tools and dependencies for Aspen ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc nasm make g++

RUN apt-get install -y --no-install-recommends \
    qemu-system-x86 gdb-multiarch python3 python3-pip python3-pyelftools

RUN apt-get install -y --no-install-recommends \
    git vim sudo locales qemu-user man cmake pkg-config \
    libnl-3-dev libnl-route-3-dev libnuma-dev uuid-dev \
    libssl-dev libaio-dev libcunit1-dev libclang-dev libncurses-dev meson \
    && rm -rf /var/lib/apt/lists/*


# Force generic x86_64 compilation flags to avoid AVX512/UINTR issues
ENV CFLAGS="-O2 -march=core2"
ENV CXXFLAGS="-O2 -march=core2"
ENV EXTRA_CFLAGS=""
ENV EXTRA_LDFLAGS=""
ENV PKG_CONFIG_PATH=""

# --- Locale setup ---
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# --- Create passwordless sudo user ---
RUN useradd -m -s /bin/bash aspen-user && \
    echo "aspen-user ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/aspen-init

# --- Record version identifier for consistency ---
RUN (echo '#\!/bin/sh'; echo 'echo 12.x86_64') > /usr/bin/aspen-docker-version && \
    chmod ugo+rx,u+w,go-w /usr/bin/aspen-docker-version

# --- Git identity and editor configuration ---
ARG USER="Aspen Dev"
ARG EMAIL="aspen@example.com"

USER aspen-user
RUN git config --global user.name "${USER}" && \
    git config --global user.email "${EMAIL}" && \
    (echo "(custom-set-variables"; echo " '(c-basic-offset 4)"; echo " '(indent-tabs-mode nil))") > ~/.emacs && \
    (echo "set expandtab"; echo "set shiftwidth=4"; echo "set softtabstop=4") > ~/.vimrc && \
    echo ". ~/.bashrc" >> ~/.bash_profile && \
    echo "export PATH=/usr/local/bin:\$PATH" >> ~/.bashrc && \
    rm -f ~/.bash_logout && \
    echo "add-auto-load-safe-path ~" > ~/.gdbinit && \
    echo "set architecture i386:x86-64" >> ~/.gdbinit && \
    echo "target remote localhost:1234" >> ~/.gdbinit && \
    echo "symbol-file aspen.elf" >> ~/.gdbinit && \
    echo "break _start" >> ~/.gdbinit && \
    echo "continue" >> ~/.gdbinit

WORKDIR /home/aspen

CMD ["/bin/bash", "-l"]
