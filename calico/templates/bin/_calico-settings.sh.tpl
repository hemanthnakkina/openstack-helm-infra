#!/bin/sh

set -eux

{{- $envAll := . }}

{{ if empty .Values.conf.node.CALICO_IPV4POOL_CIDR }}
{{ $_ := set .Values.conf.node "CALICO_IPV4POOL_CIDR" .Values.networking.podSubnet }}
{{ end }}

# An idempotent script for interacting with calicoctl to instantiate
# peers, and manipulate calico settings that we must perform
# post-deployment.

CTL=/calicoctl

# Generate configuration the way we want it to be, it doesn't matter
# if it's already set, in that case Calico will no nothing.

# BGPConfiguration: nodeToNodeMeshEnabled & asNumber
$CTL apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: {{ .Values.networking.settings.mesh }}
  asNumber: {{ .Values.networking.bgp.asnumber }}
EOF

# FelixConfiguration: ipipEnabled
$CTL apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: FelixConfiguration
metadata:
  name: default
spec:
  ipipEnabled: {{ .Values.networking.settings.ipipEnabled }}
  logSeverityScreen: Info
EOF

# ipPool - https://docs.projectcalico.org/v3.2/reference/calicoctl/resources/ippool
$CTL apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: {{ $ippool.name }}
 spec:
  cidr: {{ $ippool.spec.cidr }}
{{- if $ippool.sepc.blockSize }}
  blockSize: {{ $ippool.sepc.blockSize }}
{{- end }}
  ipipMode: {{ $ippool.spec.ipipMode }}
  natOutgoing: {{ $ippool.spec.natOutgoing }}
  disabled: {{ $ippool.spec.disabled }}
EOF

{{- end }}

# IPv4 peers
{{ if .Values.networking.bgp.ipv4.peers }}
$CTL apply -f - <<EOF
{{ .Values.networking.bgp.ipv4.peers | toYaml }}
EOF
{{ end }}

# IPv6 peers
{{ if .Values.networking.bgp.ipv6.peers }}
$CTL apply -f - <<EOF
{{ .Values.networking.bgp.ipv6.peers | toYaml }}
EOF
{{ end }}

{{/* gotpl quirks mean it is easier to loop from 0 to 9 looking for a match in an inner loop than trying to extract and sort */}}
{{ if .Values.networking.policy }}
# Policy and Endpoint rules
{{ range $n, $data := tuple 0 1 2 3 4 5 6 7 8 9 }}
# Priority: {{ $n }} objects
{{- range $section, $data := $envAll.Values.networking.policy }}
{{- if eq (toString $data.priority) (toString $n) }}
# Section: {{ $section }} Priority: {{ $data.priority }} {{ $n }}
$CTL apply -f - <<EOF
{{ $data.rules | toYaml }}
EOF
{{- end }}
{{- end }}
{{- end }}
{{ end }}

exit 0
