# E2E Verification Results — 2026-08-05

Branch: `ronny-poc/victorialogs-flows` @ f7bc8692b42, image `opennms/horizon:37.0.0-SNAPSHOT` (local build).
Stack: VictoriaLogs v1.52.0, Grafana (host port **3001**), nl6 10 devices IPFIX -> `opennms:9999`.

Grafana history: E2E PASS was verified on `opennms/helm:12.0.1` (Grafana 12.1.2). Afterwards migrated to stock `grafana/grafana-oss:latest` (13.0.2) + `GF_INSTALL_PLUGINS` + `./grafana/provisioning/` (datasources, app enable, plugin-dashboard file provider), mirroring opennms-playground `include/grafana.yml`. Re-verified on the stock stack: plugin 12.0.1 enabled, 4 datasources provisioned, Flow Deep Dive imported (folder "OpenNMS"), `rest/flows` count + top-N apps answer through the datasource proxy (note: Grafana 13 needs the `/api/datasources/proxy/uid/<uid>/` route).

## Gates

- **Gate 0 (first-ever container load): PASS.** `opennms-flows` feature resolved, victorialogs bundle 434 started, blueprint parsed, query service registered at ranking 1000.
- **Gate 1: PASS.** Health check "Connecting to VictoriaLogs (Flows): Success" (cfg overlay read, VL reachable).

## Probes

1. **Sender**: nl6 exporting from 10 per-device source IPs (10.10.0.1-10) to collector 192.168.107.4:9999, 226,560 records cumulative.
2. **Store**: `/insert/jsonline` requests flowing, 0 errors; `vl_rows_ingested_total{type="jsonline"} 111360`, all `vl_rows_dropped_total` = 0. Documents carry full `netflow.*` set, real ifIndexes, direction. Count-gap vs sender = the two outage windows below, no loss in steady state.
3. **REST**: `rest/flows/count` = 51k+ (served by VictoriaLogsFlowQueryService); `rest/flows/exporters` returns all 10 provisioned nodes after requisition import (48 SNMP interfaces/node via routed SNMP).
4. **Dashboard**: app plugin enabled, 3 datasources green via Grafana proxy; Flow Deep Dive auto-imported at `/d/c35cc96b-da0b-4fa9-a947-6f699e24ab78/`; top-5 applications (https/http/domain/ssh classified + Unknown), conversations, hosts series all return correct data. **Visual pass confirmed by Ronny 2026-08-05: WORKS.**

## E2E VERDICT: PASS (2026-08-05)

## Findings (need branch/upstream fixes)

1. **PipelineImpl persister loop has no exception isolation** (`features/flows/processing/.../PipelineImpl.java:139-141`). The unconfigured Elasticsearch repository (default `localhost:9200`) throws on every batch and starves the VictoriaLogs persister. VictoriaLogs got ZERO flows until Elasticsearch persistence was explicitly disabled. Fix: per-persister try/catch (log + continue). This also means: co-deployed ES outage today silently loses the same flows for every other persister.
2. **Hot-applying `skipElasticsearchPersistence=true` did not take effect**: after blueprint reload, the pipeline kept invoking the destroyed elastic repository via a stale proxy ("Request execution cancelled"). Restart required. Same reluctant-rebinding family as documented for the query side.

## Lab workarounds encoded in this directory

- `overlay/etc/org.opennms.features.flows.persistence.elastic.cfg` — `skipElasticsearchPersistence=true` (no ES in lab; see finding 1).
- Device-subnet route dies with every opennms restart. Re-add with the compose one-shot:
  `docker compose run --rm addroute`
- Host port 8080 is shadowed by a local Python process -> use the nl6 container IP for its REST API. Grafana on host port 3001.

## Visual checklist (confirmed 2026-08-05)

http://localhost:3001/d/c35cc96b-da0b-4fa9-a947-6f699e24ab78/ — verified working end to end by visual inspection.
