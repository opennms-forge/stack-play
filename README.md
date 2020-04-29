# stack-play
This repository has some docker-compose container stacks for local labs or for playgrounds to test things our.

## Usage

By default we use bleeding container images from latest SNAPSHOT.
The OCI images are downloaded from [DockerHub](https://hub.docker.com/u/opennms).
If you want to use other versions, just edit the image-cfg.env file and source it with:

```bash
source images-cfg.env
```
It sets the environment variables and you can spinup the stacks with the versions as specified.
