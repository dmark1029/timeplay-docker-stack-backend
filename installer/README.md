# TP3 docker stack installer

This folder contains the tp3-docker stack installer, it can be used to install
our stack on any RHEL distribution that satisfies the following requirements:

* docker ce + docker ce cli v24+ installed
* has the cli utilities:
  * curl
  * jq
  * filebeat 7.3+
* Has the "timeplay" user, as well as the "docker" user.

## Usage

To use the installer, run:

```
bash install.sh <path-to-overrides.env>
```

The `overrides.env` file must use the full path, and needs to have all the
environment variables defined in the overrides.example.ships.env

## Folder structure

```
root
 |- certs
    |- log-agent.timeplay.me (optional)
       |- agent.crt
       |- agent.key
       |- root_ca.crt
    |- timeplay.crt
    |- timeplay.key
 |- configs
    |- <individual app configs>
 |- gs-packages (optional)
    |- <game packages to install>
 |- images (optional)
    |- <docker images to install>
 |- stack
    |- <stack files>
 |- defaults.env
 |- enable-ntp.sh
 |- install.sh
```

## Customizations

The folder structure has folders labeled `(optional)`, the existance of these
folders determine if specific custom operations are run by the installer.

This section covers each of the optional operations.

### Certs

The certs directory should contain all the certificates you need to get up
and running, however the `log-agent.timeplay.me` directory is optional.

This directory, if present, contains the files:

* agent.crt
* agent.key
* root_ca.crt

Which are used to configure haproxy with the appropriate certificates to
forward filebeat packets to our remote elasticearch+graylog instance.

### Loading images offline

In cases where the internet connection on the target server is really bad or
non-existant, you can pre-populate the `images` directory with all of the
images you need.  There is a `save.sh` and `save-list.txt` file already there
to give you an idea of how to pull the images locally.

### Loading gs packages offline

In cases where the internet connection on the target server is really bad or
non-existant, you can pre-populate the gs-packages directory with all of the
images you may need.  The packages should be the exact packages that the
package service would otherwise grab.  Additionally the files must adhere
the following naming convention:

```
<package-name>-<distribution>-<version>.zip
```

for example, if you want to pre-load the wheel of fortune 1.1.0-19 package,
then you would download the package from artifactory at:

https://artifactory.timeplay.com/ui/repos/tree/General/wheel-of-fortune-snapshot-local/com.timeplay/wheel-of-fortune/wof-bigscreen/1.1.0/wof-bigscreen-1.1.0-19/StandaloneWindows64

Note: you should right click on the `StandaloneWindows64` folder and select
download, then select zip.

After you have downloaded the zip, rename place it into the `gs-packages`
folder and rename it to `wheeloffortune-win64-1.1.0-19.zip`
