#!/bin/sh

## Arguments
# $1: JSON string


## Constants

# This jq expression transforms an GitHub inputs object string into shell variables.
# See:
# https://stackoverflow.com/questions/48512914
# https://stackoverflow.com/questions/62312365

JQ_EXPR="$(cat <<-'EOF'
	to_entries | map("\(
		.key | ascii_upcase | gsub("-"; "_") | gsub("^"; "INPUT_")
	)=\(
		.value
	)") | @sh
EOF
)"
JQ_EXPR="$(echo "$JQ_EXPR" | tr '\n' ' ')"


## Main

printf '%s\n' "$1" | jq -r "$JQ_EXPR"
