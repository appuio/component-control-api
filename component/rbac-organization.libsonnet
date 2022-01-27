/*
* Allows any authenticated user to perform basic actions
*/
local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

[
  kube.ClusterRole(role) {
    metadata+: {
      labels+: common.DefaultLabels,
    },
    rules: params.organization_roles[role],
  }

  for role in std.objectFields(params.organization_roles)
]
