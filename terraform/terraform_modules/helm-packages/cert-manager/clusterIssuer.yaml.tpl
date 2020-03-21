apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: ${clusterIssuerName}
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${email}
    privateKeySecretRef:
      name: ${clusterIssuerName}
    solvers:
      - http01:
          ingress:
            class: traefik