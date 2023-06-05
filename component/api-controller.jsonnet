/*
* Deploys the control-api API server
*/
local common = import 'common.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

local serviceAccount = common.LoadManifest('rbac/controller/service_account.yaml') {
  metadata+: {
    namespace: params.namespace,
  },
};

local role = com.namespaced(params.namespace, common.LoadManifest('rbac/controller/role.yaml'));
local leaderElectionRole = com.namespaced(params.namespace, common.LoadManifest('rbac/controller/leader_election_role.yaml'));

local webhookCertDir = '/var/run/webhook-service-tls';

local extraDeploymentArgs =
  [
    '--username-prefix=' + params.username_prefix,
    '--webhook-cert-dir=' + webhookCertDir,
  ]
;

local deployment = common.LoadManifest('deployment/controller/deployment.yaml') {
  metadata+: {
    namespace: params.namespace,
  },

  spec+: {
    template+: {
      spec+: {
        containers: [
          if c.name == 'controller' then
            c {
              image: '%(registry)s/%(image)s:%(tag)s' % params.images['control-api'],
              args: [ super.args[0] ] + common.MergeArgs(common.MergeArgs(super.args[1:], extraDeploymentArgs), params.controller.extraArgs),
              env+: com.envList(params.controller.extraEnv),
              volumeMounts+: [
                {
                  name: 'webhook-service-tls',
                  mountPath: webhookCertDir,
                  readOnly: true,
                },
              ],
            }
          else
            c
          for c in super.containers
        ],
        volumes+: [
          {
            name: 'webhook-service-tls',
            secret: {
              secretName: params.controller.webhookTls.certSecretName,
            },
          },
        ],
      },
    },
  },
};

local admissionWebhookTlsSecret =
  assert std.length(params.controller.webhookTls.certificate) > 0 : 'controller.webhookTls.certificate is required';
  assert std.length(params.controller.webhookTls.key) > 0 : 'controller.webhookTls.key is required';
  kube.Secret(params.controller.webhookTls.certSecretName) {
    metadata+: {
      namespace: params.namespace,
    },
    type: 'kubernetes.io/tls',
    stringData: {
      'tls.key': params.controller.webhookTls.key,
      'tls.crt': params.controller.webhookTls.certificate,
    },
  };

local admissionWebhook = common.LoadManifest('webhook/manifests.yaml') {
  metadata+: {
    name: '%s-validating-webhook' % params.namespace,
  },
  webhooks: [
    w {
      clientConfig+: {
        [if std.length(params.controller.webhookTls.caCertificate) > 0 then 'caBundle']:
          std.base64(params.controller.webhookTls.caCertificate),
        service+: {
          namespace: params.namespace,
        },
      },
    }
    for w in super.webhooks
  ],
};

local admissionWebhookService = common.LoadManifest('webhook/service.yaml') {
  metadata+: {
    namespace: params.namespace,
  },
};

local metricsService = common.LoadManifest('deployment/controller/metrics-service.yaml') {
  metadata+: {
    namespace: params.namespace,
    labels+: {
      name: $.metadata.name,
    },
  },
  spec+: {
    ports: [
      super.ports[0] {
        name: 'metrics',
      },
    ],
  },
};

{
  '01_role': role,
  '01_leader_election_role': leaderElectionRole,
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
  '01_leader_election_role_binding': kube.RoleBinding(role.metadata.name) {
    metadata+: {
      namespace: params.namespace,
    },
    roleRef: {
      kind: 'Role',
      apiGroup: 'rbac.authorization.k8s.io',
      name: leaderElectionRole.metadata.name,
    },
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
  '10_webhook_cert_secret': admissionWebhookTlsSecret,
  '10_webhook_config': admissionWebhook,
  '11_webhook_service': admissionWebhookService,
  '12_metrics_service': metricsService,
}
