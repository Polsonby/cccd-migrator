#!/bin/sh
function _deploy_migrator() {
  usage="deploy -- deploy template-deploy-migrator pod
  into a namespace.
  Usage: kubernetes_deploy/pods/migrator/deploy.sh environment
  Where:
    environment [dev|staging|api-sandbox|production]
    [image_tag] any valid ECR image tag for app
  Example:
    # deploy image for current commit to dev
    deploy.sh dev

    # deploy latest image of master to dev
    deploy.sh dev latest

    # deploy latest branch image to dev
    deploy.sh dev <branch-name>-latest

    # deploy specific image (based on commit sha)
    deploy.sh dev <commit-sha>

  "

  if [ $# -gt 2 ]
  then
    echo "$usage"
    return 0
  fi


  case "$1" in
    dev | staging | api-sandbox | production)
      environment=$1
      ;;
    *)
      echo "$usage"
      return 0
      ;;
  esac

  if [ -z "$2" ]
  then
    current_branch=$(git branch | grep \* | cut -d ' ' -f2)
    current_version=$(git rev-parse $current_branch)
  else
    current_version=$2
  fi

  context='live-1'
  component=migrator
  docker_registry=754256621582.dkr.ecr.eu-west-2.amazonaws.com/laa-get-paid/cccd
  docker_image_tag=${docker_registry}:${component}-${current_version}

  echo "Deleting previous pod..."
  kubectl --context ${context} -n cccd-${environment} delete pod cccd-template-deploy-migrator

  printf "\e[33m--------------------------------------------------\e[0m\n"
  printf "\e[33mJob: .k8s/pod.yaml\e[0m\n"
  printf "\e[33mcontext: $context\e[0m\n"
  printf "\e[33mEnvironment: $environment\e[0m\n"
  printf "\e[33mDocker image: $docker_image_tag\e[0m\n"
  printf "\e[33m--------------------------------------------------\e[0m\n"
  kubectl apply --context ${context} -n cccd-${environment} -f .k8s/${environment}/secrets.yaml
  kubectl set image -f .k8s/pod.yaml cccd-migrator=${docker_image_tag} --local --output yaml | kubectl apply --context ${context} -n cccd-${environment} -f -
}

_deploy_migrator $@
