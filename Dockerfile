ARG DOCKER_IMAGE="docker.io/library/archlinux:multilib-devel"

FROM "$DOCKER_IMAGE"

ARG ADD_PACKAGES
ARG INSTALL_YAY
ARG RUNNER_UID

ARG R_USER="runner"
ARG R_HOME="/home/$R_USER"

RUN pacman -Syu --needed --noconfirm git pacman-contrib $ADD_PACKAGES

RUN <<EOF
	if id $RUNNER_UID >/dev/null 2>&1; then
		usermod -d "$R_HOME" -m -l "$R_USER"
	else
		useradd -d "$R_HOME" -m -u $RUNNER_UID "$R_USER"
	fi
	echo "$R_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
EOF


WORKDIR "$R_HOME"
USER "$R_USER"

COPY --chmod=644 config/makepkg.conf .makepkg.conf
COPY --chmod=755 scripts/*.sh bin/
COPY --chmod=755 entrypoint.sh /entrypoint.sh

RUN <<EOF
	cd "$R_HOME" # COPY changes the working directory... :facepalm:
	mkdir -p tmp
	if  [ "$INSTALL_YAY" = true ]; then
		git clone --depth 1 https://aur.archlinux.org/yay-bin.git tmp/yay
		cd tmp/yay && makepkg -si --noconfirm
		cd -
	fi
EOF

ENTRYPOINT ["/entrypoint.sh"]
