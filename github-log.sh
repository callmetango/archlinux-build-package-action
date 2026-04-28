# GitHub log functions

GL_GROUP_OPEN=0

glgrp() {
	[ $GL_GROUP_OPEN = 1 ] && printf "::endgroup::\n"
	printf "::group::${1}\n"
	GL_GROUP_OPEN=1
}

glgrpend() {
	[ $GL_GROUP_OPEN = 1 ] && printf "::endgroup::\n"
	GL_GROUP_OPEN=0
}

glend() {
	if [ $GL_GROUP_OPEN = 1 ]; then
		printf "::endgroup::\n"
		GL_GROUP_OPEN=0
	fi
}
