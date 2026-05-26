# GitHub env and output functions

# Sets a variable in the $GITHUB_ENV
# Arguments
# $1: name of the env variable
# $2: value of the env variable
gh_env_set() {
	printf "$1=%s\n" "$2" >> $GITHUB_ENV
}

# Sets a variable in the $GITHUB_OUTPUT
# Arguments
# $1: name of the output variable
# $2: value of the output variable
gh_output() {
	printf "$1=%s\n" "$2" >> $GITHUB_OUTPUT
}


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
