local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;

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
  '30_webhook_cert_secret': admissionWebhookTlsSecret,
  '30_webhook_config': admissionWebhook,
  '31_webhook_service': admissionWebhookService,
}
