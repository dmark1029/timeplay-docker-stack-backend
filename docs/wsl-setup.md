## Setup guide for the Docker stack in WSL

------------

## WSL Setup

Firstly, make sure that WSL is enabled; to do this open `Windows Features` scroll until you see Windows Subsystem for Linux and make sure this is checked off.
Next run powershell as administrator and run the following commands:
```
wsl --set-default-version 2
wsl --list --online
```
Doing so will install WSL2. By default this installation will come with ubuntu but for this guide we will be using Debian.
You can either download and install Debian through the Mircosoft store or by running the command: `	wsl --install -d Debian`. This will prompt you to restart your system. After restarting, launch the Debian installation and set up your user and password. Once finished run the commands `sudo apt update` and `sudo apt full-upgrade` to get the lastest version of Debian.

## Docker installation
First we need to enable systemd for WSL. Edit `/etc/wsl.conf` with sudo and add the following lines:
```
[boot]
systemd=true
```
Reboot WSL by going to powershell and running the command `wsl --shutdown`. Once this is complete you can relaunch WSL.
To get Docker setup on WSL, you can run the following commands in order:
```
sudo apt install apt-transport-https ca-certificates curl gnupg
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin
```
We need to make sure that dockerd is up and running by running the command `sudo systemctl start docker`.

You are now ready to start working with Docker on your WSL installation.
