# stack-play
This repository has some docker-compose container stacks for local labs or for playgrounds to test things out.
We use here just very basics to get a stack up and running nothing for productions.

If you want to look for more advanced production ready deployments with Kubernetes, please look at our [OpenNMS Kubernetes](https://github.com/OpenNMS/opennms-drift-kubernetes) repository.

## Usage

By default we use bleeding container images from latest SNAPSHOT.
The OCI images are downloaded from [DockerHub](https://hub.docker.com/u/opennms).
If you want to use other versions, just edit the image-cfg.env file and source it with:

```bash
source images-cfg.env
```
It sets the environment variables and you can spinup the stacks with the versions as specified.
