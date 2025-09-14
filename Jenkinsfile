// Jenkins Pipeline for building, testing, scanning, pushing, and deploying a Go application

pipeline {
    agent any // Run on any available agent

    tools {
        go 'go1.22.0' // Specify Go version to use
    }

    environment {
        // Docker image details
        IMAGE_NAME      = 'jenkins-go-app'
        IMAGE           = "jakirhosen9395/${IMAGE_NAME}"
        TAG             = "${env.BUILD_ID}" // Use Jenkins build ID as image tag

        // Source code repository details
        CODE_REPO       = 'git@github.com:jakirhosen9395/developer-repo.git'
        CODE_BRANCH     = 'go-app-develop'

        // SonarQube scanner tool location
        SCANNER_HOME    = tool 'sonar7.2'

        // Kubernetes manifest repository details
        MANIFEST_REPO   = 'git@github.com:jakirhosen9395/deploy-repo.git'
        MANIFEST_BRANCH = 'k8s-manifest'
        MANIFEST_FILE   = 'go-app-cicd.yaml'

        // Deployment server and Docker container details
        CONTAINER_NAME  = 'jenkins-go-app'
        PORT_MAP        = '9001:9000'
        HOST            = 'root@192.168.56.51'
        SSH_CREDENTIALS = 'ssh-deploy-key'
    }

    stages {
        stage('Checkout source') {
            steps {
                // Clone the application source code from GitHub
                git branch: "${CODE_BRANCH}",
                    credentialsId: 'github-ssh-key',
                    url: "${CODE_REPO}"
            }
        }

        stage('Unit test + Coverage') {
            steps {
                // Run Go unit tests and generate code coverage report
                withEnv(["PATH+GO=/usr/local/go/bin"]) {
                    sh '''
                        go test ./... -coverprofile=coverage.out -covermode=atomic
                        test -s coverage.out // Ensure coverage report is generated
                    '''
                }
            }
        }

        stage('SonarQube Scan') {
            steps {
                // Analyze code quality and coverage using SonarQube
                withSonarQubeEnv('SonarQube-Server') {
                    withEnv(["PATH+SCANNER=${SCANNER_HOME}/bin"]) {
                        sh '''
                            sonar-scanner \
                                -Dsonar.projectKey=go-calculator \
                                -Dsonar.projectName=go-calculator \
                                -Dsonar.projectVersion=1.0 \
                                -Dsonar.sourceEncoding=UTF-8 \
                                -Dsonar.sources=. \
                                -Dsonar.inclusions=**/*.go,**/*.html \
                                -Dsonar.exclusions=**/vendor/**,**/*.gen.go \
                                -Dsonar.tests=. \
                                -Dsonar.test.inclusions=**/*_test.go \
                                -Dsonar.go.coverage.reportPaths=coverage.out
                        '''
                    }
                }
            }
        }

        // stage('Quality Gate') {
        //     steps {
        //         // Optionally, wait for SonarQube quality gate result before proceeding
        //         timeout(time: 10, unit: 'MINUTES') {
        //             waitForQualityGate abortPipeline: false
        //         }
        //     }
        // }

        stage('Build image') {
            steps {
                // Build Docker image for the application
                sh '''
                    test -f Dockerfile || cp /opt/docker/Dockerfile . // Use default Dockerfile if not present
                    docker build -t ${IMAGE}:${TAG} .
                '''
            }
        }

        stage('Docker Login') {
            steps {
                // Authenticate to Docker Hub using credentials stored in Jenkins
                withCredentials([usernamePassword(credentialsId: 'docker-hub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
                }
            }
        }

        stage('Push image') {
            steps {
                // Push the built Docker image to Docker Hub
                sh 'docker push ${IMAGE}:${TAG}'
            }
        }

        stage('Update k8s manifest in deploy-repo') {
            steps {
                // Update Kubernetes manifest file with new Docker image tag and push changes to GitHub
                sshagent(credentials: ['github-ssh-key']) {
                    sh '''
                        rm -rf deploy-repo // Remove any existing local copy
                        git clone -b ${MANIFEST_BRANCH} ${MANIFEST_REPO} deploy-repo // Clone manifest repo
                        cd deploy-repo

                        // Update image tag in manifest file
                        sed -i -E 's#image:[[:space:]]*"?jakirhosen9395/'"${IMAGE_NAME}"':[^"[:space:]]*#image: "jakirhosen9395/'"${IMAGE_NAME}"':'"${TAG}"'#g' "${MANIFEST_FILE}"

                        git config user.name "jenkins-bot"
                        git config user.email "jenkins@local"
                        git add "${MANIFEST_FILE}"
                        git commit -m "update ${MANIFEST_FILE} image tag to ${TAG}" || true // Commit changes
                        git push origin "${MANIFEST_BRANCH}" // Push to remote repo
                    '''
                }
            }
        }

        stage('Deploy from Docker Hub') {
            steps {
                // Deploy the updated Docker image to the remote server using SSH
                sshagent(credentials: [SSH_CREDENTIALS]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${HOST} \
                            'docker rm -f ${CONTAINER_NAME} || true && \
                             docker pull ${IMAGE}:${TAG} && \
                             docker run -d --name ${CONTAINER_NAME} -p ${PORT_MAP} --restart always \
                                 -e HOST=0.0.0.0 -e PORT=9000 ${IMAGE}:${TAG}'
                    '''
                }
            }
        }
    }
}
