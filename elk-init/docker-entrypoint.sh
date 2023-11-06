#!/bin/bash

## --- Check elasticsearch status ---
echo 'Waiting for availability of Elasticsearch. This can take several minutes.'
declare -i exit_code=0
# Poll the 'elasticsearch' service until it responds with HTTP code 200.
function wait_for_elasticsearch {
	local -i result=1
	local output

	# retry for max 120s (60*2s)
	for _ in $(seq 1 60); do
	  echo 'Checking elasticsearch...'
		local -i exit_code=0
		output="$(curl -sD -m15 -w '%{http_code}' -u 'elastic:password' http://elasticsearch:9200/)" || exit_code=$?

		if ((exit_code)); then
			result=$exit_code
		fi

		if [[ "${output: -3}" -eq 200 ]]; then
			result=0
			break
		fi

		sleep 2
	done

	if ((result)) && [[ "${output: -3}" -ne 000 ]]; then
		echo -e "\n${output::-3}"
	fi

	return $result
}
wait_for_elasticsearch || exit_code=$?
if ((exit_code)); then
	case $exit_code in
		6)
			echo 'Could not resolve host. Is Elasticsearch running?'
			;;
		7)
			echo 'Failed to connect to host. Is Elasticsearch healthy?'
			;;
		28)
			echo 'Timeout connecting to host. Is Elasticsearch healthy?'
			;;
		*)
			echo "Connection to Elasticsearch failed. Exit code: ${exit_code}"
			;;
	esac

	exit $exit_code
fi
echo 'Elasticsearch is running'


## --- init mapping ---
# echo 'Init mapping'
# function init_mappings {
#   curl -u 'elastic:password' -X DELETE http://elasticsearch:9200/your_index
#   curl -u 'elastic:password' -X PUT http://elasticsearch:9200/your_index
#   curl -u 'elastic:password' -X GET http://elasticsearch:9200/your_index
#   curl -u 'elastic:password' -X PUT http://elasticsearch:9200/your_index/_mapping?pretty -d @initial_mappings.json -H 'Content-Type: application/json'
# }
# init_mappings
# echo 'Init mapping finished'


## --- init users
echo 'Init users'
# Set password of a given Elasticsearch user.
function set_user_password {
	local username=$1
	local password=$2
	local -i result=1
	local output

  echo "Change password for ${username}" 
	output="$(curl -sD -m15 -w '%{http_code}' -u 'elastic:password' -X POST -H 'Content-Type: application/json' -d "{\"password\" : \"${password}\"}" "http://elasticsearch:9200/_security/user/${username}/_password")"
	if [[ "${output: -3}" -eq 200 ]]; then
		result=0
	fi

	if ((result)); then
		echo -e "\n${output::-3}\n"
	fi

	return $result
}
set_user_password "kibana_system" "kibana"
set_user_password "logstash_system" "logstash"
echo 'Init users finished'
