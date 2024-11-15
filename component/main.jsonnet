// main template for control-api
local common = import 'common.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local controlApi = import 'lib/control-api.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.control_api;


local zones = [
  controlApi.Zone(name) +
  com.makeMergeable(params.zones[name]) {
    metadata+: {
      labels+: common.DefaultLabels,
    },
  }
  for name in std.objectFields(params.zones)
  if params.zones[name] != null
];

local usageprofiles = com.generateResources(params.usage_profiles, controlApi.UsageProfile);

local hasCountriesConfig = params.odoo8.countries != null && std.length(params.odoo8.countries) > 0;

local countryList = if hasCountriesConfig then std.filterMap(
  function(name) params.odoo8.countries[name] != null,
  function(name) {
    name: name,
    code: params.odoo8.countries[name].code,
    id: params.odoo8.countries[name].id,
  },
  std.objectFields(params.odoo8.countries)
);

local countriesConfigMap =
  kube.ConfigMap('billing-entity-odoo8-country-list') {
    metadata+: {
      namespace: params.namespace,
    },
    data: {
      'billing_entity_odoo8_country_list.yaml': std.manifestYamlDoc(countryList),
    },
  };

local certSecret =
  if params.apiserver.tls.certSecretName != null then
    assert std.length(params.apiserver.tls.serverCert) > 0 : 'apiserver.tls.serverCert is required';
    assert std.length(params.apiserver.tls.serverKey) > 0 : 'apiserver.tls.serverKey is required';
    kube.Secret(params.apiserver.tls.certSecretName) {
      metadata+: {
        namespace: params.namespace,
      },
      stringData: {
        'tls.key': params.apiserver.tls.serverKey,
        'tls.crt': params.apiserver.tls.serverCert,
      },
    }
  else
    null;

// Define outputs below
{
  '00_namespace': [
    kube.Namespace(params.namespace),
    kube.Namespace(params.invitation_store_namespace),
  ],
  [if hasCountriesConfig then '10_odoo_countrylist']: countriesConfigMap,
  [if certSecret != null then '10_certs']: certSecret,
  '10_rbac_cluster_admin_impersonation': (import 'rbac-cluster-admin-impersonation.libsonnet'),
  '10_rbac_basic_user': (import 'rbac-basic-user.libsonnet'),
  '10_rbac_organization': (import 'rbac-organization.libsonnet'),
  [if params.idp_adapter.enabled then '30_idp_adapter']: (import 'idp-adapter.libsonnet'),
  [if std.length(zones) > 0 then '20_zones']: zones,
  [if params.cleanupJob.enabled then '20_cronjob']: (import 'cleanup-cronjob.libsonnet'),
  [if std.length(usageprofiles) > 0 then '90_usage_profiles']: usageprofiles,
}
