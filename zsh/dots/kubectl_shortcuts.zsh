# Kubernetes Shortcuts
# ------------------------------------------------------------------------------

if (( $+commands[kubectl] )); then

  # basic
  alias k='kubectl'
  alias ka='k apply'
  alias kdel='k delete'
  alias kci='kubectl cluster-info'
  alias kapi='kubectl api-resources'
  alias ktno='k top nodes'
  alias ktpo='k top pods'
  alias ktpoc='k top pods --containers'

  # get
  alias kg='k get'

  alias kga='k get all'

  alias kgpo='k get pods'

  alias kgdeploy='k get deployments'

  alias kgns='k get namespaces'

  alias kgno='k get nodes'

  alias kgj='k get jobs'

  alias kging='k get ingresses'

  alias kgcj='k get cronjobs'

  alias kgcm='k get configmaps'

  alias kgsec='k get secrets'

  alias kgsvc='k get services'

  alias kgsa='k get serviceaccounts'

  alias kgev='k get events --sort-by=.metadata.creationTimestamp'

  alias kgpvc='k get persistentvolumeclaims'

  alias kgpv='k get persistentvolumes'

  alias kgrs='k get replicasets'

  alias kgrc='k get replicationcontrollers'

  # describe
  alias kd='k describe'

  alias kdpo='k describe $(k get pods -o name | fzf)'

  alias kddeploy='k describe $(k get deployments -o name | fzf)'

  alias kdns='k describe $(k get namespaces -o name | fzf)'

  alias kdno='k describe $(k get nodes -o name | fzf)'

  alias kdj='k describe $(k get jobs -o name | fzf)'

  alias kding='k describe $(k get ingresses -o name | fzf)'

  alias kdcj='k describe $(k get cronjobs -o name | fzf)'

  alias kdcm='k describe $(k get configmaps -o name | fzf)'

  alias kdsec='k describe $(k get secrets -o name | fzf)'

  alias kdsvc='k describe $(k get services -o name | fzf)'

  alias kdsa='k describe $(k get serviceaccounts -o name | fzf)'

  alias kdep='k describe $(k get endpoints -o name | fzf)'

  alias kdev='k describe $(k get events -o name | fzf)'

  alias kdpvc='k describe $(k get persistentvolumeclaims -o name | fzf)'

  alias kdpv='k describe $(k get events -o persistentvolumes | fzf)'

  alias kdrs='k describe $(k get replicaset -o name | fzf)'

  alias kdrc='k describe $(k get replicationcontrollers -o name | fzf)'

  # get object names for fzf
  alias kgpn='k get pods --output=jsonpath={.items..metadata.name} | tr " " "\n"'

  alias kgcjn='k get cronjobs --output=jsonpath={.items..metadata.name} | tr " " "\n"'

  alias kgcmn='k get cm --output=jsonpath={.items..metadata.name} | tr " " "\n"'

  alias kgsecn='k get secret --output=jsonpath={.items..metadata.name} | tr " " "\n"'

  # delete
  alias kdelpo='k delete pod $(kgpn | fzf)'

  alias kdelcm='k delete cm $(kgcmn | fzf)'

  alias kdelcj='k delete cronjob $(kgcjn | fzf)'

  # edit
  alias kecj='k edit cronjob $(kgcjn | fzf)'

  alias kecm='k edit cm $(kgcmn | fzf)'

  alias kesec='k edit secret $(kgsecn | fzf)'

  # config
  alias kc='kubectl config'

  alias kcuc='kubectl config use-context'

  alias kcgc='kubectl config get-contexts'

  alias kcsc='kubectl config set-context'

  alias kcdc='kubectl config delete-context'

  alias kccc='kubectl config current-context'

  # show logs of selected pod
  kl() {
    if [ -n "$1" ]; then
      kubectl logs --follow $1
    else
      pod=$(kgpn | fzf --exit-0) && kubectl logs --follow $pod
    fi
  }

  klc() {
    if [[ -z "$1" ]] || ; then
      pod=$(kgpn| fzf --exit-0) && kubectl logs --all-containers --follow $pod
    else
      kubectl logs $1 --all-containers --follow
    fi
  }

  # fuzzy pod logs with preview
  alias klz='kgpn | fzf --preview "kubectl logs {}" --no-height'

  # bash into a pod
  alias kexb='k exec -it $(kgpn | fzf --prompt "/bin/bash > ") -- /bin/bash'

  # set the namespace in k8s context
  kname() {
    local k8snamespace=$(kgns --output=jsonpath={.items..metadata.name} |
      tr " " "\n" | fzf)
    if [ -z "${k8snamespace}" ]; then
      printf "${RED}ERROR$RESET: No namespace specified.\n"
      return 1;
    fi
    kubectl config set-context $(kubectl config current-context) \
      --namespace=$k8snamespace
    printf "${GREEN}Namespace$RESET set to "$k8snamespace"\n"
  }

  # port forward
  # Usage: kpf 3000
  kpf(){
    if [ -z "${1}" ]; then
      printf "${RED}ERROR$RESET: No port specified.\n"
      return 1;
    fi;
    kubectl port-forward $(kgpn | fzf --exit-0) $1;
  }

  # execute command inside of pod
  kex(){
    if [ -z "${1}" ]; then
      printf "${RED}ERROR$RESET: No command specified.\n"
      return 1;
    fi;
    kubectl exec -it $(kgpn | fzf --exit-0) $1;
  }

  # port forward all monitoring deployments and open them in default browser
  kprom(){
    nohup $(k port-forward $(kgpn | grep grafana) 3000) > /dev/null 2>&1 &
    nohup $(k port-forward $(kgpn | grep server) 9090) > /dev/null 2>&1 &
    nohup $(k port-forward $(kgpn | grep gateway) 9091) > /dev/null 2>&1 &
    nohup $(k port-forward $(kgpn | grep alertmanager) 9093) > /dev/null 2>&1 &
    sleep 5
    open http://localhost:{3000,9090,9091,9093}
  }

  # run a custom "busybox"
  kbusy(){
    kubectl run -i --tty busybox --image=${1:-busybox} --restart=Never -- sh
  }

  # change k8s cluster context
  changeK8SClusterContext(){
    local k8scontext=$(kubectl config get-contexts -o name | fzf --query="$1")
    if [ -z "${k8scontext}" ]; then
      printf "${RED}ERROR$RESET: No context specified.\n"
      return 1;
    fi;
    kubectl config set-context $k8scontext --namespace=default
    kubectl config use-context $k8scontext
  }

  # change Google Kubernetes Engine
  changeGKE(){
    # gcloud init
    # changeK8SClusterContext
    vared -p " Copy commandline access from gcp web ui?  [y/N]: " -c copy
    copy=${copy:-n}
    if [[ "$copy" =~ ^(y|Y)$ ]]; then
      echo -e "\n\nCopy the command from your gcloud web ui\n\n"
    else
      # read -p "Press any key to choose your region:"
      GCREGION=$(gcloud compute regions list --format="value(name)" | fzf);
      if [ -z "${GCREGION}" ]; then
        printf "${RED}ERROR$RESET: No region specified.\n"
        return 1;
      fi;
      # read -p "Press any key to choose your project:"
      GCPROJECT=$(gcloud projects list --format="value(name)" | fzf)
      if [ -z "${GCPROJECT}" ]; then
        printf "${RED}ERROR$RESET: No project specified.\n"
        return 1;
      fi;
      # read -p "Press any key to choose your cluster:"
      GCCLUSTER=$(gcloud container clusters list --format="value(name)" | fzf)
      if [ -z "${GCCLUSTER}" ]; then
        printf "${RED}ERROR$RESET: No cluster specified.\n"
        return 1;
      fi;
      gcloud beta container clusters get-credentials $GCCLUSTER \
        --region $GCREGION \
        --project $GCPROJECT;
    fi
  }

fi
