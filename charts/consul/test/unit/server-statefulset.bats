#!/usr/bin/env bats

load _helpers

@test "server/StatefulSet: enabled by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: enable with global.enabled false" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.enabled=false' \
      --set 'server.enabled=true' \
      . | tee /dev/stderr |
      yq 'length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: disable with server.enabled" {
  cd `chart_dir`
  assert_empty helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.enabled=false' \
      .
}

@test "server/StatefulSet: disable with global.enabled" {
  cd `chart_dir`
  assert_empty helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.enabled=false' \
      .
}

#--------------------------------------------------------------------
# retry-join

@test "server/StatefulSet: retry join gets populated" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.replicas=3' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].command | any(contains("-retry-join"))' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# image

@test "server/StatefulSet: image defaults to global.image" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.image=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "foo" ]
}

@test "server/StatefulSet: image can be overridden with server.image" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.image=foo' \
      --set 'server.image=bar' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].image' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

#--------------------------------------------------------------------
# resources

@test "server/StatefulSet: resources defined by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq -rc '.spec.template.spec.containers[0].resources' | tee /dev/stderr)
  [ "${actual}" = '{"limits":{"cpu":"100m","memory":"100Mi"},"requests":{"cpu":"100m","memory":"100Mi"}}' ]
}

@test "server/StatefulSet: resources can be overridden" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.resources.foo=bar' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].resources.foo' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

# Test support for the deprecated method of setting a YAML string.
@test "server/StatefulSet: resources can be overridden with string" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.resources=foo: bar' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].resources.foo' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

#--------------------------------------------------------------------
# updateStrategy (derived from updatePartition)

@test "server/StatefulSet: no updateStrategy when not updating" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.updateStrategy' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "server/StatefulSet: updateStrategy during update" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.updatePartition=2' \
      . | tee /dev/stderr |
      yq -r '.spec.updateStrategy.type' | tee /dev/stderr)
  [ "${actual}" = "RollingUpdate" ]

  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.updatePartition=2' \
      . | tee /dev/stderr |
      yq -r '.spec.updateStrategy.rollingUpdate.partition' | tee /dev/stderr)
  [ "${actual}" = "2" ]
}

#--------------------------------------------------------------------
# storageClass

@test "server/StatefulSet: no storageClass on claim by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.volumeClaimTemplates[0].spec.storageClassName' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "server/StatefulSet: can set storageClass" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.storageClass=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.volumeClaimTemplates[0].spec.storageClassName' | tee /dev/stderr)
  [ "${actual}" = "foo" ]
}

#--------------------------------------------------------------------
# serverCert

@test "server/StatefulSet: consul-server-cert uses default cert when serverCert.secretName not set" {
    cd `chart_dir`
    local object=$(helm template \
        -s templates/server-statefulset.yaml \
        --set 'global.tls.enabled=true' \
        --set 'server.serverCert.secretName=null' \
        . | tee /dev/stderr )

    local actual=$(echo "$object" |
        yq -r '.spec.template.spec.volumes[2].secret.secretName' | tee /dev/stderr)
    [ "${actual}" = "RELEASE-NAME-consul-server-cert" ]
}

@test "server/StatefulSet: consul-server-cert uses serverCert.secretName when serverCert (and caCert) are set" {
    cd `chart_dir`
    local object=$(helm template \
        -s templates/server-statefulset.yaml \
        --set 'global.tls.enabled=true' \
        --set 'global.tls.caCert.secretName=ca-cert' \
        --set 'server.serverCert.secretName=server-cert' \
        . | tee /dev/stderr )

    local actual=$(echo "$object" |
        yq -r '.spec.template.spec.volumes[2].secret.secretName' | tee /dev/stderr)
    [ "${actual}" = "server-cert" ]
}

@test "server/StatefulSet: when server.serverCert.secretName!=null and global.tls.caCert.secretName=null, fail" {
    cd `chart_dir`
    run helm template \
        -s templates/server-statefulset.yaml \
        --set 'global.tls.enabled=true' \
        --set 'server.serverCert.secretName=server-cert' \
        .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "If server.serverCert.secretName is provided, global.tls.caCert must also be provided" ]]
}
#--------------------------------------------------------------------
# exposeGossipAndRPCPorts

