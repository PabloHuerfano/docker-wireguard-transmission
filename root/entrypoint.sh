#!/bin/bash

set euo -pipefail

# check for wireguard config, then start wireguard
if [ ! -f /etc/wireguard/"$INTERFACE".conf ]
then
  echo "Could not find /etc/wireguard/"$INTERFACE".conf"
  exit 1
fi

if [ -f /etc/wireguard/"$INTERFACE".conf ]
then
    chmod 600 /etc/wireguard/"$INTERFACE".conf
    wg-quick up "$INTERFACE"
fi

# make transmission only use the wireguard interface
if [ ! -z "$KILLSWITCH" ]; then
	WIREGUARDIPV4=$(ip addr show "$KILLSWITCH" | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')
	WIREGUARDIPV6=$(ip addr show "$KILLSWITCH" | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d')
	sed -i "/bind-address-ipv4/c\    \"bind-address-ipv4\": \"$WIREGUARDIPV4\"," /etc/transmission-daemon/settings.json
	sed -i "/bind-address-ipv6/c\    \"bind-address-ipv6\": \"$WIREGUARDIPV6\"," /etc/transmission-daemon/settings.json
fi

# apply TRANSMISSION_ environment variables
tr_settings_file="/etc/transmission-daemon/settings.json"
TR_ENV=${!TRANSMISSION_@}

printf "[INFO] Updating transmission settings.json with the following environment variables: \n${TR_ENV:-none} \n"

for ENV_SETTING in ${TR_ENV}; do
    env_setting=${ENV_SETTING//"TRANSMISSION_"/} # trim TRANSMISSION_
    env_setting=${env_setting,,} # lowercase
    env_setting=${env_setting//_/-} # replace underscore with hyphen
    if [[ -n $(jq --arg key "${env_setting}" < "${tr_settings_file}" '. | select($key)') ]]; then
        printf "[INFO] Updating key:'${env_setting}' with value:'${!ENV_SETTING}' in settings.json \n"
        tmp=$(mktemp)
        if [[ ${!ENV_SETTING} =~ ^[0-9]+$ ]]; then
            jq --arg key "${env_setting}" \
               --arg value "${!ENV_SETTING}" \
               '. | .[$key]=($value|tonumber)' \
               ${tr_settings_file} > "${tmp}" && mv "${tmp}" ${tr_settings_file}
        else
            jq --arg key "${env_setting}" \
               --arg value "${!ENV_SETTING}" \
               '. | .[$key]=$value' \
               ${tr_settings_file} > "${tmp}" && mv "${tmp}" ${tr_settings_file}
        fi
    else
        printf "[WARN] Key ${env_setting} does not exist in settings.json, skipping variable ${ENV_SETTING} \n"
    fi
done

# start transmission
exec /usr/bin/transmission-daemon --foreground --config-dir /etc/transmission-daemon
