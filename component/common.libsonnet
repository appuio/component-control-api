local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

local defaultLabels = {
  'app.kubernetes.io/name': 'control-api',
  'app.kubernetes.io/component': 'control-api',
  'app.kubernetes.io/managed-by': 'commodore',
};


local image = params.images['control-api'];
local loadManifest(manifest) = std.parseJson(kap.yaml_load('control-api/manifests/' + image.tag + '/' + manifest));
local loadManifestStream(manifest) = std.parseJson(kap.yaml_load_stream('control-api/manifests/' + image.tag + '/' + manifest));

local mergeArgs(args, additional) =
  local foldFn =
    function(acc, arg)
      local ap = std.splitLimit(arg, '=', 1);
      acc { [ap[0]]: ap[1] };
  local base = std.foldl(foldFn, args, {});
  local final = std.foldl(foldFn, additional, base);
  [ '%s=%s' % [ k, final[k] ] for k in std.objectFields(final) ];

{
  DefaultLabels: defaultLabels,
  LoadManifest: loadManifest,
  LoadManifestStream: loadManifestStream,
  MergeArgs: mergeArgs,
}
