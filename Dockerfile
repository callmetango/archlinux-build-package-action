# Base image
FROM docker.io/library/archlinux:multilib-devel

# Install dependencies
RUN pacman -Syu --needed --noconfirm pacman-contrib namcap git

# Setup user
RUN useradd -m builder && \
    echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
WORKDIR /home/builder
USER builder

# Install yay
RUN git clone https://aur.archlinux.org/yay-bin.git
RUN cd yay-bin && makepkg -si --noconfirm

# Copy files
COPY github-log.sh LICENSE README.md /
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