@test "server/StatefulSet: server gossip and RPC ports are not exposed by default" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr )

  # Test that hostPort is not set for gossip ports
  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "serflan-tcp")' | yq -r '.hostPort' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "serflan-udp")' | yq -r '.hostPort' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "serfwan-tcp")' | yq -r '.hostPort' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "serfwan-udp")' | yq -r '.hostPort' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  # Test that hostPort is not set for rpc ports
  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "server")' | yq -r '.hostPort' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  # Test that ADVERTISE_IP is being set to podIP
  local actual=$(echo "$object" |
    yq -r -c '.spec.template.spec.containers[0].env | map(select(.name == "ADVERTISE_IP"))' | tee /dev/stderr)
  [ "${actual}" = '[{"name":"ADVERTISE_IP","valueFrom":{"fieldRef":{"fieldPath":"status.podIP"}}}]' ]
}

@test "server/StatefulSet: server gossip and RPC ports can be exposed" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.exposeGossipAndRPCPorts=true' \
      . | tee /dev/stderr)

  # Test that hostPort is set for gossip ports
  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "serflan-tcp")' | yq -r '.hostPort' | tee /dev/stderr)
  [ "${actual}" = "8301" ]

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "serflan-udp")' | yq -r '.hostPort' | tee /dev/stderr)
  [ "${actual}" = "8301" ]

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "serfwan-tcp")' | yq -r '.hostPort' | tee /dev/stderr)
  [ "${actual}" = "8302" ]

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "serfwan-udp")' | yq -r '.hostPort' | tee /dev/stderr)
  [ "${actual}" = "8302" ]

  # Test that hostPort is set for rpc ports
  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "server")' | yq -r '.hostPort' | tee /dev/stderr)
  [ "${actual}" = "8300" ]

  # Test that ADVERTISE_IP is being set to hostIP
  local actual=$(echo "$object" |
    yq -r -c '.spec.template.spec.containers[0].env | map(select(.name == "ADVERTISE_IP"))' | tee /dev/stderr)
  [ "${actual}" = '[{"name":"ADVERTISE_IP","valueFrom":{"fieldRef":{"fieldPath":"status.hostIP"}}}]' ]

}

#--------------------------------------------------------------------
# serflan

@test "server/StatefulSet: server.ports.serflan.port is set to 8301 by default" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr )

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "serflan-tcp")' | yq -r '.containerPort' | tee /dev/stderr)
  [ "${actual}" = "8301" ]

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "serflan-udp")' | yq -r '.containerPort' | tee /dev/stderr)
  [ "${actual}" = "8301" ]

  local command=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].command' | tee /dev/stderr)

  local actual=$(echo $command | jq -r ' . | any(contains("-serf-lan-port=8301"))' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: server.ports.serflan.port can be customized" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.ports.serflan.port=9301' \
      . | tee /dev/stderr )

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "serflan-tcp")' | yq -r '.containerPort' | tee /dev/stderr)
  [ "${actual}" = "9301" ]

  local actual=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].ports[] | select(.name == "serflan-udp")' | yq -r '.containerPort' | tee /dev/stderr)
  [ "${actual}" = "9301" ]

  local command=$(echo "$object" |
      yq -r '.spec.template.spec.containers[0].command' | tee /dev/stderr)

  local actual=$(echo $command | jq -r ' . | any(contains("-serf-lan-port=9301"))' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: retry join uses server.ports.serflan.port" {
  cd `chart_dir`
  local command=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.replicas=3' \
      --set 'server.ports.serflan.port=9301' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].command' | tee /dev/stderr)

  local actual=$(echo $command | jq -r ' . | any(contains("-retry-join=\"${CONSUL_FULLNAME}-server-0.${CONSUL_FULLNAME}-server.${NAMESPACE}.svc:9301\""))' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $command | jq -r ' . | any(contains("-retry-join=\"${CONSUL_FULLNAME}-server-1.${CONSUL_FULLNAME}-server.${NAMESPACE}.svc:9301\""))' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $command | jq -r ' . | any(contains("-retry-join=\"${CONSUL_FULLNAME}-server-2.${CONSUL_FULLNAME}-server.${NAMESPACE}.svc:9301\""))' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# extraVolumes

@test "server/StatefulSet: adds extra volume" {
  cd `chart_dir`

  # Test that it defines it
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=configMap' \
      --set 'server.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.volumes[] | select(.name == "userconfig-foo")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.configMap.name' | tee /dev/stderr)
  [ "${actual}" = "foo" ]

  local actual=$(echo $object |
      yq -r '.configMap.secretName' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  # Test that it mounts it
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=configMap' \
      --set 'server.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "userconfig-foo")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.readOnly' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object |
      yq -r '.mountPath' | tee /dev/stderr)
  [ "${actual}" = "/consul/userconfig/foo" ]

  # Doesn't load it
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=configMap' \
      --set 'server.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].command | map(select(test("userconfig"))) | length' | tee /dev/stderr)
  [ "${actual}" = "0" ]
}

