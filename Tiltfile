load('ext://dotenv', 'dotenv')

# reading effective.env for full list of environment variables for the stack
dotenv(fn='effective.env')

STACK_PARTNER = os.getenv("STACK_PARTNER")
STACK_SCHEME = os.getenv("STACK_SCHEME")
STACK_COMPONENTS = os.getenv("STACK_COMPONENTS")

print("STACK_PARTNER: %s"%(STACK_PARTNER))
print("STACK_SCHEME: %s"%(STACK_SCHEME))
print("STACK_COMPONENTS: %s"%(STACK_COMPONENTS))

# reading the effective docker-compose yml as well as the debug ymls to be used for debugging
ymls = ["effective.docker-compose.yml", "docker-compose.debug.yml", "schemes/%s/docker-compose.%s.debug.yml"%(STACK_SCHEME, STACK_SCHEME)]
print(ymls)

COMPOSE_PROJECT_NAME = os.getenv("COMPOSE_PROJECT_NAME")

docker_compose(ymls, project_name=COMPOSE_PROJECT_NAME)

node_services = [
  # Base TP3 Node services
  {
    'name': 'web-client-service',
    'path_env': os.getenv('WCS_PATH'),
    'image_env': os.getenv('IMAGE_WCS'),
    'install_cmd': 'npm run build-ci',
    'workdir': '/usr/src/app'
  },
  {
    'name': 'game-room',
    'path_env': os.getenv('ROOM_PATH'),
    'image_env': os.getenv('IMAGE_ROOM'),
    'install_cmd': 'npm run build-ci',
    'workdir': '/usr/src/app'
  },
  {
    'name': 'session-manager',
    'path_env': os.getenv('SESSION_MANAGER_PATH'),
    'image_env': os.getenv('IMAGE_SESSION_MANAGER'),
    'install_cmd': 'npm run build-ci',
    'workdir': '/usr/src/app'
  },
  {
    'name': 'playlist-manager',
    'path_env': os.getenv('PLAYLIST_MANAGER_PATH'),
    'image_env': os.getenv('IMAGE_PLAYLIST_MANAGER'),
    'install_cmd': 'npm run build-ci',
    'workdir': '/usr/src/app'
  },
  {
    'name': 'gs-license-service',
    'path_env': os.getenv('LICENSE_SERVICE_PATH'),
    'image_env': os.getenv('IMAGE_LICENSE_SERVICE'),
    'install_cmd': 'npm run build-ci',
    'workdir': '/usr/src/app'
  },
  {
    'name': 'gs-package-service',
    'path_env': os.getenv('PACKAGE_SERVICE_PATH'),
    'image_env': os.getenv('IMAGE_PACKAGE_SERVICE'),
    'install_cmd': 'npm run build-ci',
    'workdir': '/usr/src/app'
  },
  {
    'name': 'asset-manager',
    'path_env': os.getenv('ASSET_MANAGER_PATH'),
    'image_env': os.getenv('IMAGE_ASSET_MANAGER'),
    'install_cmd': 'npm run build-ci',
    'workdir': '/usr/src/app'
  },

  # Ship-specific Node services
  {
    'name': 'reward-service',
    'path_env': os.getenv('REWARD_SERVICE_PATH'),
    'image_env': os.getenv('IMAGE_REWARD_SERVICE'),
    'install_cmd': 'npm run build-ci',
    'workdir': '/usr/src/app'
  },
  {
    'name': 'sessions',
    'path_env': os.getenv('SESSIONS_PATH'),
    'image_env': os.getenv('IMAGE_SESSIONS'),
    'install_cmd': 'npm run build-ci',
    'workdir': '/usr/src/app'
  },
  {
    'name': 'transaction-service',
    'path_env': os.getenv('TRANSACTION_SERVICE_PATH'),
    'image_env': os.getenv('IMAGE_TRANSACTION_SERVICE'),
    'install_cmd': 'npm run build-ci',
    'workdir': '/usr/src/app'
  },
  {
    'name': 'tp3-data-uploader',
    'path_env': os.getenv('DATA_UPLOADER_PATH'),
    'image_env': os.getenv('IMAGE_DATA_UPLOADER'),
    'install_cmd': 'npm run build-ci',
    'workdir': '/usr/src/app'
  },

  # DOND-specific Node services
  {
    'name': 'dond-client-service',
    'path_env': os.getenv('DOND_CLIENT_SERVICE_PATH'),
    'image_env': os.getenv('IMAGE_DOND_CLIENT_SERVICE'),
    'install_cmd': 'npm run build-ci',
    'workdir': '/usr/src/app'
  }
]

