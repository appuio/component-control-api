/*
* Deploys the control-api billing entity cleanup cronjob
*/
local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.control_api;
local com = import 'lib/commodore.libjsonnet';

local namespace = {
  metadata+: {
    namespace: params.namespace,
  },
};

local cronJob = kube.CronJob('cleanup-inflight-partner-records') + namespace {
  spec+: {
    schedule: params.cleanupJob.schedule,
    failedJobsHistoryLimit: params.cleanupJob.jobHistoryLimit.failed,
    successfulJobsHistoryLimit: params.cleanupJob.jobHistoryLimit.successful,
    jobTemplate+: {
      spec+: {
        template+: {
          spec+: {
            nodeSelector: params.cleanupJob.nodeSelector,
            restartPolicy: 'Never',
            containers_+: {
              cleanup: kube.Container('cleanup') {
                image: '%(registry)s/%(image)s:%(tag)s' % params.images['control-api'],
                args: params.cleanupJob.extraArgs,
                env+: com.envList(params.cleanupJob.extraEnv),
              },
            },
          },
        },
      },
    },
  },
};

[ cronJob ]
