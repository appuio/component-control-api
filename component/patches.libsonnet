{
  ApiServicePatch(name, insecureSkipTLSVerify, caCert=null): {
    patches+: [
      {
        patch: std.manifestJsonMinified([
          {
            path: '/spec/insecureSkipTLSVerify',
          } +
          if insecureSkipTLSVerify then {
            op: 'add',
            value: insecureSkipTLSVerify,
          } else {
            op: 'remove',
          },
        ]),
        target: {
          kind: 'APIService',
          name: name,
        },
      },
      if caCert != null then {
        patch: std.format(|||
          - op: add
            path: /spec/caBundle
            value: %s
        |||, std.base64(caCert)),
        target: {
          kind: 'APIService',
          name: name,
        },
      },
    ],
  },
  LabelPatch(kind, name, labels): {
    patches+: [
      {
        patch: std.format(|||
          - op: add
            path: /metadata/labels
            value: %s
        |||, labels),
        target: {
          kind: kind,
          name: name,
        },
      },
    ],
  },
}