@test "server/StatefulSet: adds extra secret volume" {
  cd `chart_dir`

  # Test that it defines it
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=secret' \
      --set 'server.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.volumes[] | select(.name == "userconfig-foo")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.secret.name' | tee /dev/stderr)
  [ "${actual}" = "null" ]

  local actual=$(echo $object |
      yq -r '.secret.secretName' | tee /dev/stderr)
  [ "${actual}" = "foo" ]

  # Test that it mounts it
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=configMap' \
      --set 'server.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "userconfig-foo")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.readOnly' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  local actual=$(echo $object |
      yq -r '.mountPath' | tee /dev/stderr)
  [ "${actual}" = "/consul/userconfig/foo" ]

  # Doesn't load it
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=configMap' \
      --set 'server.extraVolumes[0].name=foo' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].command | map(select(test("userconfig"))) | length' | tee /dev/stderr)
  [ "${actual}" = "0" ]
}

@test "server/StatefulSet: adds loadable volume" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=configMap' \
      --set 'server.extraVolumes[0].name=foo' \
      --set 'server.extraVolumes[0].load=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].command | map(select(test("/consul/userconfig/foo"))) | length' | tee /dev/stderr)
  [ "${actual}" = "1" ]
}

@test "server/StatefulSet: adds extra secret volume with items" {
  cd `chart_dir`

  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraVolumes[0].type=secret' \
      --set 'server.extraVolumes[0].name=foo' \
      --set 'server.extraVolumes[0].items[0].key=key' \
      --set 'server.extraVolumes[0].items[0].path=path' \
      . | tee /dev/stderr |
      yq -c '.spec.template.spec.volumes[] | select(.name == "userconfig-foo")' | tee /dev/stderr)
  [ "${actual}" = "{\"name\":\"userconfig-foo\",\"secret\":{\"secretName\":\"foo\",\"items\":[{\"key\":\"key\",\"path\":\"path\"}]}}" ]
}

#--------------------------------------------------------------------
# affinity

@test "server/StatefulSet: affinity not set with server.affinity=null" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.affinity=null' \
      . | tee /dev/stderr |
      yq '.spec.template.spec | .affinity? == null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: affinity set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec.affinity | .podAntiAffinity? != null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# nodeSelector

@test "server/StatefulSet: nodeSelector is not set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec.nodeSelector' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "server/StatefulSet: specified nodeSelector" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml \
      --set 'server.nodeSelector=testing' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.nodeSelector' | tee /dev/stderr)
  [ "${actual}" = "testing" ]
}

#--------------------------------------------------------------------
# priorityClassName

@test "server/StatefulSet: priorityClassName is not set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml \
      . | tee /dev/stderr |
      yq '.spec.template.spec.priorityClassName' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

@test "server/StatefulSet: specified priorityClassName" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml \
      --set 'server.priorityClassName=testing' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.priorityClassName' | tee /dev/stderr)
  [ "${actual}" = "testing" ]
}

#--------------------------------------------------------------------
# extraLabels

@test "server/StatefulSet: no extra labels defined by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.labels | del(."app") | del(."chart") | del(."release") | del(."component") | del(."hasDNS")' | tee /dev/stderr)
  [ "${actual}" = "{}" ]
}

@test "server/StatefulSet: extra labels can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraLabels.foo=bar' \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.labels.foo' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

@test "server/StatefulSet: multiple extra labels can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraLabels.foo=bar' \
      --set 'server.extraLabels.baz=qux' \
      . | tee /dev/stderr)
  local actualFoo=$(echo "${actual}" | yq -r '.spec.template.metadata.labels.foo' | tee /dev/stderr)
  local actualBaz=$(echo "${actual}" | yq -r '.spec.template.metadata.labels.baz' | tee /dev/stderr)
  [ "${actualFoo}" = "bar" ]
  [ "${actualBaz}" = "qux" ]
}

#--------------------------------------------------------------------
# annotations

@test "server/StatefulSet: no annotations defined by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations | del(."consul.hashicorp.com/connect-inject") | del(."consul.hashicorp.com/config-checksum")' | tee /dev/stderr)
  [ "${actual}" = "{}" ]
}

