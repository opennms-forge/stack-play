#!/usr/bin/env bash
# Copyright 2026 Ronny Trommer <ronny@no42.org>
# SPDX-License-Identifier: Apache-2.0
#
# onms-provision.sh — generate and import an OpenNMS requisition from nl6 devices
#
# Generic across every example: it reads whatever devices the running nl6
# instance currently exposes (NL6_URL/api/v1/devices), so the same script
# provisions any fabric (5-stage-clos, large-clos, …). Run it after the
# example's own nl6-provision.sh has created the devices.
#
# Usage:
#   ./onms-provision.sh                  # generate XML to stdout
#   ./onms-provision.sh --import         # generate and import into OpenNMS
#   ./onms-provision.sh --import --dry-run  # print what would be imported
#
set -euo pipefail

NL6_URL="${NL6_URL:-http://localhost:8080}"
# One knob for scheme + host + port + context path. Switch http/https or point
# at a remote OpenNMS by setting just this — e.g. OPENNMS_BASE_URL=https://onms:443/opennms
OPENNMS_BASE_URL="${OPENNMS_BASE_URL:-http://localhost:8980/opennms}"
OPENNMS_BASE_URL="${OPENNMS_BASE_URL%/}"   # tolerate a trailing slash
OPENNMS_USER="${OPENNMS_USER:-admin}"
OPENNMS_PASS="${OPENNMS_PASS:-admin}"
FOREIGN_SOURCE="${FOREIGN_SOURCE:-nl6-inventory}"
MINION_LOCATION="${MINION_LOCATION:-Default}"
GNMI_SERVICE="${GNMI_SERVICE:-gNMI-Telemetry}"
OC_PORT="${OC_PORT:-9339}"
OC_MODE="${OC_MODE:-gnmi}"
OC_PATHS="${OC_PATHS:-/interfaces/interface/state/counters,/components/component/state}"

IMPORT=false
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Generate an OpenNMS requisition XML from nl6 simulated devices.

Options:
  --import      Upload the requisition to OpenNMS and trigger an import
  --dry-run     With --import: print the XML without uploading
  -h|--help     Show this message

