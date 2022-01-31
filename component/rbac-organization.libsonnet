/*
* Allows any authenticated user to perform basic actions
*/
local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;


local adminrole = common.LoadManifest('rbac/organization-admin-role.yaml') {
  metadata+: {
    labels+: common.DefaultLabels,
  },
};

local viewrole = common.LoadManifest('rbac/organization-viewer-role.yaml') {
  metadata+: {
    labels+: common.DefaultLabels,
  },
};

[ adminrole, viewrole ]
