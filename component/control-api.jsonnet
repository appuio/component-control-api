local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';

// The hiera parameters for the component
local inv = kap.inventory();
local params = inv.parameters.control_api;

com.Kustomization(
  'https://github.com/appuio/control-api//config/deployment',
  params.manifests_version,
  {
    'ghcr.io/appuio/control-api': {
      local image = params.images['control-api'],
      newTag: image.tag,
      newName: '%(registry)s/%(image)s' % image,
    },
  },
  params.kustomize_input {
    labels+: [
      {
        pairs: {
          'app.kubernetes.io/managed-by': 'commodore',
        },
      },
    ],
  },
)