@test "server/StatefulSet: annotations can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.annotations=foo: bar' \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations.foo' | tee /dev/stderr)
  [ "${actual}" = "bar" ]
}

#--------------------------------------------------------------------
# metrics

@test "server/StatefulSet: when global.metrics.enableAgentMetrics=true, adds prometheus scrape=true annotations" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.metrics.enabled=true'  \
      --set 'global.metrics.enableAgentMetrics=true'  \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations."prometheus.io/scrape"' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: when global.metrics.enableAgentMetrics=true, adds prometheus port=8500 annotation" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.metrics.enabled=true'  \
      --set 'global.metrics.enableAgentMetrics=true'  \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations."prometheus.io/port"' | tee /dev/stderr)
  [ "${actual}" = "8500" ]
}

@test "server/StatefulSet: when global.metrics.enableAgentMetrics=true, adds prometheus path=/v1/agent/metrics annotation" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.metrics.enabled=true'  \
      --set 'global.metrics.enableAgentMetrics=true'  \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations."prometheus.io/path"' | tee /dev/stderr)
  [ "${actual}" = "/v1/agent/metrics" ]
}

@test "server/StatefulSet: when global.metrics.enableAgentMetrics=true, sets telemetry flag" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.metrics.enabled=true'  \
      --set 'global.metrics.enableAgentMetrics=true'  \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("telemetry { prometheus_retention_time = \"1m\" }")' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: when global.metrics.enableAgentMetrics=true and global.metrics.agentMetricsRetentionTime is set, sets telemetry flag with updated retention time" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.metrics.enabled=true'  \
      --set 'global.metrics.enableAgentMetrics=true'  \
      --set 'global.metrics.agentMetricsRetentionTime=5m'  \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("telemetry { prometheus_retention_time = \"5m\" }")' | tee /dev/stderr)

  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: when global.metrics.enableAgentMetrics=true, global.tls.enabled=true and global.tls.httpsOnly=true, fail" {
  cd `chart_dir`
  run helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.metrics.enabled=true'  \
      --set 'global.metrics.enableAgentMetrics=true'  \
      --set 'global.tls.enabled=true'  \
      --set 'global.tls.httpsOnly=true'  \
      .

  [ "$status" -eq 1 ]
  [[ "$output" =~ "global.metrics.enableAgentMetrics cannot be enabled if TLS (HTTPS only) is enabled" ]]
}

#--------------------------------------------------------------------
# config-configmap

@test "server/StatefulSet: adds config-checksum annotation when extraConfig is blank" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations."consul.hashicorp.com/config-checksum"' | tee /dev/stderr)
  [ "${actual}" = df8f3705556144cfb39ae46653965f84faf85001af69306f74d01793503908f4 ]
}

@test "server/StatefulSet: adds config-checksum annotation when extraConfig is provided" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraConfig="{\"hello\": \"world\"}"' \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations."consul.hashicorp.com/config-checksum"' | tee /dev/stderr)
  [ "${actual}" = a97d7f332bb6585541f1eab2d1782f8b00bd16b883c34b2db3dd3ce7d67ba39e ]
}

@test "server/StatefulSet: adds config-checksum annotation when config is updated" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.acls.manageSystemACLs=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.metadata.annotations."consul.hashicorp.com/config-checksum"' | tee /dev/stderr)
  [ "${actual}" = 023154f44972402c58062dbb8ab09095563dd99c23b9dab9d51d705486e767b7 ]
}

#--------------------------------------------------------------------
# tolerations

@test "server/StatefulSet: tolerations not set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec | .tolerations? == null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: tolerations can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.tolerations=foobar' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.tolerations == "foobar"' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# tolerations

@test "server/StatefulSet: topologySpreadConstraints not set by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec | .topologySpreadConstraints? == null' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: topologySpreadConstraints can be set" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.topologySpreadConstraints=foobar' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.topologySpreadConstraints == "foobar"' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  # todo: test for Kube versions < 1.18 when helm supports --kube-version flag (https://github.com/helm/helm/pull/9040)
  # not supported before 1.18
  # run helm template \
  #     -s templates/server-statefulset.yaml  \
  #     --kube-version "1.17" \
  #     .
  # [ "$status" -eq 1 ]
  # [[ "$output" =~ "`topologySpreadConstraints` requires Kubernetes 1.18 and above." ]]
}

#--------------------------------------------------------------------
# global.openshift.enabled & server.securityContext

