/*
* Deploys the control-api API server
*/
local common = import 'common.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

local serviceAccount = common.LoadManifest('rbac/controller/service_account.yaml') {
  metadata+: {
    namespace: params.namespace,
  },
};

local role = com.namespaced(params.namespace, common.LoadManifest('rbac/controller/role.yaml'));
local leaderElectionRole = com.namespaced(params.namespace, common.LoadManifest('rbac/controller/leader_election_role.yaml'));

local mergeArgs(args, additional) = std.set(args + additional, function(arg) std.split(arg, '=')[0]);
local extraDeploymentArgs =
  [
    '--username-prefix=' + params.username_prefix,
  ]
;

local deployment = common.LoadManifest('deployment/controller/deployment.yaml') {
  metadata+: {
    namespace: params.namespace,
  },

  spec+: {
    template+: {
      spec+: {
        containers: [
          if c.name == 'controller' then
            c {
              image: '%(registry)s/%(image)s:%(tag)s' % params.images['control-api'],
              args: [ super.args[0] ] + mergeArgs(super.args[1:], extraDeploymentArgs),
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
  '01_leader_election_role': leaderElectionRole,
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
  '01_leader_election_role_binding': kube.RoleBinding(role.metadata.name) {
    metadata+: {
      namespace: params.namespace,
    },
    roleRef: {
      kind: 'Role',
      apiGroup: 'rbac.authorization.k8s.io',
      name: leaderElectionRole.metadata.name,
    },
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
}
