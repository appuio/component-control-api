local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

local defaultLabels = {
  'app.kubernetes.io/name': 'control-api',
  'app.kubernetes.io/component': 'control-api',
  'app.kubernetes.io/managed-by': 'commodore',
};

{
  DefaultLabels: defaultLabels,
}
