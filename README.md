# Sample implementation of Azure Kubernetes Service "anti-DRY" bootstrap & maintenance strategy

## Table of Contents

- [Background](#background)
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Notes](#notes)

## Background <a name = "background"></a>

It's hard to keep up with the evolution of Kubernetes. Significantly, upgrade strategy is a headache.

Blue/Green deployment is an effective strategy to mitigate the risk of upgrades. On the other hand, the challenge is how to manage the differences between the Blue and Green codes of infrastructure. DRY(Don't Repeat Yourself) is a typical concept that solves this problem, but its implementation tends to be cumbersome.

For example, there are several ways to achieve DRY with Terraform. Workspace, Module, specifying git tag as a source, git branching strategy & flow, etc. These are helpful ways, but it isn't easy to understand, design, operate, and maintain for developers early in the IaC and Kubernetes learning curve. In addition, in the rapidly evolving Kubernetes, it's common to want to redesign the code that creates the cluster. So, standardization of Blue/Green by Module often breaks down.

The codes in this repository are a sample of implementation of Azure Kubernetes Services Blue/Green bootstrap & maintenance without adopting DRY. Utilizing Terraform, Flux (v2), and GitHub Actions. The Blue and Green codes are not standardized, but the directories are split. In addition, it also has Terraform states for each environment. You can treat AKS clusters as immutable.

In this strategy, you should not persist data, state, and configuration in a cluster. All of them should be stored outside the cluster and connected for bootstrapping, configuration, running apps, and operation.

<img src="https://raw.githubusercontent.com/ToruMakabe/Images/master/aks-anti-dry.png?raw=true" width="800">

However, the difference of codes between Blue and Green must be easy to see. Therefore, this sample has support steps in CI, such as posting the diff as a comment at the time of Pull Requests.

DRY is a great concept, and you should be aware that it will come true in the future, but I hope this sample will serve as a starting point.

## Prerequisites & Tested <a name = "prerequisites"></a>

* [Terraform](https://www.terraform.io/docs/index.html): 1.0.2
  * hashicorp/azurerm: 2.68
  * hashicorp/kubernetes: 2.3
  * State store: Terraform Cloud
* [Flux(v2)](https://fluxcd.io/docs/): 0.16.1

### Privileges required for execution

* Admin
  * Azure Subscription Owner (Azure role)
    * Need User Access Administrator for role assignment
  * Azure Kubernetes Service Cluster Admin Role (Azure role)
    * For execution of Flux
    * If you are an Azure Subscription Owner, a separate assignment is not required
  * GitHub Repo control (GitHub PAT)
    * For execution of Flux
* GitHub Actions CI (Azure Service Principal)
  * Azure Subscription Reader (Azure role)

In this sample, assigned strong privileges to admin so that you can try it smoothly for your PoC. In your actual operation, please be aware of the least privilege and fine-grained scope for you.

## Usage <a name = "usage"></a>

### Prepare variables

The policy of this sample for variables such as IDs and secrets is as follows.

* Operate in a private repository
* Static IDs like Azure resource IDs can be written in the source code
  * To clarify the operation target and share it with the team as code
  * Code encryption on repo is sometimes overkilling and complex procedures can trigger accidents
* Secrets and values generated without regularity not written in the source code
  * use Secret Store
    * Azure Key Vault and Secret Store CSI Driver
      * Create and inject automatically on this sample (Redis password for sample app)
        * Create secret and [store to Key Vault](https://github.com/ToruMakabe/aks-safe-deploy/blob/08ae26ad813a0c25f641afb5eb54b0c2518f2dc9/terraform/shared/main.tf#L289)
        * [Pass](https://github.com/ToruMakabe/aks-safe-deploy/blob/08ae26ad813a0c25f641afb5eb54b0c2518f2dc9/terraform/blue/main.tf#L399) Azure AD Tenant ID and kubelet Managed ID to AKS as Kubernetes ConfigMap for Secret Store CSI Driver
        * Kustomize [SecretProviderClass](./flux/apps/base/session-checker/secret-provider-class.yaml) manifest [with ConfigMap](./flux/clusters/blue/apps.yaml)
        * Pass Secret to sample app [as environment variable](./flux/apps/base/session-checker/deployment.yaml)
    * GitHub Secret
      * [For CI](https://github.com/ToruMakabe/aks-safe-deploy/blob/08ae26ad813a0c25f641afb5eb54b0c2518f2dc9/.github/workflows/ci-terraform-shared.yaml#L17)
        * TF_API_TOKEN: Token for Terraform Cloud
        * ARM_TENANT_ID: Azure AD Tenant ID
        * ARM_SUBSCRIPTION_ID: Azure Subscription ID
        * ARM_CLIENT_ID: Service Principal Client ID
        * ARM_CLIENT_SECRET: Service Principal Client Secret


You have to prepare the following variables.

* Azure Resources (Shared): [Terraform tfvars](./terraform/shared/sample.tfvars)
* Azure Resources (Blue/Green): [Terraform tfvars](./terraform/blue/sample.tfvars)
* Kubernetes Resources (Blue/Green): [Flux helper script](./flux/scripts/blue/bootstrap.sh)

You can also [use environment variables](https://www.terraform.io/docs/language/values/variables.html) instead of tfvars file.

### Bootstrap order

1. Azure Resources (Shared): [Terraform dir](./terraform/shared)
2. Azure Resources (Blue/Green): [Terraform dir](./terraform/blue)
3. Kubernetes Resources (Blue/Green): [Flux helper script](./flux/scripts/blue/bootstrap.sh)

You can operate Blue/Green independently from step 2, but always be aware of the context of clusters.

### CI

Pull Requests trigger the following GitHub Actions as CI. These actions post the result as comments to the PR.

* diff between Blue/Green Flux files: [Github Actions workflow](./.github/workflows/ci-flux.yaml)
  * PR for files /flux directory
* format/validate/plan Shared Terraform files: [Github Actions workflow](./.github/workflows/ci-terraform-shared.yaml)
  * PR for files /terraform/shared directory
* diff between Blue/Green Terrarform files, and format/validate: [Github Actions workflow](./.github/workflows/ci-terraform-blue.yaml)
  * PR for files /terraform/blue or green directory
  * not run plan
    * To realize the concept of immutable
    * To not assign strong privileges to CI (Azure Kubernetes Service Cluster Admin Role is required to execute plan)

### Switch Blue/Green

You can join/remove services of each cluster to/from backend addresses of Application Gateway by changing Terraform variable ["demoapp_svc_ips"](./terraform/shared/sample.tfvars) and applying it while continuing the service.

This IP address is the Service IP of NGINX Ingress and can be changed [in this code](./flux/infrastructure/blue/nginx-values.yaml).

There are [sample app](https://github.com/ToruMakabe/session-checker) and [test script](./test/scripts/session-check.sh) to help you switch between blue and green and see sessions across the cluster.

If you have both Blue and Green joined in the backend, then:

```
% kubectl cluster-info
Kubernetes control plane is running at https://hoge-aks-anti-dry-green-fuga.hcp.japaneast.azmk8s.io:443
[snip]
% kubectl -n session-checker get po
NAME                               READY   STATUS    RESTARTS   AGE
session-checker-76799c4797-8gq9x   1/1     Running   0          15m
session-checker-76799c4797-r4blx   1/1     Running   0          15m

% kubectl config use-context hoge-aks-anti-dry-blue-admin
Switched to context "hoge-aks-anti-dry-blue-admin".
% kubectl cluster-info
Kubernetes control plane is running at https://hoge-aks-anti-dry-blue-fuga.hcp.japaneast.azmk8s.io:443
[snip]
% kubectl -n session-checker get po
NAME                               READY   STATUS    RESTARTS   AGE
session-checker-76799c4797-kc896   1/1     Running   0          108s
session-checker-76799c4797-wjszz   1/1     Running   0          108s

% ./session-check.sh
{"count":0,"hostname":"session-checker-76799c4797-kc896"}
{"count":1,"hostname":"session-checker-76799c4797-8gq9x"}
{"count":2,"hostname":"session-checker-76799c4797-wjszz"}
{"count":3,"hostname":"session-checker-76799c4797-r4blx"}
{"count":4,"hostname":"session-checker-76799c4797-kc896"}
{"count":5,"hostname":"session-checker-76799c4797-8gq9x"}
```

Requests are distributed across both clusters and multiple pods, but the session is shared by Redis, so it counts correctly.

Then, comment out the Service IP of Blue and apply it.

```
demoapp_svc_ips = {
  # blue  = "10.0.32.4",
  green = "10.0.80.4",
}
```

```
{"count":41,"hostname":"session-checker-76799c4797-wjszz"}
{"count":42,"hostname":"session-checker-76799c4797-r4blx"}
{"count":43,"hostname":"session-checker-76799c4797-kc896"}
{"count":44,"hostname":"session-checker-76799c4797-8gq9x"}
{"count":45,"hostname":"session-checker-76799c4797-r4blx"}
{"count":46,"hostname":"session-checker-76799c4797-8gq9x"}
{"count":47,"hostname":"session-checker-76799c4797-r4blx"}
{"count":48,"hostname":"session-checker-76799c4797-8gq9x"}
{"count":49,"hostname":"session-checker-76799c4797-r4blx"}
{"count":50,"hostname":"session-checker-76799c4797-8gq9x"}
{"count":51,"hostname":"session-checker-76799c4797-r4blx"}
^C
Number of unrecoverable HTTP errors: 0
```

Removed the Service IP of Blue without disruption. So, you can destroy the Blue cluster.

## Notes <a name = "notes"></a>

* Always be aware of the context of which cluster you are currently working on
  * [Visual Studio Code Kubernetes Tools](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-kubernetes-tools)