NPM_TOKEN = os.getenv('NPM_TOKEN')
if NPM_TOKEN == None:
  print("----------------------------------------------------")
  print("-> Please provide NPM token (as NPM_TOKEN environment variable) if you want to use your local copies of Node services.")
  print("-> You can get this from Artifactory.")
  print("-> Skipping Node service linking...")
  print("----------------------------------------------------")
else:
  for service in node_services:
    print(service)
    print(service["path_env"])
    if service["path_env"]:
      docker_build(service["image_env"], service["path_env"],
        build_args={'NPM_TOKEN': NPM_TOKEN},
        live_update=[
          sync(service["path_env"], service["workdir"]),
          run(service["install_cmd"], trigger='package.json'),
          restart_container()
        ]
      )

go_services = [
  # Base TP3 Go services
  {
    'name': 'task-spawner',
    'path_env': os.getenv('TASK_SPAWNER_PATH'),
    'image_env': os.getenv('IMAGE_TASK_SPAWNER'),
    'install_cmd': 'cd src && go mod download',
    'workdir': '/usr/src/app'
  },

  # Ship-specific Go services
  {
    'name': 'ships-service',
    'path_env': os.getenv('SHIPS_SERVICE_PATH'),
    'image_env': os.getenv('IMAGE_SHIPS_SERVICE'),
    'install_cmd': 'go mod download',
    'workdir': '/usr/src/app'
  },
  {
    'name': 'update-service',
    'path_env': os.getenv('UPDATE_SERVICE_PATH'),
    'image_env': os.getenv('IMAGE_UPDATE_SERVICE'),
    'install_cmd': 'go mod download',
    'workdir': '/usr/src/app'
  },
  {
    'name': 'card-service',
    'path_env': os.getenv('CARD_SERVICE_PATH'),
    'image_env': os.getenv('IMAGE_CARD_SERVICE'),
    'install_cmd': 'cd src && go mod download',
    'workdir': '/usr/src/app'
  },
]

GOPROXY = os.getenv('GOPROXY')
GONOSUMDB = os.getenv('GONOSUMDB')
if GOPROXY == None or GONOSUMDB == None:
  print("----------------------------------------------------")
  print("-> Please provide Go registry credentials (as GOPROXY and GONOSUMDB environment variables) if you want to use your local copies of Go services.")
  print("-> You can get GOPROXY from Artifactory.")
  print("-> Make sure GOPROXY has ',https://proxy.golang.org,direct' at the end of it")
  print("-> GONOSUMDB should be 'artifactory.timeplay.com'")
  print("-> Skipping Go service linking...")
  print("----------------------------------------------------")
else:
  for service in go_services:
    print(service)
    print(service["path_env"])
    service_name=service["name"]
    if service["path_env"]:
      dockerfile = read_file(service["path_env"] + "/Dockerfile-dev")
      print(dockerfile)
      docker_build(service["image_env"], service["path_env"],
        dockerfile_contents=dockerfile,
        build_args={
          'GOPROXY': GOPROXY,
          'GONOSUMDB': GONOSUMDB,
        },
        live_update=[
          sync(service["path_env"], service["workdir"]),
          run(service["install_cmd"], trigger='go.mod'),
          restart_container()
        ]
      )

proxy_server_deps=[]
proxy_server_ignore_files=[]
overrides = read_yaml("docker-compose.overrides.yml")
if overrides["services"]["proxy-server"] != None:
  for volume in overrides["services"]["proxy-server"]["volumes"]:
    dep = volume.split(":")[0]
    print(dep, dep + "/config.json")
    proxy_server_deps.append(dep)
    proxy_server_ignore_files.append(dep + "/config.json")

# TP3 Proxy Server - restart container when files are changed
local_resource('restart-proxy-server', cmd='docker restart proxy-server',
  deps=proxy_server_deps,
  ignore=proxy_server_ignore_files,
  auto_init=False
)

# Update Host - whenever hosts file is updated, update the HOST_IP variable in overrides.env
local_resource('update host',
  cmd='sed -i.bak "s/HOST_IP=.*/HOST_IP=$ip/" overrides.env && rm -f overrides.env.bak',
  env={
    'ip': local("bash ./scripts/get_host.sh"),
  },
  deps=["/etc/hosts", "/mnt/c/Windows/System32/drivers/etc/hosts"]
)

# Generate Config - whenever overrides.env is updated, regenerate effective config
local_resource('generate effective config', cmd="bash generate-configs.sh", deps=["overrides.env", "docker-compose.overrides.yml"])
