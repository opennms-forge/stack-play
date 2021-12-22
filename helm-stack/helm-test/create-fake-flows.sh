#!/bin/bash -e

# shellcheck disable=SC2143
if [ -z "$(java -version 2>&1 | grep version | grep 11)" ]; then
	echo "The generator requires java 11.  Unknown version:"
	java -version 2>&1 | grep version
	exit 1
fi

echo "downloading populator jar"
wget --quiet -c -O /tmp/nephron-testing-bundled.jar https://www.opennms.com/~ranger/helm-test/nephron-testing-bundled-0.3.2-SNAPSHOT.jar

echo "creating fake flows in elasticsearch"
java -jar /tmp/nephron-testing-bundled.jar --esRawFlowOutput=ELASTIC_SEARCH
curl -XPUT -H 'Content-Type: application/json' http://localhost:9200/_template/netflow -d@netflow-template.json
