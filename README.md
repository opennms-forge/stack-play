# stack-play
This repository has some docker-compose container stacks for local labs or for playgrounds to test things out.
We use here just very basics to get a stack up and running nothing for productions.

If you want to look for more advanced production ready deployments with Kubernetes, please look at our [OpenNMS Kubernetes](https://github.com/OpenNMS/opennms-drift-kubernetes) repository.

## Usage

By default we use bleeding container images from latest SNAPSHOT.
The OCI images are downloaded from [DockerHub](https://hub.docker.com/u/opennms).

There are two ways how you can tweak the settings.
The compose file can inherent environment variables for things like time zone, container tags.
You can also use the `docker-compose.override.yaml` option to customize the service stacks.

You can  edit the image-cfg.env file and source it with:

```bash
source images-cfg.env
```
It sets the environment variables and you can spinup the stacks with the versions as specified.

Another way is using the `docker-compose.override.yaml`.
Here an example if you want to run an OCI image from our CircleCI pipeline instead the ones published to DockerHub.

Change into a stack directory you want.

```
cd minimal-flows
```

Download a `horizon.oci` artifact from a branch from [CircleCI](https://app.circleci.com/pipelines/github/OpenNMS/opennms) which is created from the `horizon-rpm-build` job.
Load the OCI image into your docker environment with `docker image load -i horizon.oci`, it will be loaded with the tag `horizon:latest`.

Create a `docker-compose.override.yaml` and override the image tag for the horizon service:

```
vi docker-compose.override.yaml
```

```yaml
---
version: '3'
services:
  horizon:
    image: horizon:latest
```

Spin up the stack with `docker-compose up -d`.
The container image directive is now overriden with using your local horizon:latest image tag instead of downloading the one from DockerHub.
