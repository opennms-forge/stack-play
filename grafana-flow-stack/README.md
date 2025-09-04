# Test Environment for Grafana

1. edit `docker-compose.yaml` and change `GF_INSTALL_PLUGINS` to point to the Helm plugin you want to use
2. run `docker-compose up` to launch OpenNMS Horizon and related tools
3. wait until http://localhost:8980/opennms/ works
4. make sure JDK11 is in your path: `export PATH=/path/to/jdk11/java/home/bin:$PATH`
5. `cd` to the `flow-test` directory and run `./populate-test-config.sh`
6. go to http://localhost:3000/ and enable the OpenNMS plugin (datasources should already be populated)

This script creates some nodes, enables flows on them, and populates elasticsearch with fake flow data.

If you want to add more flow data, you can run the `./create-fake-flows.sh` script in the `flow-test` directory again.
