/*
* Allows any authenticated user to perform basic actions
*/
local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

local role = common.LoadManifest('user-rbac/basic-user-role.yml') {
  metadata+: {
    labels+: common.DefaultLabels,
  },
};

local roleBinding = common.LoadManifest('user-rbac/basic-user-rolebinding.yml') {
  metadata+: {
    labels+: common.DefaultLabels,
  },
};


[ role, roleBinding ]