@test "server/StatefulSet: setting server.disableFsGroupSecurityContext fails" {
  cd `chart_dir`
  run helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.disableFsGroupSecurityContext=true' .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "server.disableFsGroupSecurityContext has been removed. Please use global.openshift.enabled instead." ]]
}

@test "server/StatefulSet: securityContext is not set when global.openshift.enabled=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.openshift.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.securityContext' | tee /dev/stderr)
  [ "${actual}" = "null" ]
}

#--------------------------------------------------------------------
# server.securityContext

@test "server/StatefulSet: sets default security context settings" {
  cd `chart_dir`
  local security_context=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.securityContext' | tee /dev/stderr)

  local actual=$(echo $security_context | jq -r .runAsNonRoot)
  [ "${actual}" = "true" ]

  local actual=$(echo $security_context | jq -r .fsGroup)
  [ "${actual}" = "1000" ]

  local actual=$(echo $security_context | jq -r .runAsUser)
  [ "${actual}" = "100" ]

  local actual=$(echo $security_context | jq -r .runAsGroup)
  [ "${actual}" = "1000" ]
}

@test "server/StatefulSet: can overwrite security context settings" {
  cd `chart_dir`
  local security_context=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.securityContext.runAsNonRoot=false' \
      --set 'server.securityContext.privileged=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.securityContext' | tee /dev/stderr)

  local actual=$(echo $security_context | jq -r .runAsNonRoot)
  [ "${actual}" = "false" ]

  local actual=$(echo $security_context | jq -r .privileged)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# server.containerSecurityContext

@test "server/StatefulSet: Can set container level securityContexts" {
  cd `chart_dir`
  local manifest=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.containerSecurityContext.server.privileged=false' \
      . | tee /dev/stderr)

  local actual=$(echo "$manifest" | yq -r '.spec.template.spec.containers | map(select(.name == "consul")) | .[0].securityContext.privileged')
  [ "${actual}" = "false" ]
}

#--------------------------------------------------------------------
# global.openshift.enabled & client.containerSecurityContext

@test "client/DaemonSet: container level securityContexts are not set when global.openshift.enabled=true" {
  cd `chart_dir`
  local manifest=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.openshift.enabled=true' \
      --set 'server.containerSecurityContext.server.privileged=false' \
      . | tee /dev/stderr)

  local actual=$(echo "$manifest" | yq -r '.spec.template.spec.containers | map(select(.name == "consul")) | .[0].securityContext')
  [ "${actual}" = "null" ]
}

#--------------------------------------------------------------------
# gossip encryption

@test "server/StatefulSet: gossip encryption disabled in server StatefulSet by default" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[] | select(.name=="consul") | .env[] | select(.name == "GOSSIP_KEY") | length > 0' | tee /dev/stderr)
  [ "${actual}" = "" ]
}

@test "server/StatefulSet: gossip encryption disabled in server StatefulSet when secretName is missing" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.gossipEncryption.secretKey=bar' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[] | select(.name=="consul") | .env[] | select(.name == "GOSSIP_KEY") | length > 0' | tee /dev/stderr)
  [ "${actual}" = "" ]
}

@test "server/StatefulSet: gossip encryption disabled in server StatefulSet when secretKey is missing" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.gossipEncryption.secretName=foo' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[] | select(.name=="consul") | .env[] | select(.name == "GOSSIP_KEY") | length > 0' | tee /dev/stderr)
  [ "${actual}" = "" ]
}

@test "server/StatefulSet: gossip environment variable present in server StatefulSet when all config is provided" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.gossipEncryption.secretKey=foo' \
      --set 'global.gossipEncryption.secretName=bar' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[] | select(.name=="consul") | .env[] | select(.name == "GOSSIP_KEY") | length > 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: encrypt CLI option not present in server StatefulSet when encryption disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[] | select(.name=="consul") | .command | join(" ") | contains("encrypt")' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server/StatefulSet: encrypt CLI option present in server StatefulSet when all config is provided" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.gossipEncryption.secretKey=foo' \
      --set 'global.gossipEncryption.secretName=bar' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[] | select(.name=="consul") | .command | join(" ") | contains("encrypt")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# extraEnvironmentVariables

@test "server/StatefulSet: custom environment variables" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraEnvironmentVars.custom_proxy=fakeproxy' \
      --set 'server.extraEnvironmentVars.no_proxy=custom_no_proxy' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r 'map(select(.name == "custom_proxy")) | .[0].value' | tee /dev/stderr)
  [ "${actual}" = "fakeproxy" ]

  local actual=$(echo $object |
      yq -r 'map(select(.name == "no_proxy")) | .[0].value' | tee /dev/stderr)
  [ "${actual}" = "custom_no_proxy" ]
}

