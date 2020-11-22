#! /usr/bin/env nix-shell
#! nix-shell -i bash -p jq curl
# shellcheck shell=bash

# Check if at least 2 parameters were provided
[ $# -eq 0 ] && {
	echo "Usage: $0 SERVER ACCESS_TOKEN"
	echo "E.g. : $0 127.0.0.1:8448 A_very_long_string_that_is_your_access_token"
	exit 1
}

TEMP_ROOMLIST=$(mktemp)
TEMP_PURGELIST=$(mktemp)

# Fetch list of rooms (limited to a reasonable size to avoid overloading anything)
# FIXME: If you have more rooms this might not fetch all rooms!
curl --header "Authorization: Bearer $2" "http://$1/_synapse/admin/v1/rooms?limit=500" >"${TEMP_ROOMLIST}"

# Extract rooms without local members (we do not partake so we do not care (anymore))
jq '.rooms[] | select(.joined_local_members == 0) | .room_id' <"${TEMP_ROOMLIST}" >"${TEMP_PURGELIST}"

echo '### Room to purge:'
cat "${TEMP_PURGELIST}"

# For each room call the purge_room API endpoint
while IFS="" read -r room || [ -n "$room" ]; do
	curl --header "Authorization: Bearer $2" \
		-X POST -H "Content-Type: application/json" -d "{ \"room_id\": $room }" \
		"http://$1/_synapse/admin/v1/purge_room"
done <"${TEMP_PURGELIST}"

# Cleanup temporary files
rm "${TEMP_ROOMLIST}"
rm "${TEMP_PURGELIST}"
