#!/bin/sh

key_file="${HOME}/.ssh/id_ed25519"

[ -r "$key_file" ] || exit 0
[ -n "${XDG_RUNTIME_DIR:-}" ] || exit 0
command -v ssh-add >/dev/null 2>&1 || exit 0
command -v ksshaskpass >/dev/null 2>&1 || exit 0

export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-$XDG_RUNTIME_DIR/ssh-agent.socket}"
export SSH_ASKPASS="$(command -v ksshaskpass)"
export SSH_ASKPASS_REQUIRE=force

setsid -f sh -c 'ssh-add "$1" < /dev/null >/dev/null 2>&1' sh "$key_file"