#--------------------------------------------------------------------
# global.tls.enabled

@test "server/StatefulSet: CA volume present when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.volumes[] | select(.name == "consul-ca-cert")' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "server/StatefulSet: server volume present when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.volumes[] | select(.name == "consul-server-cert")' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "server/StatefulSet: CA volume mounted when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "consul-ca-cert")' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "server/StatefulSet: server certificate volume mounted when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "consul-server-cert")' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "server/StatefulSet: port 8501 is not exposed when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].ports[] | select (.containerPort == 8501)' | tee /dev/stderr)
  [ "${actual}" == "" ]
}

@test "server/StatefulSet: port 8501 is exposed when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].ports[] | select (.containerPort == 8501)' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "server/StatefulSet: port 8500 is still exposed when httpsOnly is not enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.httpsOnly=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].ports[] | select (.containerPort == 8500)' | tee /dev/stderr)
  [ "${actual}" != "" ]
}

@test "server/StatefulSet: port 8500 is not exposed when httpsOnly is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.httpsOnly=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].ports[] | select (.containerPort == 8500)' | tee /dev/stderr)
  [ "${actual}" == "" ]
}

@test "server/StatefulSet: readiness checks are over HTTP when TLS is disabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].readinessProbe.exec.command | join(" ") | contains("http://127.0.0.1:8500")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: readiness checks are over HTTPS when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].readinessProbe.exec.command | join(" ") | contains("https://127.0.0.1:8501")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: CA certificate is specified when TLS is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].readinessProbe.exec.command | join(" ") | contains("--cacert /consul/tls/ca/tls.crt")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: HTTP is disabled in agent when httpsOnly is enabled" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.httpsOnly=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("ports { http = -1 }")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: sets Consul environment variables when global.tls.enabled" {
  cd `chart_dir`
  local env=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[0].env[]' | tee /dev/stderr)

  local actual
  actual=$(echo $env | jq -r '. | select(.name == "CONSUL_HTTP_ADDR") | .value' | tee /dev/stderr)
  [ "${actual}" = "https://localhost:8501" ]

  actual=$(echo $env | jq -r '. | select(.name == "CONSUL_CACERT") | .value' | tee /dev/stderr)
    [ "${actual}" = "/consul/tls/ca/tls.crt" ]
}

