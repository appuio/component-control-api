local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

// Renders kustomization config creating the RBAC plus accounts for the cloud agents on the zones
// Outputs:
// - zone1/kustomization.yaml with namePrefix: zone1-
// - zone2/kustomization.yaml with namePrefix: zone2-
// - kustomization.yaml referencing the zones
std.foldl(
  function(accs, name)
    accs {
      kustomization+: {
        resources+: [ name ],
      },
      [name + '/kustomization']: {
        resources: [
          'https://github.com/appuio/appuio-cloud-agent.git//config/foreign_rbac?ref=%(tag)s' % params.images['appuio-cloud-agent'],
        ],
        namePrefix: name + '-',
      },
    }
  ,
  std.filter(function(name) name != null, std.objectFields(params.zones)),
  {}
)
