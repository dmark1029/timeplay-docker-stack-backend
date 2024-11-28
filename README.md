# tp3-docker-stack

This is the repository for the TP3 Docker Stack.

## Setup

After cloning the repo, create `overrides.env` file in the repo root directory.

Copy and paste values from `overrides.example.env` and update them to fit your development environment.

STACK_COMPONENTS: This does not include keycloak. This defaults to use stg keycloak under Timeplay realm. This is sufficient for most development. If you need to use Users realm, override AUTH_REALM as well as all the auth secrets.

STACK_PARTNER: use `timeplay` if you're not sure what partner to use.

HOST_IP: update to your local network's public IP

## Start the stack

Start the stack by running `sh ./run.sh build start`, or, if you don't need to re-build proxy-server, `sh ./run.sh start`, this does the following:

* Rebuilds proxy-server (build only)
* Runs `generate-configs.sh`
* Sources the generated `effective.env`
* Runs `fetch-certs.sh`
* Runs docker-compose

If you run into any issues, you can break things down, by running each of the steps above individually with the `bash -x` flag

## Certificates

Certificates are now automatically fetched when you run `run.sh start`, however, if you run into issues fetching the certifications, you can run `bash -x fetch-certs.sh` script to debug the issue independantly.

## Mac Developers

There are several tools the scripts use that are either unavailable or incompatible on macos.

Some of these tools can be installed by brew but base64 util has further complication. This guide use MacPorts instead to install all tools.

For developers using macos, install the following:

* Install MacPorts from https://www.macports.org/install.php

* Add `opt/local/libexec/gnubin/` to your PATH. For example, add the following to your ~/.zprofile
  `PATH="/opt/local/libexec/gnubin/:${PATH+:$PATH}";`

### bash v4 or higher

* Install a higher version of bash
    `sudo port install bash`

* Verify the terminal is using bash from MacPorts and the version is higher than v3
    `which bash`
    `bash --version`

### jq

* Install jq
    `sudo port install jq`

* Verify the installation
    `which jq`
    `jq --version`

### base64

The script `fetch-certs.sh` use base64 util but the version in brew is named gbase64.

For reason unclear, alias gbase64 to base64 does not seem to work in the script, even when the command works in terminal directly.

The workaround is to use the version from MacPorts and install coreutils from MacPorts.

* Install coreutils
   `sudo port install coreutils`

If you also have coreutils installed via Homebrew, uninstall it by running `brew uninstall coreutils`.

## Running the Docker Stack on Tilt

To set up and run the project using Tilt for local development, follow these steps:

> Note: Tilt is not required for normal installation; it is only needed for local development.

1. **Install Tilt**
   Download and install Tilt from the official [Tilt installation guide](https://docs.tilt.dev/install.html). You can skip the Kubernetes part, as it is not needed for this project. Tilt is available for macOS, Linux, and Windows.

   > Note: If using Windows, install Tilt on WSL and ensure your project files are located on the WSL filesystem as you may run into issues:
   > - postgres init script mounting as directory
   > - Tilt unable to watch for changes and live update (for more info see [here](https://github.com/microsoft/WSL/issues/4739))

2. **Run Tilt**
   Navigate to the root folder of the project and execute the following command:
   ```sh
   tilt up
   ```

3.  **Monitor and Manage**
    While Tilt is running, press the space bar on the terminal window to open the Tilt UI in your browser. This UI will allow you to monitor the status of your containers as they start up and run.

For more detailed information on using Tilt, refer to the [Tilt documentation](https://docs.tilt.dev/).