@test "server/StatefulSet: sets verify_* flags to true by default when global.tls.enabled" {
  cd `chart_dir`
  local command=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ")' | tee /dev/stderr)

  local actual
  actual=$(echo $command | jq -r '. | contains("verify_incoming_rpc = true")' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  actual=$(echo $command | jq -r '. | contains("verify_outgoing = true")' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  actual=$(echo $command | jq -r '. | contains("verify_server_hostname = true")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: doesn't set the verify_* flags by default when global.tls.enabled and global.tls.verify is false" {
  cd `chart_dir`
  local command=$(helm template \
      -s templates/server-statefulset.yaml \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.verify=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ")' | tee /dev/stderr)

  local actual
  actual=$(echo $command | jq -r '. | contains("verify_incoming_rpc = true")' | tee /dev/stderr)
  [ "${actual}" = "false" ]

  actual=$(echo $command | jq -r '. | contains("verify_outgoing = true")' | tee /dev/stderr)
  [ "${actual}" = "false" ]

  actual=$(echo $command | jq -r '. | contains("verify_server_hostname = true")' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

@test "server/StatefulSet: can overwrite CA secret with the provided one" {
  cd `chart_dir`
  local ca_cert_volume=$(helm template \
      -s templates/server-statefulset.yaml \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.caCert.secretName=foo-ca-cert' \
      --set 'global.tls.caCert.secretKey=key' \
      --set 'global.tls.caKey.secretName=foo-ca-key' \
      --set 'global.tls.caKey.secretKey=key' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.volumes[] | select(.name=="consul-ca-cert")' | tee /dev/stderr)

  # check that the provided ca cert secret is attached as a volume
  local actual
  actual=$(echo $ca_cert_volume | jq -r '.secret.secretName' | tee /dev/stderr)
  [ "${actual}" = "foo-ca-cert" ]

  # check that the volume uses the provided secret key
  actual=$(echo $ca_cert_volume | jq -r '.secret.items[0].key' | tee /dev/stderr)
  [ "${actual}" = "key" ]
}

#--------------------------------------------------------------------
# global.federation.enabled

@test "server/StatefulSet: fails when federation.enabled=true and tls.enabled=false" {
  cd `chart_dir`
  run helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.federation.enabled=true' .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "If global.federation.enabled is true, global.tls.enabled must be true because federation is only supported with TLS enabled" ]]
}

@test "server/StatefulSet: mesh gateway federation enabled when federation.enabled=true" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.federation.enabled=true' \
      --set 'global.tls.enabled=true' \
      --set 'meshGateway.enabled=true' \
      --set 'connectInject.enabled=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("connect { enable_mesh_gateway_wan_federation = true }")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: mesh gateway federation not enabled when federation.enabled=false" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.federation.enabled=false' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("connect { enable_mesh_gateway_wan_federation = true }")' | tee /dev/stderr)
  [ "${actual}" = "false" ]
}

#--------------------------------------------------------------------
# global.acls.replicationToken

@test "server/StatefulSet: acl replication token config is not set by default" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr)

  # Test the flag is not set.
  local actual=$(echo "$object" |
    yq '.spec.template.spec.containers[0].command | any(contains("ACL_REPLICATION_TOKEN"))' | tee /dev/stderr)
  [ "${actual}" = "false" ]

  # Test the ACL_REPLICATION_TOKEN environment variable is not set.
  local actual=$(echo "$object" |
    yq '.spec.template.spec.containers[0].env | map(select(.name == "ACL_REPLICATION_TOKEN")) | length == 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: acl replication token config is not set when acls.replicationToken.secretName is set but secretKey is not" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.acls.replicationToken.secretName=name' \
      . | tee /dev/stderr)

  # Test the flag is not set.
  local actual=$(echo "$object" |
    yq '.spec.template.spec.containers[0].command | any(contains("ACL_REPLICATION_TOKEN"))' | tee /dev/stderr)
  [ "${actual}" = "false" ]

  # Test the ACL_REPLICATION_TOKEN environment variable is not set.
  local actual=$(echo "$object" |
    yq '.spec.template.spec.containers[0].env | map(select(.name == "ACL_REPLICATION_TOKEN")) | length == 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: acl replication token config is not set when acls.replicationToken.secretKey is set but secretName is not" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.acls.replicationToken.secretKey=key' \
      . | tee /dev/stderr)

  # Test the flag is not set.
  local actual=$(echo "$object" |
    yq '.spec.template.spec.containers[0].command | any(contains("ACL_REPLICATION_TOKEN"))' | tee /dev/stderr)
  [ "${actual}" = "false" ]

  # Test the ACL_REPLICATION_TOKEN environment variable is not set.
  local actual=$(echo "$object" |
    yq '.spec.template.spec.containers[0].env | map(select(.name == "ACL_REPLICATION_TOKEN")) | length == 0' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: acl replication token config is set when acls.replicationToken.secretKey and secretName are set" {
  cd `chart_dir`
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.acls.replicationToken.secretName=name' \
      --set 'global.acls.replicationToken.secretKey=key' \
      . | tee /dev/stderr)

  # Test the flag is set.
  local actual=$(echo "$object" |
    yq '.spec.template.spec.containers[0].command | any(contains("-hcl=\"acl { tokens { agent = \\\"${ACL_REPLICATION_TOKEN}\\\", replication = \\\"${ACL_REPLICATION_TOKEN}\\\" } }\""))' | tee /dev/stderr)
  [ "${actual}" = "true" ]

  # Test the ACL_REPLICATION_TOKEN environment variable is set.
  local actual=$(echo "$object" |
    yq -r -c '.spec.template.spec.containers[0].env | map(select(.name == "ACL_REPLICATION_TOKEN"))' | tee /dev/stderr)
  [ "${actual}" = '[{"name":"ACL_REPLICATION_TOKEN","valueFrom":{"secretKeyRef":{"name":"name","key":"key"}}}]' ]
}

#--------------------------------------------------------------------
# global.tls.enableAutoEncrypt

@test "server/StatefulSet: enables auto-encrypt for the servers when global.tls.enableAutoEncrypt is true" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.tls.enabled=true' \
      --set 'global.tls.enableAutoEncrypt=true' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("auto_encrypt = {allow_tls = true}")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# -bootstrap-expect

@test "server/StatefulSet: -bootstrap-expect defaults to replicas" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("-bootstrap-expect=3")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: -bootstrap-expect can be set by server.bootstrapExpect" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.bootstrapExpect=5' \
      . | tee /dev/stderr |
      yq '.spec.template.spec.containers[0].command | join(" ") | contains("-bootstrap-expect=5")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

@test "server/StatefulSet: errors if bootstrapExpect < replicas" {
  cd `chart_dir`
  run helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.bootstrapExpect=1' .
  [ "$status" -eq 1 ]
  [[ "$output" =~ "server.bootstrapExpect cannot be less than server.replicas" ]]
}

#--------------------------------------------------------------------
# license-autoload

@test "server/StatefulSet: adds volume for license secret when enterprise license secret name and key are provided" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      . | tee /dev/stderr |
      yq -r -c '.spec.template.spec.volumes[] | select(.name == "consul-license")' | tee /dev/stderr)
      [ "${actual}" = '{"name":"consul-license","secret":{"secretName":"foo"}}' ]
}

@test "server/StatefulSet: adds volume mount for license secret when enterprise license secret name and key are provided" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      . | tee /dev/stderr |
      yq -r -c '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "consul-license")' | tee /dev/stderr)
      [ "${actual}" = '{"name":"consul-license","mountPath":"/consul/license","readOnly":true}' ]
}

