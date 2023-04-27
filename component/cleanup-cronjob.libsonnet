/*
* Deploys the control-api API server
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

local hasCountriesConfig = params.odoo8.countries != null && std.length(params.odoo8.countries) > 0;

local extraDeploymentArgs =
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
                args: common.MergeArgs(extraDeploymentArgs, params.cleanupJob.extraArgs),
                env+: com.envList(params.cleanupJob.extraEnv),
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
              },
            }
          }
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
    },
  },
};

[ cronJob ]