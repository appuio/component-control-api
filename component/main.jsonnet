// main template for control-api
local common = import 'common.libsonnet';
local controlApi = import 'lib/control-api.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.control_api;


local zones = [
  controlApi.Zone(name) + params.zones[name] {
    metadata+: {
      labels+: common.DefaultLabels,
    },
  }
  for name in std.objectFields(params.zones)
  if params.zones[name] != null
];

// Define outputs below
{
  '00_namespace': kube.Namespace(params.namespace),
  '10_rbac_cluster_admin_impersonation': (import 'rbac-cluster-admin-impersonation.libsonnet'),
  '10_rbac_basic_user': (import 'rbac-basic-user.libsonnet'),
  '10_rbac_organization': (import 'rbac-organization.libsonnet'),
  [if params.idp_adapter.enabled then '30_idp_adapter']: (import 'idp-adapter.libsonnet'),
  [if std.length(zones) > 0 then '20_zones']: zones,
}