@test "server/StatefulSet: adds env var for license path when enterprise license secret name and key are provided" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.enterpriseLicense.secretName=foo' \
      --set 'server.enterpriseLicense.secretKey=bar' \
      . | tee /dev/stderr |
      yq -r -c '.spec.template.spec.containers[0].env[] | select(.name == "CONSUL_LICENSE_PATH")' | tee /dev/stderr)
      [ "${actual}" = '{"name":"CONSUL_LICENSE_PATH","value":"/consul/license/bar"}' ]
}

@test "server/StatefulSet: -recursor can be set by global.recursors" {
  cd `chart_dir`
  local actual=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'global.recursors[0]=1.2.3.4' \
      . | tee /dev/stderr |
      yq -r -c '.spec.template.spec.containers[0].command | join(" ") | contains("-recursor=\"1.2.3.4\"")' | tee /dev/stderr)
  [ "${actual}" = "true" ]
}

#--------------------------------------------------------------------
# extraContainers

@test "server/StatefulSet: adds extra container" {
  cd `chart_dir`

  # Test that it defines the extra container
  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraContainers[0].image=test-image' \
      --set 'server.extraContainers[0].name=test-container' \
      --set 'server.extraContainers[0].ports[0].name=test-port' \
      --set 'server.extraContainers[0].ports[0].containerPort=9410' \
      --set 'server.extraContainers[0].ports[0].protocol=TCP' \
      --set 'server.extraContainers[0].env[0].name=TEST_ENV' \
      --set 'server.extraContainers[0].env[0].value=test_env_value' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers[] | select(.name == "test-container")' | tee /dev/stderr)

  local actual=$(echo $object |
      yq -r '.name' | tee /dev/stderr)
  [ "${actual}" = "test-container" ]

  local actual=$(echo $object |
      yq -r '.image' | tee /dev/stderr)
  [ "${actual}" = "test-image" ]

  local actual=$(echo $object |
      yq -r '.ports[0].name' | tee /dev/stderr)
  [ "${actual}" = "test-port" ]

  local actual=$(echo $object |
      yq -r '.ports[0].containerPort' | tee /dev/stderr)
  [ "${actual}" = "9410" ]

  local actual=$(echo $object |
      yq -r '.ports[0].protocol' | tee /dev/stderr)
  [ "${actual}" = "TCP" ]

  local actual=$(echo $object |
      yq -r '.env[0].name' | tee /dev/stderr)
  [ "${actual}" = "TEST_ENV" ]

  local actual=$(echo $object |
      yq -r '.env[0].value' | tee /dev/stderr)
  [ "${actual}" = "test_env_value" ]

}

@test "server/StatefulSet: adds two extra containers" {
  cd `chart_dir`

  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      --set 'server.extraContainers[0].image=test-image' \
      --set 'server.extraContainers[0].name=test-container' \
      --set 'server.extraContainers[1].image=test-image' \
      --set 'server.extraContainers[1].name=test-container-2' \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers | length' | tee /dev/stderr)

  [ "${object}" = 3 ]

}

@test "server/StatefulSet: no extra containers added by default" {
  cd `chart_dir`

  local object=$(helm template \
      -s templates/server-statefulset.yaml  \
      . | tee /dev/stderr |
      yq -r '.spec.template.spec.containers | length' | tee /dev/stderr)

  [ "${object}" = 1 ]
}
