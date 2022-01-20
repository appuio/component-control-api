local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('control-api', params.namespace) {
  spec+: params.appSpec,
};

{
  'control-api': app,
}