Environment variables (all optional):
  NL6_URL           nl6 base URL             (default: http://localhost:8080)
  OPENNMS_BASE_URL  OpenNMS base URL incl. scheme, host, port, context path
                    (default: http://localhost:8980/opennms)
  OPENNMS_USER      OpenNMS username         (default: admin)
  OPENNMS_PASS      OpenNMS password         (default: admin)
  FOREIGN_SOURCE    Requisition foreign-source name (default: nl6-inventory)
  MINION_LOCATION   Minion location label    (default: Default)

gNMI / OpenConfig telemetry (per-node requisition metadata, consumed by the
OpenConfigConnector in telemetryd-configuration.xml):
  GNMI_SERVICE      Monitored service that activates the connector (default: gNMI-Telemetry)
  OC_PORT           Device gNMI/gRPC port    (default: 9339, the nl6 gNMI port)
  OC_MODE           Stream mode: gnmi | jti  (default: gnmi)
  OC_PATHS          Comma-separated OpenConfig subscription paths
                    (default: /interfaces/interface/state/counters,/components/component/state)

Examples:
  $0 --import                                        # upload and trigger import
  $0 --import --dry-run                              # preview XML without importing
  OPENNMS_BASE_URL=https://onms:443/opennms $0 --import
  MINION_LOCATION=site-a $0 --import
EOF
}

if [[ $# -eq 0 ]]; then usage; exit 0; fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --import)   IMPORT=true; shift ;;
    --dry-run)  DRY_RUN=true; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Error: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# ── fetch devices + generate requisition XML ──────────────────────────────────
# Python handles both the HTTP fetch (urllib) and XML generation to avoid
# any shell-level HTTP client interception.

# Values reach Python via the environment, not by interpolating into the heredoc
# (note the quoted 'PYEOF'): the shell never expands inside the Python source, so
# a quote or backtick in any of these vars can't break out into code injection.
requisition=$(
  NL6_URL="${NL6_URL}" \
  FOREIGN_SOURCE="${FOREIGN_SOURCE}" \
  MINION_LOCATION="${MINION_LOCATION}" \
  GNMI_SERVICE="${GNMI_SERVICE}" \
  OC_PORT="${OC_PORT}" \
  OC_MODE="${OC_MODE}" \
  OC_PATHS="${OC_PATHS}" \
  python3 - <<'PYEOF'
import json, os, ssl, sys
import urllib.request
from datetime import datetime, timezone
from xml.sax.saxutils import quoteattr

url          = os.environ["NL6_URL"] + "/api/v1/devices"
foreign_source = os.environ["FOREIGN_SOURCE"]
location     = os.environ["MINION_LOCATION"]
gnmi_service = os.environ["GNMI_SERVICE"]
oc_port      = os.environ["OC_PORT"]
oc_mode      = os.environ["OC_MODE"]
oc_paths     = os.environ["OC_PATHS"]

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

try:
    with urllib.request.urlopen(url, context=ctx) as resp:
        data = json.load(resp)
except Exception as e:
    print(f"Error fetching {url}: {e}", file=sys.stderr)
    sys.exit(1)

if not data.get("success"):
    print(f"API error: {data.get('message', 'unknown')}", file=sys.stderr)
    sys.exit(1)

devices = data["data"]
ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

lines = []
lines.append('<?xml version="1.0" encoding="UTF-8"?>')
lines.append(f'<model-import xmlns="http://xmlns.opennms.org/xsd/config/model-import"')
lines.append(f'              date-stamp="{ts}"')
lines.append(f'              foreign-source="{foreign_source}">')

for device in devices:
    node_id = device["id"]
    ip      = device["ip"]
    lines.append(f'    <node location="{location}" foreign-id="{node_id}" node-label="{node_id}">')
    lines.append(f'        <interface ip-addr="{ip}" status="1" snmp-primary="P">')
    lines.append( '            <monitored-service service-name="ICMP"/>')
    lines.append( '            <monitored-service service-name="SNMP"/>')
    lines.append(f'            <monitored-service service-name={quoteattr(gnmi_service)}/>')
    lines.append( '        </interface>')
    # Geolocation asset fields (from the nl6 device API). Exact coordinates win
    # when present; the city name is emitted as an OpenNMS geocoder fallback and for
    # readability. Asset elements precede meta-data per the requisition schema.
    lat = device.get("latitude")
    lng = device.get("longitude")
    if lat is not None and lng is not None:
        try:
            lat_f, lng_f = float(lat), float(lng)
            lines.append(f'        <asset name="latitude" value={quoteattr(f"{lat_f}")}/>')
            lines.append(f'        <asset name="longitude" value={quoteattr(f"{lng_f}")}/>')
        except (TypeError, ValueError):
            pass
    loc = device.get("location")
    if loc:
        # quoteattr() escapes commas/non-ASCII (e.g. "Tōkyō, Japan").
        lines.append(f'        <asset name="city" value={quoteattr(str(loc))}/>')
    # OpenConfig connector config (per node); overrides telemetryd-configuration.xml defaults.
    # quoteattr() escapes XML metacharacters — gNMI paths legitimately contain [name="..."].
    lines.append(f'        <meta-data context="requisition" key="oc.port" value={quoteattr(oc_port)}/>')
    lines.append(f'        <meta-data context="requisition" key="oc.mode" value={quoteattr(oc_mode)}/>')
    lines.append(f'        <meta-data context="requisition" key="oc.paths" value={quoteattr(oc_paths)}/>')
    lines.append( '    </node>')

lines.append('</model-import>')
print("\n".join(lines))
PYEOF
)

# ── output or import ──────────────────────────────────────────────────────────

if ! $IMPORT; then
  echo "$requisition"
  exit 0
fi

node_count=$(echo "$requisition" | grep -c '<node ')
echo "Importing ${node_count} devices into OpenNMS as foreign-source '${FOREIGN_SOURCE}'..."

if $DRY_RUN; then
  echo "--- dry-run: requisition XML ---"
  echo "$requisition"
  exit 0
fi

opennms_base="${OPENNMS_BASE_URL}"
# --fail-with-body: exit non-zero on an HTTP >= 400 (auth failure, bad XML,
# duplicate foreign-source, …) while still printing the response body, so a
# rejected upload/import reports the error instead of a misleading "done".
curl_opts=(-sk --fail-with-body -u "${OPENNMS_USER}:${OPENNMS_PASS}" -H "Content-Type: application/xml" -H "Accept: application/xml")

tmp=$(mktemp /tmp/onms-provision.XXXXXX.xml)
chmod 600 "$tmp"
trap 'rm -f "$tmp"' EXIT
printf '%s' "$requisition" > "$tmp"

echo -n "Uploading requisition  ... "
if ! curl "${curl_opts[@]}" -X POST -d "@${tmp}" \
     "${opennms_base}/rest/requisitions"; then
  echo "FAILED (see response above)" >&2
  exit 1
fi
echo "done"

echo -n "Triggering import      ... "
if ! curl "${curl_opts[@]}" -X PUT \
     "${opennms_base}/rest/requisitions/${FOREIGN_SOURCE}/import?rescanExisting=false"; then
  echo "FAILED (see response above)" >&2
  exit 1
fi
echo "done"

