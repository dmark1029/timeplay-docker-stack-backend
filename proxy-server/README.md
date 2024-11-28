# tp3-proxy-server

A customized nginx server that redirects players on the Docker Stack to the different controllers, RMBs, frontends, and services.

## Setup

There should already be a build available in Artifactory to use as a Docker image in the Docker Stack. However, you might want to build your own proxy-server Docker image to test something. Below are some instructions on how to do that.

The proxy-server is built using [`pacman`](https://git.timeplay.com/projects/TOOLS/repos/pacman/browse), our custom build tool, this is run via npx and thus doesn't need to be installed separately

### Dependencies

 * Docker/Podman - to build the container as the last step on the build.json.  **Note: if you are using podman, make sure to have the podman-docker package installed for all the podman -> docker aliases**
 * Nodejs+NPM - to run pacman, see .tools-versions for specific versions. **Note: for this project, the version is irrelavant so long as it can run pacman**

### Building the image

First, export the following variables in your shell, as they are needed by `pacman` to be able to find the builds:

```sh
export artifactoryUser=<your Artifactory username>
export artifactoryPass=<your Artifactory encrypted password - find it in Set Me Up>
```

Then, run the following to perform the build process:

```sh
npm_config_registry=https://artifactory.timeplay.com/artifactory/api/npm/npm-virtual npx --package @timeplay/pacman -- pacman ./proxy-server/build.json
```

`pacman` will then follow the instructions in `build.json`, specifically:
 * download all the frontends and put them into a folder called `staging`, then it will
 * build a Docker image for proxy-server, copying all these frontends over along with the config in `nginx` folder.

The resulting image will be tagged as `tp3-proxy-server:internal`
