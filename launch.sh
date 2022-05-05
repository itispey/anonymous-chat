#!/usr/bin/env bash

make_template() {
	find . -name "*.lua" | sort |
		xgettext --from-code=utf-8 \
			--add-comments=TRANSLATORS \
			--package-name=GroupButler \
			--package-version=4.2 \
			--msgid-bugs-address=https://telegram.me/baconn \
			--force-po \
			--files-from=/dev/stdin \
			--output=/dev/stdout
}

case $1 in bot | "")
	source .env && export $(cut -d= -f1 .env)
	while true; do
		./polling.lua
		sleep 10
	done
esac
