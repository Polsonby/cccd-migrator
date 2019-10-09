set -ex

# output help for cli tool and keep pod running for 24 hours
bin/migrate -h && sleep 86400
