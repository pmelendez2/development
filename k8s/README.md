
### How To Install Client Tools

There are a number of useful client tools for interacting with a Kubernetes cluster.  These instructions assume that you are on MacOSX.

Get the client tools and install them onto your local machine. We recommend that you use the `brew` tool for this on a Mac.

Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/), the Kubernetes CLI tool. This tool will allow you to manipulate your Kubernetes cluster.
```
brew install kubernetes-cli
```
Install [helm](https://kubernetes.io/docs/setup/minikube/#quickstart) client, the Kubernetes package manager. This tool will allow  you to install packages on your Kubernetes cluster.
```
brew install kubernetes-helm
```
Install [kail](https://github.com/boz/kail), the Kubernetes log tailer (optional). This tool will allow you to aggregate log messages from various the many sources within Kubernetes.
```
brew tap boz/repo
brew install boz/repo/kail
```
Install [flux](https://github.com/weaveworks/flux) client, the GitOps Kubernetes operator (optional). This tool will allow you to update the Docker images running in your cluster merely by modifying a GitHub repo.
```
brew install fluxctl
```
Install [linkerd](https://linkerd.io/), the service mesh cli tool (optional):
```
brew install linkerd
```

If you will be using an Amazon hosted Kubernetes cluster, then your will want to install two Amazon-specific tools.

Install [aws-iam-authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html), a tool to use AWS IAM credentials to authenticate to a Kubernetes cluster
```
brew install aws-iam-authenticator
```
Install [eksctl](https://eksctl.io/) client, to create Kubernetes clusters on Amazon EKS
```
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl
```


### How to Create a Local Kubernetes Cluster

There are several ways to run Kubernetes on your local machine ([docker desktop](https://rominirani.com/tutorial-getting-started-with-kubernetes-with-docker-on-mac-7f58467203fd), [k3s](https://k3s.io/), [minikube](https://kubernetes.io/docs/setup/minikube/), [kind](https://github.com/kubernetes-sigs/kind), etc.) and several [opinions](https://medium.com/containers-101/local-kubernetes-for-mac-minikube-vs-docker-desktop-f2789b3cad3a) on which is best.  Any one will probably do. 

However, we choose to document minikube because it offers the opportunity to select a particular version of Kubernetes and it runs on all manner of desktops, including MacOSX, Linux, and Windows.

*   Install [minikube](https://github.com/kubernetes/minikube) (see [this excellent tutorial](https://codefresh.io/kubernetes-tutorial/local-kubernetes-mac-minikube-vs-docker-desktop/))
```
brew cask install minikube
```
*   If you are using a Mac, you can install the hyperkit driver vm:

```
brew install docker-machine-driver-hyperkit
sudo chown root:wheel /usr/local/opt/docker-machine-driver-hyperkit/bin/docker-machine-driver-hyperkit
sudo chmod u+s /usr/local/opt/docker-machine-driver-hyperkit/bin/docker-machine-driver-hyperkit
minikube config set vm-driver hyperkit
```
*   Configure minikube (to use the same version of K8s that we will use remotely)
```
minikube config set kubernetes-version v1.11.5
minikube config set memory 8192
minikube config set cpus 4
```
*   Start minikube and modify networking 
```
minikube start --extra-config=apiserver.authorization-mode=RBAC
minikube ssh -- sudo ip link set docker0 promisc on
```
*   Configure CLI tools to talk to your local cluster. In **each and every window** that you will use the Docker cli, you must set environment variables to use the Docker daemon in the minikube VM:
```
eval $(minikube docker-env)
```
*   Stop your cluster
Kubernetes can be a heavy resource consumer.  So, you may want to (non-destructively) stop the virtual machine running your cluster when you are not using it.  You may restart it later with the `minikube start `command above.
```
minikube stop
```

### How to Create Your Own Private Remote K8S Cluster

Here is what you need to know to create your own Kubernetes cluster in the Amazon Cloud (EKS) to use your local client tools to interact with that cluster; and to install the basic services into the cluster.

*   Set up cluster on Amazon - do once for each cluster you want to set up
    *   Create K8s cluster in Amazon EKS using GUI
        *   `eksctl create cluster --auto-kubeconfig --region=us-west-2 --nodes=3`
    *   Save the cluster name in an environment variable for later
        *   <code>export <strong>CLUSTER_NAME</strong>=$(eksctl get cluster --region=us-west-2 -o json | jq ".[0].name" | sed -e "s/\"//g")</code>
    *   Configure the K8s CLI to talk to your cluster
        *   Set <code>KUBECONFIG</code> env variable so that <code>kubectl</code> can manage that new cluster
        *   <code>export KUBECONFIG="~/.kube/eksctl/clusters/${CLUSTER_NAME}"</code>
*   Adjust cluster resources - do when necessary
    *   Scale your nodegroup	
        *   <code>export <strong>NODE_GROUP</strong>=$(eksctl get nodegroup --region=us-west-2 --cluster ${CLUSTER_NAME} -o json| jq '.[0].Name' | sed -e 's/"//g')</code>
        *   <code>eksctl scale nodegroup --region=us-west-2 --cluster ${CLUSTER_NAME} --nodes=4 ${NODE_GROUP}</code>
*   Delete your cluster when done
    *   <code>eksctl delete cluster --name=$(CLUSTER_NAME)</code>

### How to Bootstrap Your Cluster

The tidepool backend requires a small set of basic services to run without your Kubernetes cluster that you must install manually.  

*   Install Tiller, the service-side component of the Helm package manager, create a service account for Tiller, and install the Kubernetes dashboard.
```
kubectl -n kube-system create sa tiller`
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --skip-refresh --upgrade --service-account tiller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml
```

### How to Install the Tidepool Services

You may install the Tidepool service manually into your Kubernetes cluster using the [Helm package manager](https://helm.sh/) with a single command.

#### Manual Update

The Tidepool Kubernetes manifests are created and installed using the helm package manager.  The helm chart for Tidepool is stored in the public GitHub development repo in the _k8s_ branch. at present. You may install it directly into your cluster with this helm command, where `RELEASE_NAME` is a name of your choosing:

```
helm install https://github.com/tidepool-org/development/tree/k8s/k8s/charts/backend --name ${RELEASE_NAME}
```

This will install the tidepool services into the <code>default</code> namespace.

This will install the Tidepool services and the [Ambassador API Gateway](https://www.getambassador.io/) into your cluster. The Docker images used for each tidepool service are listed in the `values.yaml `file. 

To change the Docker images while the cluster is running, first create a local file (`values-override.yaml`) with the image name and tags to change.  Then, upgrade you helm release with the   `helm upgrade` command and provide a set of new values in a local file:

```
helm upgrade ${RELEASE_NAME} https://github.com/tidepool-org/development/tree/k8s/k8s/charts/backend -f values-override.yaml
```

#### GitOps

As an alternative to manually running helm to upgrade your Tidepool services on each change of a Docker image used, you may use the [Weave Flux](https://www.weave.works/oss/flux/) product to watch for new images on Docker Hub.  

Weave Flux does this by reference to a GitHub repo that you provide that stores a copy of the Helm release configurations and any other non-Helm Kubernetes manifest files that you want to run on your Kubernetes cluster. Let's call this your <code>config</code> repo.

The workflow is simple.  

First, you install Weave Flux itself into your Kubernetes cluster.  When you install it, you configure Weave Flux with the URL to the GitHub repo with your Helm release configurations and Kubernetes manifests.  

Then, Weave Flux will poll the `CONFIG_REPO`. It will compare the contents of the config repo with what it has previously installed in your cluster.  If the two have diverged, it was make them identical by changing the Kubernetes resources in your cluster to match what is in your `CONFIG_REPO`.

To do this, first clone the development repo.  We will use this clone as your private `CONFIG_REPO`. 

Then, you can modify your clone as you like and watch how Weave Flux keeps your Kubernetes cluster in sync.

Finally, using helm, install the Weave Flux operator into your cluster:

```
helm repo add weaveworks https://weaveworks.github.io/flux

helm install --name flux --set rbac.create=true --set helmOperator.create=true --set git.url=${CONFIG_REPO} --set git.branch=${YOUR_BRANCH_NAME} --set git.pollInterval=1m --set helmOperator.replicaCount=1 weaveworks/flux
```


N.B. Weave flux will install ALL kubernetes manifests that it discovers in the branch of your` CONFIG_REPO. `It will also look for files with valid` HelmRelease `manifest file and install the helm releases according to the files found.

The `HelmRelease` manifest file for your Tidepool backed is stored at `k8s/release/backend.yaml. `To configure Weave Flux to watch for new Docker images posted to Docker Hub, modify that file`. `See the [Flux documentation](https://github.com/weaveworks/flux) for details.

In order to allow Flux to install new Docker images, Flux will need write access to your Git repo. Your provide that by getting the Flux public key from Flux and adding it to your Git Repo as a "deploy key".  

To retrieve the key, you may use the Flux CLI tool `fluxctl`.

Install [flux](https://github.com/weaveworks/flux) client:
```
brew install fluxctl
```
Get key
```
fluxctl identity
```

Then, open GitHub, navigate to your fork, go to `Setting > Deploy` keys click on `Add deploy key,` check` Allow write access`, paste the Flux public key and click `Add key`.

### How To Access the Tidepool Services

Once you have installed the Tidepool services in your cluster, they will start and run.  To access the Tidepool Web portal, you need to forward a local port to the port that provides the Tidepool Web application:

```
kubectl port-forward svc/blip 3000:3000 &
```
Open` localhost:3000`

At present, you must also forward traffic from the API Gateway to the Tidepool backend.` `_This is needed to inform the Tidepool web app where the Tidepool API server is located. The default config is localhost.  In production, this would be replaced with the DNS name of the Api server.  Now, we just manually forward to the internal service.

```
kubectl port-forward deployment/default-ambassador 8009 &
```


### How to Inspect Your Cluster

There are several ways to inspect what is happening inside your cluster.  Foremost is inspecting the Kubernetes dashboard that you installed above.  From the dashboard, you may inspect the logs of any running Kubernetes.  You may also inspect the logs from the command line.

There are a number of other optional services that you may choose to run in your cluster, including [Istio](https://istio.io/) (service mesh), [Prometheus](https://prometheus.io/) (metrics), [Grafana](https://grafana.com/) (analytics and monitoring), [Kiali](https://www.kiali.io/) (service mesh observability), and Jaeger (distributed tracing).  Each offers its own web interface.  Follow the instructions below to inspect those services.



*   Web Services \
Given private access (`kubectl`) to a Kubernetes cluster, you may look at Kubernetes web services by forwarding the port of a service to a local port.
    *   Ambassador Admin Console in browse
        *   `kubectl port-forward deployment/ambassador 8877 &`
        *   Open<code> [http://localhost:8877/ambassador/v0/diag/](http://localhost:8877/ambassador/v0/diag/)</code>
    *   Kubernetes Dashboard
        *   <code>kubectl proxy</code>
        *   Get token to authenticate
            *   <code>SECRET_NAME=$(kubectl get serviceaccount default -n kube-system -o jsonpath='{.secrets[].name}')</code>
            *   <code>kubectl get secret ${SECRET_NAME} -o jsonpath='{.data.token}' -n kube-system | base64 -D</code>
        *   Open<code> [http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login](http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login) </code>
    *   [Service Graph](https://istio.io/docs/tasks/telemetry/servicegraph/) (if installed)
        *   <code>kubectl port-forward -n istio-system svc/servicegraph 8088:8088 &</code>
        *   Open<code> [http://localhost:8088/force/forcegraph.html](http://localhost:8088/force/forcegraph.html) </code>
    *   [Kiali](https://www.kiali.io/) (if installed)
        *   <code>kubectl port-forward -n istio-system svc/kiali 20001:20001 &</code>
        *   Open<code> [http://localhost:20001/kiali](http://localhost:20001/kiali)</code>
    *   [Prometheus](https://istio.io/docs/tasks/telemetry/querying-metrics/) (if installed)
        *   <code>kubectl port-forward -n istio-system svc/prometheus 9090:9090 &</code>
        *   Open<code> [http://localhost:9090/graph](http://localhost:9090/graph) </code>
    *   [Jaeger](https://istio.io/docs/tasks/telemetry/distributed-tracing/)  (if installed)
        *   <code>kubectl port-forward -n istio-system svc/jaeger 16686:16686 &</code>
        *   Open<code> [http://localhost:16686](http://localhost:16686/)</code>
*   Logs
    *   All services
        *   <code>kail</code>
    *   All services in the default namespace
        *   <code>kail -n default </code>
    *   Tidepool Web
        *   <code>kail --svc blip</code>
    *   Istio (if installed)
        *   <code>kail -n istio-system</code>
    *   Tiller
        *   <code>kail -n kube-system --svc tiller</code>
*   GitOps
    *   Set what version of Tidepool containers are deployed
        *   <code>fluxctl list-controllers -n dev</code>
    *   See what images are available to deploy
        *   <code>fluxctl list-images</code>