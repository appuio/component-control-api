local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local patches = import 'patches.libsonnet';

// The hiera parameters for the component
local inv = kap.inventory();
local params = inv.parameters.control_api;

local countryList = std.filterMap(
  function(name) params.odoo8.countries[name] != null,
  function(name) {
    name: name,
    code: params.odoo8.countries[name].code,
    id: params.odoo8.countries[name].id,
  },
  std.objectFields(params.odoo8.countries)
);

local countries_yaml = std.manifestYamlDoc(countryList);

local hasCountriesConfig = params.odoo8.countries != null && std.length(params.odoo8.countries) > 0;

/////////////////
// API Server

local validCertSecret =
  if params.apiserver.tls.certSecretName != null then
    assert std.length(params.apiserver.tls.serverCert) > 0 : 'apiserver.tls.serverCert is required';
    assert std.length(params.apiserver.tls.serverKey) > 0 : 'apiserver.tls.serverKey is required';
    true
  else
    false
;

local apiserverDeploymentArgs =
  [
    '--invitation-storage-backing-ns=' + params.invitation_store_namespace,
  ]
  +
  (if validCertSecret then
     [
       '--tls-cert-file=/apiserver.local.config/certificates/tls.crt',
       '--tls-private-key-file=/apiserver.local.config/certificates/tls.key',
     ]
   else
     [])
  +
  (if hasCountriesConfig then
     [
       '--billing-entity-odoo8-country-list=/config/billing_entity_odoo8_country_list.yaml',
     ]
   else
     [])
  + params.apiserver.extraArgs
;

local apiserverDeploymentArgsPatch = {
  patches+: [
    {
      patch: std.format(|||
        - op: add
          path: "/spec/template/spec/containers/0/args/-"
          value: "%s"
      |||, arg),
      target: {
        kind: 'Deployment',
        name: 'control-api-apiserver',
      },
    }
    for arg in apiserverDeploymentArgs
  ],
};

local apiserverOdooConfigPatch = if hasCountriesConfig then {
  patches+: [
    {
      patch: std.format(|||
        - op: add
          path: /spec/template/spec/containers/0/volumeMounts/-
          value:
            mountPath: /config/billing_entity_odoo8_country_list.yaml
            name: countries-config
            readOnly: true
            subPath: billing_entity_odoo8_country_list.yaml
        - op: add
          path: /spec/template/spec/volumes/-
          value:
            name: countries-config
            configMap:
              name: billing-entity-odoo8-country-list
        - op: add
          path: /spec/template/metadata/annotations
          value:
            'checksum/countries': %s
      |||, std.md5(countries_yaml)),
      target: {
        kind: 'Deployment',
        name: 'control-api-apiserver',
      },
    },
  ],
} else {};

local apiserverExtraEnvList = com.envList(params.apiserver.extraEnv);
local apiserverDeploymentEnvPatch = if std.length(apiserverExtraEnvList) > 0 then {
  patches+: [
    {
      patch: std.format(|||
        - op: add
          path: /spec/template/spec/containers/0/env
          value: []
        - op: add
          path: /spec/template/spec/containers/0/env/-
          value: %s
      |||, apiserverExtraEnvList),
      target: {
        kind: 'Deployment',
        name: 'control-api-apiserver',
      },
    },
  ],
} else {};

local apiserverDeploymentResources = std.mergePatch({
  limits: {
    cpu: '300m',
    memory: '100Mi',
  },
  requests: {
    cpu: '100m',
    memory: '200Mi',
  },
}, params.apiserver.resources);
local apiserverDeploymentResourcesPatch = {
  patches+: [
    {
      patch: std.format(|||
        - op: add
          path: /spec/template/spec/containers/0/resources
          value:
            %s
      |||, std.manifestJson(apiserverDeploymentResources)),
      target: {
        kind: 'Deployment',
        name: 'control-api-apiserver',
      },
    },
  ],
};

local apiserverDeploymentVolumesPatch = if validCertSecret then {
  patches+: [
    {
      patch: std.format(|||
        - op: replace
          path: /spec/template/spec/volumes/0
          value:
            name: apiserver-certs
            secret:
              secretName: %s
      |||, params.apiserver.tls.certSecretName),
      target: {
        kind: 'Deployment',
        name: 'control-api-apiserver',
      },
    },
  ],
} else {};

local apiserverDeploymentPatch = apiserverDeploymentArgsPatch
                                 + apiserverDeploymentEnvPatch
                                 + apiserverDeploymentResourcesPatch
                                 + apiserverOdooConfigPatch
                                 + apiserverDeploymentVolumesPatch;

local apiserverRoleBindingPatch = patches.LabelPatch('Service', 'control-api-apiserver', std.toString({
  name: 'control-api-apiserver',
}));

local apiserverServicePatch = patches.LabelPatch('Service', 'control-api-apiserver', std.toString({
  name: 'control-api-apiserver',
}));

/////////////////
// Controller

local webhookCertDir = '/var/run/webhook-service-tls';

local validAdmissionWebhookTlsSecret =
  assert std.length(params.controller.webhookTls.certificate) > 0 : 'controller.webhookTls.certificate is required';
  assert std.length(params.controller.webhookTls.key) > 0 : 'controller.webhookTls.key is required';
  true
;

