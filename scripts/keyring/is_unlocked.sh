#!/usr/bin/env bash

# Reports whether the keyring collection secret-tool would actually read is
# unlocked. That is the *default* collection (the `default` alias), not the
# classic `login` one, which may be locked in setups where the shell's data
# lives elsewhere - checking the wrong collection reports "locked" for a
# session whose keyring is in fact open.

default_path=$(busctl --user call org.freedesktop.secrets \
    /org/freedesktop/secrets \
    org.freedesktop.Secret.Service ReadAlias s default 2>/dev/null \
    | awk '{print $NF}' | tr -d '"')

if [[ -z "${default_path}" || "${default_path}" == "/" ]]; then
    default_path="/org/freedesktop/secrets/collection/login"
fi

locked_state=$(busctl --user get-property org.freedesktop.secrets \
    "${default_path}" \
    org.freedesktop.Secret.Collection Locked 2>/dev/null)

if [[ "${locked_state}" == "b false" ]]; then
    echo "Keyring is unlocked (${default_path})" >&2
    exit 0
else
    echo "Keyring is locked (${default_path})" >&2
    exit 1
fi
