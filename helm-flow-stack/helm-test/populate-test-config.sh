#!/bin/bash -e

CURRENT_EPOCH="$(date '+%s')000"

echo "requisitioning test nodes"
curl -X POST -H 'Content-type: application/json' -u admin:admin -d@grafana-test.json 'http://localhost:8980/opennms/rest/requisitions'
curl -X PUT  -H 'Content-type: application/json' -u admin:admin                      'http://localhost:8980/opennms/rest/requisitions/grafana-test/import?rescanExisting=dbonly'

echo "waiting for database to settle"
sleep 20

./create-fake-flows.sh

curl -u admin:admin -H 'Content-type: application/json' -X POST -d@grafana-datasource-entities.json    http://localhost:3000/api/datasources
curl -u admin:admin -H 'Content-type: application/json' -X POST -d@grafana-datasource-flows.json       http://localhost:3000/api/datasources
curl -u admin:admin -H 'Content-type: application/json' -X POST -d@grafana-datasource-performance.json http://localhost:3000/api/datasources

echo "tricking opennms into thinking the fake nodes have SNMP and recent flow data"
for IP in 0 1 2 3 4; do
	((IFINDEX = IP + 1))
	curl -X POST \
		-H 'Content-type: application/json' \
		-u admin:admin \
		-d "{ \"ifIndex\": ${IFINDEX}, \"lastIngressFlow\": ${CURRENT_EPOCH}, \"lastEgressFlow\": ${CURRENT_EPOCH}, \"physAddr\": \"00:00:00:00:00:0${IP}\" }" "http://localhost:8980/opennms/api/v2/nodes/grafana-test:0.0.0.${IP}/snmpinterfaces"
done
