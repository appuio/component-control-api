/*
* Deploys the control-api API server
*/
local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

local serviceAccount = common.LoadManifest('apiserver/service_account.yaml') {
  metadata+: {
    namespace: params.namespace,
  },
};

local role = common.LoadManifest('apiserver/role.yaml');

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

local mergeArgs(args, additional) = std.set(args + additional, function(arg) std.split(arg, '=')[0]);
local extraDeploymentArgs =
  [
    '--username-prefix=' + params.username_prefix,
  ] +
  if certSecret != null then
    [
      '--tls-cert-file=/apiserver.local.config/certificates/tls.crt',
      '--tls-private-key-file=/apiserver.local.config/certificates/tls.key',
    ]
  else
    []
;


local deployment = common.LoadManifest('apiserver/deployment.yaml') {
  metadata+: {
    namespace: params.namespace,
  },

  spec+: {
    template+: {
      spec+: {
        containers: [
          if c.name == 'apiserver' then
            c {
              image: '%(registry)s/%(image)s:%(tag)s' % params.images['control-api'],
              args: mergeArgs(super.args, extraDeploymentArgs),
            }
          else
            c
          for c in super.containers
        ],
      } + if certSecret != null then
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
      else {},
    },
  },
};

local service = common.LoadManifest('apiserver/service.yaml') {
  metadata+: {
    namespace: params.namespace,
  },
  spec+: {
    selector: deployment.spec.selector.matchLabels,
  },
};


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
  '01_role_binding_auth_delegator': common.LoadManifest('apiserver/role_binding_auth_delegator.yaml') {
    subjects: [
      {
        kind: 'ServiceAccount',
        name: serviceAccount.metadata.name,
        namespace: serviceAccount.metadata.namespace,
      },
    ],
  },
  '01_service_account': serviceAccount,
  '02_deployment': deployment,
  [if certSecret != null then '02_certs']: certSecret,
  '02_service': service,
  '02_apiservice': common.LoadManifest('apiserver/apiservice.yaml') {
    spec+: {
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
  },
}
