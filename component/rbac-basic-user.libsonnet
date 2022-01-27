/*
* Allows any authenticated user to perform basic actions
*/
local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

local role = kube.ClusterRole('control-api:basic-user') {
  metadata+: {
    labels+: common.DefaultLabels,
  },
  rules: params.basic_user_role,
};

local roleBinding = kube.ClusterRoleBinding('control-api:basic-user') {
  metadata+: {
    labels+: common.DefaultLabels,
  },
  roleRef_: role,
  subjects: [
    {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Group',
      name: 'system:authenticated',
    },
  ],
};


[ role, roleBinding ]
