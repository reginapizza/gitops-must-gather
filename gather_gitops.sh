#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck source=/dev/null
source "${SCRIPT_DIR}"/common

# Expect base collection path as an argument
BASE_COLLECTION_PATH=$1

# Use PWD as base path if no argument is passed
if [ "${BASE_COLLECTION_PATH}" = "" ]; then
    BASE_COLLECTION_PATH=$(pwd)
fi

NAMESPACE=${2:-openshift-gitops}

GITOPS_COLLECTION_PATH="$BASE_COLLECTION_PATH/cluster-gitops"
gitops_folder="$GITOPS_COLLECTION_PATH/gitops"

# Set the color variable
red='\033[0;31m'

# Auxiliary function that adds a k8s prefix to a resource
# $1: The prefix - e.g. "ns" or "pod"
# $2...$N: Resources
# Returns: The list of resources with the prefix prepended on them
#
# Example: addResourcePrefix pod a b c  => Returns: pod/a pod/b pod/c
function addResourcePrefix() {
  local result=""
  local prefix="${1}"
  shift

  for ns in "$@"; do
    result+=" ${prefix}/${ns} "
  done

  echo "${result}"
}

# Get all ArgoCD namespaces in the cluster
function getArgoCDsNamespaces() {
  local result=()
  local namespaces
  namespaces=$(oc get ArgoCD --all-namespaces -o jsonpath='{.items[*].metadata.namespace}')
  for namespace in ${namespaces}; do
    result+=("${namespace}")
  done

  printf "%s\n" "${result[@]}"
}

# Get all ArgoCDs in the namespaces provided by getArgoCDsNamespaces
function getArgoCDs() {
  local result
  local namespaces
  namespaces="$(getArgoCDsNamespaces)"
  for namespace in ${namespaces}; do
    result=$(oc get ArgoCD -n "${namespace}")
    echo "${result[@]}"
    echo ""
  done
}

# Get all resources in all argocd namespaces
function getAllArgoCDResources() {
  local result
  local namespaces
  namespaces="$(getArgoCDsNamespaces)"
  for namespace in ${namespaces}; do
    result=$(oc get all -n "${namespace}")
    echo -e "Namespace '${namespace}':"
    echo "${result[@]}"
    echo ""
  done
}

#Get all Applications
function getApplications() {
  local result
  oc get Applications --all-namespaces -o yaml
  echo "${result}"
}

# Get all ApplicationSets
function getApplicationSets() {
  local result
  oc get ApplicationSets --all-namespaces -o yaml
  echo "${result}"
}

# Get all ApplicationProjects
function getAppProjects() {
  local result
  oc get AppProjects --all-namespaces -o yaml
  echo "${result}"
}

# Get logs for every deployment
# tr '|' '\t' < file | column -t (command to change to column format)
function getOperatorLogs() {
  local namespaces
  namespaces="$(getArgoCDsNamespaces)"
  for namespace in ${namespaces}; do
    local deploymentResult=""
    local deployments
    deployments=$(oc get deployments -n "${namespace}" -o jsonpath='{.items[*].metadata.name}')
    # for deployment in ${deployments}; do
    for (( i=0; i< ${#deployments[@]}; i++ )); do
      echo "Deployments are: ${deployments}"
      # if [ "$i" -eq 0 ]; then
      #   deploymentResult+=$(oc get deployment/"${deployments[i]}" -n "${namespace}")"\n"
      # else
        deploymentResult+=$(oc get deployment/"${deployments[i]}" -n "${namespace}" --no-headers=true)"\n"
      # fi
    done
    local statefulsetResult=""
    local statefulsets
    statefulsets=$(oc get statefulset -n "${namespace}" -o jsonpath='{.items[*].metadata.name}')
    for statefulset in ${statefulsets}; do
      statefulsetResult+=$(oc get statefulset/"${statefulset}" -n "${namespace}")
    done

    echo -e "Deployments in namespace '${namespace}':"
    echo -e "${deploymentResult}" | column -t 
    echo -e "StatefulSets in namespace '${namespace}':"
    echo -e "${statefulsetResult}"| column -t
    echo ""
  done
}


function main() {
  echo
  echo -e "${red}Starting GitOps Operator must-gather script...${clear}"
  mkdir -p "$gitops_folder"
  echo
  
  echo
  echo -e "OpenShift Cluster Version:"
  oc version > "${gitops_folder}"/oc-version.txt 2>&1
  echo

  echo -e "Cluster Service Versions"
  for csv in $(oc -n "${NAMESPACE}" get csv -o name) ; do
    oc -n "${NAMESPACE}" get "${csv}" -o yaml > "${gitops_folder}/${csv}.yaml"
  done
  echo

  echo 
  echo -e "GitOps Operator Version:"
  oc get sub openshift-gitops-operator -n openshift-operators -o yaml | grep -oP '(currentCSV: openshift-gitops-operator)\K.*' | cut -c 2- > "${gitops_folder}"/gitops-operator-version.txt 2>&1
  echo

  echo
  echo -e "GitOps Operator Subscription:"
  oc describe sub openshift-gitops-operator -n openshift-operators > "${gitops_folder}"/subscription.txt 2>&1
  echo

  echo
  echo -e "${red}Pods for GitOps Operator:"
  oc get pods -n openshift-gitops -o wide > "${gitops_folder}"/pods.txt 2>&1
  echo

  echo
  echo -e "Deployments for GitOps Operator:"
  for deployment in $(oc -n "${NAMESPACE}" get csv -o name) ; do
    oc -n "${NAMESPACE}" get "${deployment}" -o yaml > "${gitops_folder}"/deployment_"${deployment}".yaml
  done
  echo

  echo
  echo -e "Secrets for GitOps Operator"
  oc -n "${NAMESPACE}" get secrets -o yaml > "${gitops_folder}"/secrets.yaml 2>&1
  echo

  echo
  echo -e "Namespaces where ArgoCD instances are present:"
  getArgoCDsNamespaces  > "${gitops_folder}"/argocds.txt 2>&1
  echo

  echo
  echo -e "Namespaces where ArgoCD instances are present:"
  getAllArgoCDResources  > "${gitops_folder}"/argocds.txt 2>&1
  echo

  echo
  echo -e "ArgoCDs:"
  getArgoCDs  > "${gitops_folder}"/argocds.txt 2>&1
  echo

  echo
  echo -e "Applications:"
  getApplications  > "${gitops_folder}"/applications.txt 2>&1
  echo

  echo
  echo -e "ApplicationSets:"
  getApplicationSets  > "${gitops_folder}"/applicationsets.txt 2>&1
  echo

  echo
  echo -e "AppProjects:"
  getAppProjects  > "${gitops_folder}"/appprojects.txt 2>&1
  echo

  echo
  echo -e "GitOps Operator Events (Warnings only):"
  oc get events -n openshift-gitops --field-selector type=Warning  > "${gitops_folder}"/events.txt 2>&1
  echo 

  echo
  echo -e "GitOps Operator Events (Errors only):"
  oc get events -n openshift-gitops --field-selector type=Error > "${gitops_folder}"/events.txt 2>&1
  echo

  echo
  echo -e "GitOps CRDs:"
  oc get crds -l operators.coreos.com/openshift-gitops-operator.openshift-operators > "${gitops_folder}"/crds.txt 2>&1
  echo

  echo
  echo
  echo -e "Done! Thank you for using the GitOps must-gather tool :)"
  echo
}

main "$@"
