/*
* Deploys the control-api API server
*/
local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

local image = params.images['control-api'];

local loadManifest(manifest) = std.parseJson(kap.yaml_load('control-api/manifests/' + image.tag + '/' + manifest));

local serviceAccount = loadManifest('service_account.yaml') {
  metadata+: {
    namespace: params.namespace,
  },
};

local role = loadManifest('role.yaml');

local deployment = loadManifest('deployment.yaml') {
  metadata+: {
    namespace: params.namespace,
  },

  spec+: {
    template+: {
      spec+: {
        containers: [
          if c.name == 'apiserver' then
            c {
              image: '%s/%s:%s' % [ image.registry, image.image, image.tag ],
            }
          else
            c
          for c in super.containers
        ],
      },
    },
  },
};

{
  '01_role': role,
  '01_role_binding': kube.ClusterRoleBinding(role.metadata.name) {
    roleRef: {
      kind: 'ClusterRole',
      apiGroup: 'rbac.authorization.k8s.io',
      name: role.metadata.name,
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: serviceAccount.metadata.name,
        namespace: serviceAccount.metadata.namespace,
      },
    ],
  },
  '01_role_binding_auth_delegator': loadManifest('role_binding_auth_delegator.yaml') {
    subjects: [
      {
        kind: 'ServiceAccount',
        name: serviceAccount.metadata.name,
        namespace: serviceAccount.metadata.namespace,
      },
    ],
  },
  '01_service_account': serviceAccount,
  '02_deployment': deployment,
  '02_service': loadManifest('service.yaml') {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      selector: deployment.spec.selector.matchLabels,
    },
  },
  '02_apiservice': loadManifest('apiservice.yaml'),
}