local controllerDeploymentArgs =
  (if validAdmissionWebhookTlsSecret then
     [
       '--webhook-cert-dir=' + webhookCertDir,
     ]
   else
     [])
  +
  params.controller.extraArgs
;

local controllerDeploymentArgPatches = {
  patches+: [
    {
      patch: std.format(|||
        - op: add
          path: "/spec/template/spec/containers/0/args/-"
          value: "%s"
      |||, arg),
      target: {
        kind: 'Deployment',
        name: 'control-api-controller',
      },
    }
    for arg in controllerDeploymentArgs
  ],
};

local controllerExtraEnvList = com.envList(params.controller.extraEnv);
local controllerDeploymentEnvPatch = if std.length(controllerExtraEnvList) > 0 then {
  patches+: [
    {
      patch: std.format(|||
        - op: add
          path: /spec/template/spec/containers/0/env
          value: []
        - op: add
          path: /spec/template/spec/containers/0/env/-
          value: %s
      |||, controllerExtraEnvList),
      target: {
        kind: 'Deployment',
        name: 'control-api-controller',
      },
    },
  ],
} else {};

local controllerDeploymentVolumePatch = {
  patches+: [
    {
      patch: |||
        - op: add
          path: "/spec/template/spec/volumes"
          value: []
        - op: add
          path: "/spec/template/spec/volumes/-"
          value:
            name: webhook-service-tls
            secret:
              secretName: webhook-service-tls
      |||,
      target: {
        kind: 'Deployment',
        name: 'control-api-controller',
      },
    },
  ],
};

local controllerDeploymentResources = std.mergePatch({
  limits: {
    cpu: '300m',
    memory: '200Mi',
  },
  requests: {
    cpu: '150m',
    memory: '100Mi',
  },
}, params.controller.resources);
local controllerDeploymentResourcesPatch = {
  patches+: [
    {
      patch: std.format(|||
        - op: add
          path: "/spec/template/spec/containers/0/resources"
          value: %s
      |||, std.manifestJson(controllerDeploymentResources)),
      target: {
        kind: 'Deployment',
        name: 'control-api-controller',
      },
    },
  ],
};

local controllerDeploymentVolumeMountsPatch = {
  patches+: [
    {
      patch: |||
        - op: add
          path: "/spec/template/spec/containers/0/volumeMounts"
          value: []
        - op: add
          path: "/spec/template/spec/containers/0/volumeMounts/-"
          value:
            mountPath: /var/run/webhook-service-tls
            name: webhook-service-tls
            readOnly: true
      |||,
      target: {
        kind: 'Deployment',
        name: 'control-api-controller',
      },
    },
  ],
};

local controllerDeploymentPatch = controllerDeploymentArgPatches
                                  + controllerDeploymentEnvPatch
                                  + controllerDeploymentResourcesPatch
                                  + controllerDeploymentVolumeMountsPatch
                                  + controllerDeploymentVolumePatch;

local controllerRoleBindingPatch = patches.LabelPatch('ClusterRoleBinding', 'control-api-controller', std.toString({
  name: 'control-api-controller',
}));


local controllerServicePatch = patches.LabelPatch('Service', 'control-api-controller-metrics', std.toString({
  app: 'control-api-controller',
  name: 'control-api-controller',
})) {
  patches+: [
    {
      patch: |||
        - op: add
          path: /spec/ports/0/name
          value: metrics
      |||,
      target: {
        kind: 'Service',
        name: 'control-api-controller-metrics',
      },
    },
  ],
};

////////////////
// Misc

local apiservicePatches = patches.ApiServicePatch('v1.organization.appuio.io', params.apiserver.apiservice.insecureSkipTLSVerify, params.apiserver.tls.serverCert)
                          + patches.ApiServicePatch('v1.user.appuio.io', params.apiserver.apiservice.insecureSkipTLSVerify, params.apiserver.tls.serverCert)
                          + patches.ApiServicePatch('v1.billing.appuio.io', params.apiserver.apiservice.insecureSkipTLSVerify, params.apiserver.tls.serverCert);

local kustomize_input = params.kustomize_input
                        + apiservicePatches

                        + apiserverDeploymentPatch
                        + apiserverRoleBindingPatch
                        + apiserverServicePatch

                        + controllerDeploymentPatch
                        + controllerRoleBindingPatch
                        + controllerServicePatch;

com.Kustomization(
  'https://github.com/appuio/control-api//config/deployment',
  params.manifests_version,
  {
    'ghcr.io/appuio/control-api': {
      local image = params.images['control-api'],
      newTag: image.tag,
      newName: '%(registry)s/%(image)s' % image,
    },
    'ghcr.io/vshn/appuio-keycloak-adapter': {
      local image = params.images['idp-adapter'],
      newTag: image.tag,
      newName: '%(registry)s/%(image)s' % image,
    },
  },
  kustomize_input {
    labels+: [
      {
        pairs: {
          'app.kubernetes.io/managed-by': 'commodore',
        },
      },
    ],
    patchesStrategicMerge: [ 'rm-namespace.yaml' ],
  },
) {
  'rm-namespace': [
    {
      '$patch': 'delete',
      apiVersion: 'v1',
      kind: 'Namespace',
      metadata: {
        name: 'control-api',
      },
    },
  ],
}
