local helpers = import 'helpers.jsonnet';

local Secret(config, group) = helpers.secret(config, group) {
  data_+:: {
    'thanos.yaml': std.manifestYamlDoc({
      type: 'S3',
      config: {
        bucket: group.secret.input.bucket,
        endpoint: 's3.%s.amazonaws.com' % config.cluster.eks.region,
        region: config.cluster.eks.region,
        insecure: false,
        signature_version2: false,
        encrypt_sse: false,
        put_user_metadata: {},
        http_config: {
          idle_conn_timeout: '0s',
          response_header_timeout: '0s',
          insecure_skip_verify: false,
        },
        trace: {
          enable: false,
        },
      },
    }),
  },
};

function(config) (
  local group = config.groups.thanos;
  if group.enabled then {
    Secret: Secret(config, group),
  }
)