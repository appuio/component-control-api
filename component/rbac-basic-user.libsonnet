/*
* Allows any authenticated user to perform basic actions
*/
local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

local role = common.LoadManifest('rbac/basic-user-role.yaml') {
  metadata+: {
    labels+: common.DefaultLabels,
  },
};

local roleBinding = common.LoadManifest('rbac/basic-user-rolebinding.yaml') {
  metadata+: {
    labels+: common.DefaultLabels,
  },
};


[ role, roleBinding ]
