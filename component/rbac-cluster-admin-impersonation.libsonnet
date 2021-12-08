/*
* Allows impersonation of the `cluster-admin` user bound to the `cluster-admin` role
* for users in the configured role.
*/
local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

local role = kube.ClusterRole('cluster-admin-impersonator') {
  metadata+: {
    labels+: common.DefaultLabels,
  },
  rules: [
    {
      apiGroups: [
        '',
      ],
      resources: [
        'users',
      ],
      verbs: [
        'impersonate',
      ],
      resourceNames: [
        'cluster-admin',
      ],
    },
  ],
};

local roleBinding = kube.ClusterRoleBinding('cluster-admin-impersonator') {
  metadata+: {
    labels+: common.DefaultLabels,
  },
  roleRef_: role,
  subjects: [
    {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Group',
      name: params.cluster_admin_impersonation.oidc_administrator_role,
    },
  ],
};

local clusterAdminBinding = kube.ClusterRoleBinding('user-cluster-admin') {
  metadata+: {
    labels+: common.DefaultLabels,
  },
  roleRef_: kube.ClusterRole('cluster-admin'),
  subjects: [
    {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'User',
      name: 'cluster-admin',
    },
  ],
};


[ role, roleBinding, clusterAdminBinding ]
