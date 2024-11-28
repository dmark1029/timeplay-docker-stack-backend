@Library('pipeline-library@release/1.0.0') _

// see: https://www.jenkins.io/doc/book/pipeline/cps-method-mismatches/#PipelineCPSmethodmismatches-ClosuresinsideGString
def INTERNAL_ZIP_TPL = { -> "${REPO_NAME}-${fullVersion}.zip" }
def PARTNER_ZIP_TPL = { -> "${REPO_NAME}-${partner}-${fullVersion}.zip" }

def SHIP_PARTNERS = ["carnival","celebrity","ncl"]

def prepareBaseFiles(proxyContainerKey, proxyContainer, stackVersionKey, fullVersion) {
  baseFile = "base.env"
  versionsFile = "base-versions.env"
  sh """
    sed -i.bak "s|^${stackVersionKey}=.*\$|${stackVersionKey}=${fullVersion}|" ${baseFile} && rm ${baseFile}.bak
    sed -i.bak "s|^${proxyContainerKey}=.*\$|${proxyContainerKey}=\\\${REPO_IMAGE_BASE}/${proxyContainer}:${fullVersion}|" ${versionsFile} && rm ${versionsFile}.bak
  """.stripIndent()
}

pipeline {
  agent {
    node {
      label instanceManager.getInstance('linux')
    }
  }
  options {
    timeout(time: 60, unit: 'MINUTES')
    skipDefaultCheckout()
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '' + common.config.numToKeepStr,
    daysToKeepStr: '' + common.config.daysToKeepStr,
    artifactNumToKeepStr: '' + common.config.artifactNumToKeepStr,
    artifactDaysToKeepStr: '' + common.config.artifactDaysToKeepStr))
  }
  environment {
    PROJECT_KEY = "tp3"
    REPO_NAME = "tp3-docker-stack"
    VERSION_FILE = "version.txt"
    baseVersion = "0.0.0"
    fullVersion = "0.0.0-0"

    stackVersionKey = "STACK_VERSION"
    proxyContainerKey = "IMAGE_PROXY_SERVER"
    proxyContainer = "tp3-proxy-server"

    partner = "placeholder-needed-for-tpl-to-work"
  }
  triggers {
    pollSCM('')
  }
  stages {
    stage('Clone') {
      steps {
        cleanWs()
        echo 'Cloning..'
        script {
          gitSSHCheckout {
            withMerge = false
            withWipeOut = true
            withBuildProperties = true
          }
        }
      }
    }
    stage('Setup') {
      when { not { tag "deploy-*" } }
      steps {
        script {
          withCredentials([
            usernamePassword(credentialsId: "jenkins-service-account", usernameVariable: 'ART_USERNAME', passwordVariable: 'ART_PASSWORD'),
            usernamePassword(credentialsId: "ships-repo-service-account", usernameVariable: 'NEXUS_USERNAME', passwordVariable: 'NEXUS_PASSWORD')
          ]) {
            sh """\
              echo '${ART_PASSWORD}' | docker login -u '${ART_USERNAME}' --password-stdin registry.timeplay.com/docker-snapshot-local
              echo '${ART_PASSWORD}' | docker login -u '${ART_USERNAME}' --password-stdin registry.timeplay.com/docker-virtual
              echo '${NEXUS_PASSWORD}' | docker login -u '${NEXUS_USERNAME}' --password-stdin registry.timeplay.com/docker-virtual

              asdf install
            """.stripIndent()
          }
        }
      }
    }
    stage('Build Proxy') {
      when { not { tag "deploy-*" } }
      steps {
        script {
          withCredentials([usernamePassword(credentialsId: "jenkins-service-account", usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
            sh """
              # remove all images in this repository
              docker 2>/dev/null 1>&2 rmi -f `docker images -q ${proxyContainer} | uniq` || true
              docker 2>/dev/null 1>&2 rmi -f `docker images -q registry.timeplay.com/docker-snapshot-local/${proxyContainer} | uniq` || true

              # Build image
              export artifactoryUser=${USERNAME}
              export artifactoryPass=${PASSWORD}
              export gitUser=${USERNAME}
              export gitPass=${PASSWORD}
              npx --package @timeplay/pacman -- pacman ./proxy-server/build.json
            """
          }
        }
      }
    }
    stage('Build Installer') {
      when { not { tag "deploy-*" } }
      steps {
        script {
          props = readProperties file: "build.properties"
          baseVersion = "${props.VERSION}"
          fullVersion = "${props.VERSION}-${BUILD_NUMBER}"

          echo "Writing ${fullVersion} in version file ${VERSION_FILE}"
          sh "echo ${fullVersion}> ${VERSION_FILE}"

          // artifactory zip should contain all partners, this is what we are using to deploy to internal environments
          artifactoryZip = "${WORKSPACE}/${INTERNAL_ZIP_TPL()}"

          // baseZip should contain no partners, and is used as a base to build the partner specific zips
          baseZip = "${WORKSPACE}/${REPO_NAME}-base-${fullVersion}.zip"

          prepareBaseFiles(proxyContainerKey, proxyContainer, stackVersionKey, fullVersion)
          sh """
            mkdir -p ./installer/stack
            find . -maxdepth 1 -mindepth 1 \\
              ! -name '.*' \\
              ! -name '*.zip' \\
              ! -name '*example*' \\
              ! -name 'docs' \\
              ! -name 'logs' \\
              ! -name 'deploy' \\
              ! -name 'Tiltfile' \\
              ! -name 'partner' \\
              ! -name 'README.md' \\
              ! -name 'installer' \\
              ! -name 'effective.*' \\
              ! -name 'development' \\
              ! -name 'Jenkinsfile' \\
              ! -name 'proxy-server' \\
              ! -name 'manifest.json' \\
              ! -name 'container-data' \\
              ! -name 'build.properties' \\
              -exec cp -r {} ./installer/stack \\;
          """

          dir ("installer") {
            sh """
              zip -r "${baseZip}" .
              cp "${baseZip}" "${artifactoryZip}"

              cp -r "${WORKSPACE}/partner" "stack/"
              zip -ru "${artifactoryZip}" .
            """

            SHIP_PARTNERS.each { curr_partner ->
              partner = curr_partner
              partnerZip = "${WORKSPACE}/${PARTNER_ZIP_TPL()}"
              sh """
                echo "building partner zip: ${partnerZip}"
                cp "${baseZip}" "${partnerZip}"
                zip -ru "${partnerZip}" "./stack/partner/${partner}"
              """
            }
          }
        }
      }
    }
    stage('Publish to Artifactory') {
      when { not { tag "deploy-*" } }
      steps {
        script {
          if (common.config.uploadableBranch) {
            artContainerName = "registry.timeplay.com/docker-snapshot-local/${proxyContainer}:${fullVersion}"
            nexusContainerName = "registry.timeplay.com/docker-virtual/${proxyContainer}:${fullVersion}"
            imgName = "${proxyContainer}"

            dir ("proxy-server") {
              sh """\
                # see: https://github.com/moby/buildkit/issues/2761#issuecomment-1745626228
                export BUILDX_NO_DEFAULT_ATTESTATIONS=1
                docker buildx build --platform linux/amd64,linux/arm64 --output type=registry -t ${artContainerName} -t ${nexusContainerName} .

                # Builds an img file for amd+arm
                docker buildx build --platform linux/amd64 --output type=docker,dest=../${imgName}-amd64.img -t ${artContainerName} -t ${nexusContainerName} .
                docker buildx build --platform linux/arm64 --output type=docker,dest=../${imgName}-arm64.img -t ${artContainerName} -t ${nexusContainerName} .
              """.stripIndent()
            }

            sharedServices.uploadGPSPackage("linux-amd64-docker/${imgName}/${fullVersion}", "${imgName}-amd64.img")
            sharedServices.uploadGPSPackage("linux-arm64-docker/${imgName}/${fullVersion}", "${imgName}-arm64.img")
            SHIP_PARTNERS.each { curr_partner ->
              partner = curr_partner
              sharedServices.uploadNexusPackage("./${PARTNER_ZIP_TPL()}", "ships-${partner}", "docker-stack-installer/${fullVersion}/tp3-docker-stack-installer.zip")
            }

            sharedServices.uploadNexusPackage("./${INTERNAL_ZIP_TPL()}", "ships-internal", "docker-stack-installer/${fullVersion}/tp3-docker-stack-installer.zip")
            artifactory.uploadArtifacts("(${INTERNAL_ZIP_TPL()})", "{1}", [".git/*"], "false")
          } else {
            echo "INFO: Artifact upload for branch ${env.BRANCH_NAME} is not allowed. Please get artifacts from build workspace instead"
          }
        }
      }
    }
    stage('Tag release build') {
      when { not { tag "deploy-*" } }
      steps {
        script {
          if (common.config.uploadableBranch) {
            def versionTag = "v${fullVersion}"
            sh "git tag -af '${versionTag}' -m 'Automatic tag by jenkins'"
            sh "git push origin '${versionTag}'"
          }
        }
      }
    }
    stage('deploy') {
      when { tag "deploy-*" }
      steps {
        script {
          def (envName, version, commitHash) = deployTag.getVersion(TAG_NAME, true, true)
          version = version - 'v'

          def overridesFile = "deploy/${envName}.overrides.env"
          if (!fileExists(overridesFile)) {
            error("Failed to find environment file ${envName}")
          }

          prepareBaseFiles(proxyContainerKey, proxyContainer, stackVersionKey, version)

          // generate deployment manifest based on the specific environment overrides
          sh """\
            cp -f '${overridesFile}' overrides.env
            ./run.sh manifest
          """.stripIndent()

          // deploy!
          sharedServices.deployDockerStack('./effective.env', './overrides.env', './manifest.json')
        }
      }
    }
  }
  post {
    success { echo "Build was successful" }
    unstable { echo "Build was unstable" }
    failure { echo "Build failed" }
    always {
      script {
        sendNotifications(currentBuild.result, "email, mattermost", "false", "#tp3")
      }
      echo "ALWAYS"
    }
  }
}
