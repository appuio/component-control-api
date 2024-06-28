/*
* Deploys the control-api API server
*/
local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;
local com = import 'lib/commodore.libjsonnet';

local serviceAccount = common.LoadManifest('rbac/apiserver/service_account.yaml') {
  metadata+: {
    namespace: params.namespace,
  },
};

local role = common.LoadManifest('rbac/apiserver/role.yaml');

local hasCountriesConfig = params.odoo8.countries != null && std.length(params.odoo8.countries) > 0;

local certSecret =
  if params.apiserver.tls.certSecretName != null then
    assert std.length(params.apiserver.tls.serverCert) > 0 : 'apiserver.tls.serverCert is required';
    assert std.length(params.apiserver.tls.serverKey) > 0 : 'apiserver.tls.serverKey is required';
    kube.Secret(params.apiserver.tls.certSecretName) {
      metadata+: {
        namespace: params.namespace,
      },
      stringData: {
        'tls.key': params.apiserver.tls.serverKey,
        'tls.crt': params.apiserver.tls.serverCert,
      },
    }
  else
    null;

local extraDeploymentArgs =
  [
    '--username-prefix=' + params.username_prefix,
    '--invitation-storage-backing-ns=' + params.invitation_store_namespace,
  ]
  +
  (if certSecret != null then
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
;

local countryList = std.filterMap(
  function(name) params.odoo8.countries[name] != null,
  function(name) {
    name: name,
    code: params.odoo8.countries[name].code,
    id: params.odoo8.countries[name].id,
  },
  std.objectFields(params.odoo8.countries)
);

local countriesConfigMap =
  kube.ConfigMap('billing-entity-odoo8-country-list') {
    metadata+: {
      namespace: params.namespace,
    },
    data: {
      'billing_entity_odoo8_country_list.yaml': std.manifestYamlDoc(countryList),
    },
  };

local deployment = common.LoadManifest('deployment/apiserver/deployment.yaml') {
  metadata+: {
    namespace: params.namespace,
  },

  spec+: {
    template+: {
      [if hasCountriesConfig then 'metadata']+: {
        annotations+: {
          'checksum/countries':
            std.md5(countriesConfigMap.data['billing_entity_odoo8_country_list.yaml']),
        },
      },
      spec+:
        {
          containers: [
            if c.name == 'apiserver' then
              c {
                image: '%(registry)s/%(image)s:%(tag)s' % params.images['control-api'],
                args: [ super.args[0] ] + common.MergeArgs(common.MergeArgs(super.args[1:], extraDeploymentArgs), params.apiserver.extraArgs),
                env+: com.envList(params.apiserver.extraEnv),
                resources+: com.makeMergeable(params.apiserver.resources),
                volumeMounts+:
                  if hasCountriesConfig then
                    [ {
                      name: 'countries-config',
                      mountPath: '/config/billing_entity_odoo8_country_list.yaml',
                      readOnly: true,
                      subPath: 'billing_entity_odoo8_country_list.yaml',
                    } ]
                  else
                    [],
              }
            else
              c
            for c in super.containers
          ],
        }
        + (if certSecret != null then
             {
               volumes: [
                 {
                   name: 'apiserver-certs',
                   secret: {
                     secretName: certSecret.metadata.name,
                   },
                 },
               ],
             }
           else
             {})
        + (if hasCountriesConfig then
             {
               volumes+: [
                 {
                   name: 'countries-config',
                   configMap: {
                     name: countriesConfigMap.metadata.name,
                   },
                 },
               ],
             }
           else {}),
    },
  },
};

local service = common.LoadManifest('deployment/apiserver/service.yaml') {
  metadata+: {
    namespace: params.namespace,
    labels+: {
      name: $.metadata.name,
    },
  },
  spec+: {
    selector: deployment.spec.selector.matchLabels,
  },
};

local apiServices =
  std.map(
    function(upstream)
      local manifest = upstream {
        spec+:
          {
            service: {
              name: service.metadata.name,
              namespace: service.metadata.namespace,
            },
          }
          +
          (
            if params.apiserver.tls.serverCert != null
               && params.apiserver.tls.serverCert != ''
            then
              { caBundle: std.base64(params.apiserver.tls.serverCert) }
            else
              {}
          )
          +
          params.apiserver.apiservice,
      };
      if !manifest.spec.insecureSkipTLSVerify then
        manifest {
          spec+: {
            insecureSkipTLSVerify:: false,
          },
        }
      else
        manifest,
    common.LoadManifestStream('deployment/apiserver/apiservice.yaml')
  );

local metricsRbac =
  local sa = kube.ServiceAccount('metrics') {
    metadata+: {
      namespace: params.namespace,
    },
  };
  [
    sa,
    kube.Secret(sa.metadata.name) {
      metadata+: {
        annotations+: {
          'kubernetes.io/service-account.name': sa.metadata.name,
          'vcluster.loft.sh/force-sync': 'true',
        },
        namespace: params.namespace,
      },
      type: 'kubernetes.io/service-account-token',
      data:: {},
    },
    kube.ClusterRoleBinding(sa.metadata.name) {
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
        name: 'system:monitoring',
      },
      subjects_: [ sa ],
    },
  ];

{
  '01_role': role,
  '01_role_binding': kube.ClusterRoleBinding(role.metadata.name) {
    roleRef: {
      kind: 'ClusterRole',
      apiGroup: 'rbac.authorization.k8s.io',
      name: role.metadata.name,
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: serviceAccount.metadata.name,
        namespace: serviceAccount.metadata.namespace,
      },
    ],
  },
  '01_role_binding_auth_delegator': common.LoadManifest('rbac/apiserver/role_binding_auth_delegator.yaml') {
    subjects: [
      {
        kind: 'ServiceAccount',
        name: serviceAccount.metadata.name,
        namespace: serviceAccount.metadata.namespace,
      },
    ],
  },
  '01_service_account': serviceAccount,
  [if hasCountriesConfig then '01_countries_configmap']: countriesConfigMap,
  '02_deployment': deployment,
  [if certSecret != null then '02_certs']: certSecret,
  '02_service': service,
  '02_apiservice': apiServices,
  '03_api_metrics_rbac': metricsRbac,
}
