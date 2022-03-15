/*
* Deploys the IDP-Adapter controller
*/
local common = import 'common.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

local idpRoleTmpl = std.parseJson(kap.yaml_load(
  'dependencies/control-api/manifests/idp-adapter/%(image)s/%(tag)s/rbac/clusterrole.yaml' % params.images['idp-adapter'],
));

local name = 'idp-adapter';

local serviceAccount = kube.ServiceAccount(name) {
  metadata+: {
    namespace: params.namespace,
  },
};

local clusterRole = kube.ClusterRole(name) {
  rules: idpRoleTmpl.rules,
};

local clusterRoleBinding = kube.ClusterRoleBinding(name) {
  subjects_: [ serviceAccount ],
  roleRef_: clusterRole,
};

local leaderElectionRole = kube.Role(name + '-leader-election-role') {
  rules: [
    {
      apiGroups: [
        '',
      ],
      resources: [
        'configmaps',
      ],
      verbs: [
        'get',
        'list',
        'watch',
        'create',
        'update',
        'patch',
        'delete',
      ],
    },
    {
      apiGroups: [
        'coordination.k8s.io',
      ],
      resources: [
        'leases',
      ],
      verbs: [
        'get',
        'list',
        'watch',
        'create',
        'update',
        'patch',
        'delete',
      ],
    },
    {
      apiGroups: [
        '',
      ],
      resources: [
        'events',
      ],
      verbs: [
        'create',
        'patch',
      ],
    },
  ],
};

local leaderElectionRoleBinding = kube.RoleBinding(name) {
  subjects_: [ serviceAccount ],
  roleRef_: leaderElectionRole,
};

local secrets = [
  if params.secrets[s] != null then
    kube.Secret(s) + com.makeMergeable(params.secrets[s])
  for s in std.objectFields(params.secrets)
];

local deployment = kube.Deployment(name) {
  metadata+: {
    labels+: common.DefaultLabels,
  },
  spec+: {
    replicas: 1,
    template+: {
      spec+: {
        serviceAccount: serviceAccount.metadata.name,
        containers_+: {
          operator: kube.Container('controller') {
            image: '%(registry)s/%(image)s:%(tag)s' % params.images['idp-adapter'],
            resources: params.idp_adapter.resources,
            args+: params.idp_adapter.args,
            env+: com.envList(params.idp_adapter.env),
          },
        },
      },
    },
  },
};

std.map(
  function(o) o {
    metadata+: {
      namespace: params.namespace,
      labels+: common.DefaultLabels,
    },
  },
  [
    serviceAccount,
    clusterRole,
    clusterRoleBinding,
    leaderElectionRole,
    leaderElectionRoleBinding,
    deployment,
  ] + secrets,
)
