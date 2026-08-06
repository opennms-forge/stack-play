# victorialogs-e2e-lab

End-to-end lab for OpenNMS flow persistence in [VictoriaLogs](https://docs.victoriametrics.com/victorialogs/).
The pipeline: [nl6](https://github.com/labmonkeys-space/nl6) simulates devices exporting IPFIX → OpenNMS Horizon (telemetryd + VictoriaLogs flow persistence) → VictoriaLogs → Grafana with the OpenNMS plugin and the Flow Deep Dive dashboard.

The VictoriaLogs flow persistence is not released yet.
It lives on the [`ronny-poc/victorialogs-flows`](https://github.com/OpenNMS/opennms/tree/ronny-poc/victorialogs-flows) branch, so you build the `opennms/horizon:37.0.0-SNAPSHOT` container image locally first.

## Prerequisites

- Docker with Compose v2
- JDK 21 and around 30 GB free disk for the OpenNMS source build
- `expect` on the host if you want to use the `karaf.exp` helper

## 1. Build the Horizon container image from the branch

```bash
git clone https://github.com/OpenNMS/opennms.git
cd opennms
git checkout ronny-poc/victorialogs-flows

# Compile and assemble (takes a while, go get coffee)
./compile.pl -DskipTests
./assemble.pl -Dopennms.home=/opt/opennms -DskipTests

# Build the container image from the assembled tarball
cd opennms-container/core
make image
```

Verify the image exists:

```bash
docker images opennms/horizon
# REPOSITORY        TAG               ...
# opennms/horizon   37.0.0-SNAPSHOT   ...
```

The tag comes from the version in the branch `pom.xml`.
If it differs from `37.0.0-SNAPSHOT`, adjust the `opennms` image tag in `compose.yml`.

## 2. Start the stack

```bash
docker compose up -d
```

Wait until OpenNMS reports healthy (first start takes a few minutes):

```bash
docker compose ps opennms
```

## 3. Route the simulated device subnet

nl6 gives each simulated device its own source IP in `10.10.0.0/16`.
OpenNMS needs a route to that subnet through the nl6 container so SNMP polling and flow attribution work:

```bash
docker compose run --rm addroute
```

The route lives in the OpenNMS container's network namespace and dies with every `opennms` restart.
Re-run the command after each restart.

## 4. Create simulated devices exporting IPFIX

Create 10 devices that export IPFIX to the OpenNMS telemetryd listener on port 9999 (the `Multi-UDP-9999` listener is enabled by default):

```bash
OPENNMS_IP=$(docker compose exec nl6 getent hosts opennms | awk '{print $1}')
curl -s -X POST http://localhost:8080/api/v1/devices \
  -H 'Content-Type: application/json' \
  -d "{\"start_ip\":\"10.10.0.1\",\"device_count\":10,\"netmask\":\"24\",\"flow\":{\"collector\":\"${OPENNMS_IP}:9999\",\"protocol\":\"ipfix\"}}"
```

Check the export status:

```bash
curl -s http://localhost:8080/api/v1/flows/status
```

## 5. Provision the devices as OpenNMS nodes

`onms-provision.sh` reads the devices from the nl6 API and imports them as a requisition:

```bash
./onms-provision.sh --import
```

## 6. Verify

Health check through the Karaf shell (expects "Connecting to VictoriaLogs (Flows): Success"):

```bash
./karaf.exp 'opennms:health-check'
```

Flows arriving through the REST API:

```bash
curl -su admin:admin 'http://localhost:8980/opennms/rest/flows/count?start=-900000'
curl -su admin:admin 'http://localhost:8980/opennms/rest/flows/exporters?start=-900000'
```

Rows ingested into VictoriaLogs:

```bash
curl -s http://localhost:9428/metrics | grep vl_rows_ingested_total
```

Grafana at <http://localhost:3001> (admin/admin) is fully provisioned: OpenNMS datasources, the OpenNMS app plugin, and the Flow Deep Dive dashboard in the "OpenNMS" folder.
Top applications, conversations, and hosts panels should fill up after a few minutes of flow traffic.

## Endpoints

| Service      | URL                            | Credentials |
|--------------|--------------------------------|-------------|
| OpenNMS      | <http://localhost:8980/opennms> | admin/admin |
| Grafana      | <http://localhost:3001>         | admin/admin |
| VictoriaLogs | <http://localhost:9428>         | none        |
| nl6 API      | <http://localhost:8080>         | none        |
| Karaf SSH    | localhost:8101                  | admin/admin |

## Lab notes

- `overlay/etc/org.opennms.features.flows.persistence.victorialogs.cfg` points the persistence and query service at `http://victorialogs:9428`.
- `overlay/etc/org.opennms.features.flows.persistence.elastic.cfg` sets `skipElasticsearchPersistence=true`. There is no Elasticsearch in this lab, and without it the unconfigured Elasticsearch repository throws on every batch and blocks the VictoriaLogs persister.
- `RESULTS.md` documents the verified end-to-end pass this lab is based on, including findings that need fixes on the branch.
