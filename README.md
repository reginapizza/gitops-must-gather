# GitOps Operator Must-Gather
=================

`GitOps must-gather` is a tool to gather information about the gitop-operator. It is built on top of [OpenShift must-gather](https://github.com/openshift/must-gather) and based off the [Istio must-gather tool](https://github.com/maistra/istio-must-gather).

### Usage
```sh
oc adm must-gather --image=docker.io/redhat-developer/gitops-must-gather:latest
```

The command above will create a local directory with a dump of the OpenShift GitOps state. Note that this command will only get data related to the GitOps Operator in your OpenShift cluster.

You will get a dump of:
- Information for the subscription of the gitops-operator
- The GitOps Operator namespace (and its children objects)
- The GitOps Operator namespace (and its children objects)
- All namespaces where ArgoCD objects exist in, plus all objects in those namespaces, such as ArgoCD, Applications, ApplicationSets, and AppProjects, and configmaps
  - No secrets will be collected
- A list of list of the namespaces that are managed by gitops-operator identified namespaces
- All GitOps CRD's definitions
- All GitOps CRD's objects
- All GitOps Webhooks
- Operator logs
- Logs of Argo CD
- Warning and error-level Events

In order to get data about other parts of the cluster (not specific to gitops-operator) you should run just `oc adm must-gather` (without passing a custom image). Run `oc adm must-gather -h` to see more options.
