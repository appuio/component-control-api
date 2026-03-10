{
  ApiServicePatch(name, insecureSkipTLSVerify, caCert=null): {
    patches+: std.prune([
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
        patch: std.manifestJsonMinified([ {
          op: 'add',
          path: '/spec/caBundle',
          value: std.base64(caCert),
        } ]),
        target: {
          kind: 'APIService',
          name: name,
        },
      },
    ]),
  },
  LabelPatch(kind, name, labels): {
    patches+: [
      {
        patch: std.manifestJsonMinified([ {
          op: 'add',
          path: '/metadata/labels',
          value: labels,
        } ]),
        target: {
          kind: kind,
          name: name,
        },
      },
    ],
  },
}
