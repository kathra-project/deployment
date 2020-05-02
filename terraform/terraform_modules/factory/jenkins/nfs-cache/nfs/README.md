# NFS Helm Chart

NFS Server

## Chart Details

This chart will do the following:

* 1 x NFS Server
* All using Kubernetes Deployments

## Installing the Chart

To install the chart with the release name `my-release`:

```bash
$ helm install --name my-release ./nfs
```

## Configuration

The following tables list the configurable parameters of the NFS chart and their default values.

### NFS

| Parameter                         | Description                                                                         | Default        |
| --------------------------------- | ----------------------------------------------------------------------------------- | -------------- |
| `PVC_STORAGE_SIZE`                | Size of the NFS data volume                                                         | `5Gi`          |
| `resourcePolicy`                  | Value 'keep' indicates that the data must be kept when the chart is deleted         | `none`         |
