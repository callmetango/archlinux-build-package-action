ARG DOCKER_IMAGE="docker.io/library/archlinux:multilib-devel"

FROM "$DOCKER_IMAGE"

ARG ADD_PACKAGES
ARG INSTALL_YAY
ARG RUNNER_UID

RUN pacman -Syu --needed --noconfirm git pacman-contrib $ADD_PACKAGES

RUN <<EOF
	if id $RUNNER_UID >/dev/null 2>&1; then
		usermod -d /home/runner -m -l runner
	else
		useradd -d /home/runner -m -u $RUNNER_UID runner
	fi
	echo 'runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

	if  [ "$INSTALL_YAY" = true ]; then
		git clone --depth 1 https://aur.archlinux.org/yay-bin.git
		cd yay-bin && makepkg -si --noconfirm
	fi
EOF

WORKDIR /home/runner
USER runner

RUN <<EOF
	mkdir -p /home/runner/bin
EOF

COPY --chmod=644 config/makepkg.conf /home/runner/.makepkg.conf
COPY --chmod=755 scripts/*.sh /home/runner/bin/
COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
