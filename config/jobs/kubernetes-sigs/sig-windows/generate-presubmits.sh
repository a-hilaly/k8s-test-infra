#!/usr/bin/env bash
# Copyright 2021 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

dir="$(dirname "${BASH_SOURCE[0]}")"

generate_presubmit_annotations() {
  branch="${1}"
  # only display on presubmit jobs for master branch for now since
  # a dashboard cannot have multiple tabs with the same name
  if [[ "${branch}" != "master" ]]; then
    return
  fi
  job_name="${2}"
  cat << EOF
    annotations:
      testgrid-dashboards: sig-windows-presubmit
      testgrid-tab-name: ${job_name}
      testgrid-num-columns-recent: '30'
EOF
}

# we need to define the full image URL so it can be autobumped
tmp="gcr.io/k8s-testimages/kubekins-e2e:v20210622-762366a-master"
kubekins_e2e_image="${tmp/\-master/}"

readonly ginkgo_focus="\[Conformance\]|\[NodeConformance\]|\[sig-windows\]|\[sig-apps\].CronJob|\[sig-api-machinery\].ResourceQuota|\[sig-network\].EndpointSlice"
readonly ginkgo_skip="\[LinuxOnly\]|\[Serial\]|\[Slow\]|\[alpha\]|GMSA|Guestbook.application.should.create.and.stop.a.working.application|device.plugin.for.Windows"

for release in "$@"; do
  output="${dir}/release-${release}-windows-presubmits.yaml"
  orchestrator_release="${release}"
  branch="release-${release}"
  dockershim_api_model="https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/job-templates/kubernetes_release_staging.json"
  containerd_api_model="https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/job-templates/kubernetes_containerd_master.json"

  case ${release} in
    1.18)
      dockershim_api_model="https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/job-templates/kubernetes_release_1_18.json"
      ;;
    1.19)
      dockershim_api_model="https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/job-templates/kubernetes_release_1_19.json"
      containerd_api_model="https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/job-templates/kubernetes_containerd_1_19.json"
      ;;
    1.20)
      dockershim_api_model="https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/job-templates/kubernetes_release_1_20.json"
      containerd_api_model="https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/job-templates/kubernetes_containerd_1_20.json"
      ;;
    1.21)
      dockershim_api_model="https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/job-templates/kubernetes_release_1_21.json"
      containerd_api_model="https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/job-templates/kubernetes_containerd_1_21.json"
      ;;
    *)
      branch="master"
      orchestrator_release="1.22"
      ;;
  esac

  cat > "${output}" <<EOF
# generated by ./config/jobs/kubernetes-sigs/sig-windows/generate-presubmits.sh.
presubmits:
  kubernetes/kubernetes:
  - name: pull-kubernetes-e2e-aks-engine-windows-dockershim
    always_run: false
    optional: true
    decorate: true
    decoration_config:
      timeout: 3h
    path_alias: k8s.io/kubernetes
    branches:
    - ${branch}
    labels:
      preset-service-account: "true"
      preset-azure-cred: "true"
      preset-azure-windows: "true"
      preset-windows-repo-list-master: "true"
      preset-k8s-ssh: "true"
      preset-dind-enabled: "true"
      preset-windows-private-registry-cred: "true"
    spec:
      containers:
      - image: ${kubekins_e2e_image}-${release}
        command:
        - runner.sh
        - kubetest
        args:
        # Generic e2e test args
        - --test
        - --up
        - --down
        - --build=quick
        - --dump=\$(ARTIFACTS)
        # Azure-specific test args
        - --deployment=aksengine
        - --provider=skeleton
        - --aksengine-admin-username=azureuser
        - --aksengine-admin-password=AdminPassw0rd
        - --aksengine-creds=\$(AZURE_CREDENTIALS)
        - --aksengine-download-url=https://aka.ms/aks-engine/aks-engine-k8s-e2e.tar.gz
        - --aksengine-public-key=\$(K8S_SSH_PUBLIC_KEY_PATH)
        - --aksengine-private-key=\$(K8S_SSH_PRIVATE_KEY_PATH)
        - --aksengine-winZipBuildScript=\$(WIN_BUILD)
        - --aksengine-orchestratorRelease=${orchestrator_release}
        - --aksengine-template-url=${dockershim_api_model}
        - --aksengine-win-binaries
        - --aksengine-deploy-custom-k8s
        - --aksengine-agentpoolcount=2
        # Specific test args
        - --test_args=--node-os-distro=windows --docker-config-file=\$(DOCKER_CONFIG_FILE) --ginkgo.focus=${ginkgo_focus} --ginkgo.skip=${ginkgo_skip}
        - --ginkgo-parallel=4
        securityContext:
          privileged: true
$(generate_presubmit_annotations ${branch} pull-kubernetes-e2e-aks-engine-windows-dockershim)
  - name: pull-kubernetes-e2e-aks-engine-windows-containerd
    always_run: false
    optional: true
    run_if_changed: 'azure.*\.go$|.*windows\.go$|test/e2e/windows/.*'
    decorate: true
    decoration_config:
      timeout: 3h
    path_alias: k8s.io/kubernetes
    branches:
    - ${branch}
    labels:
      preset-service-account: "true"
      preset-azure-cred: "true"
      preset-azure-windows: "true"
      preset-windows-repo-list-master: "true"
      preset-k8s-ssh: "true"
      preset-dind-enabled: "true"
      preset-windows-private-registry-cred: "true"
    spec:
      containers:
      - image: ${kubekins_e2e_image}-${release}
        command:
        - runner.sh
        - kubetest
        args:
        # Generic e2e test args
        - --test
        - --up
        - --down
        - --build=quick
        - --dump=\$(ARTIFACTS)
        # Azure-specific test args
        - --deployment=aksengine
        - --provider=skeleton
        - --aksengine-admin-username=azureuser
        - --aksengine-admin-password=AdminPassw0rd
        - --aksengine-creds=\$(AZURE_CREDENTIALS)
        - --aksengine-download-url=https://aka.ms/aks-engine/aks-engine-k8s-e2e.tar.gz
        - --aksengine-public-key=\$(K8S_SSH_PUBLIC_KEY_PATH)
        - --aksengine-private-key=\$(K8S_SSH_PRIVATE_KEY_PATH)
        - --aksengine-winZipBuildScript=\$(WIN_BUILD)
        - --aksengine-orchestratorRelease=${orchestrator_release}
        - --aksengine-template-url=${containerd_api_model}
        - --aksengine-win-binaries
        - --aksengine-deploy-custom-k8s
        - --aksengine-agentpoolcount=2
        # Specific test args
        - --test_args=--node-os-distro=windows --docker-config-file=\$(DOCKER_CONFIG_FILE) --ginkgo.focus=${ginkgo_focus} --ginkgo.skip=${ginkgo_skip}
        - --ginkgo-parallel=4
        securityContext:
          privileged: true
$(generate_presubmit_annotations ${branch} pull-kubernetes-e2e-aks-engine-windows-containerd)
  - name: pull-kubernetes-e2e-aks-engine-azure-disk-windows-dockershim
    decorate: true
    decoration_config:
      timeout: 2h
    always_run: false
    optional: true
    run_if_changed: 'azure.*\.go$'
    path_alias: k8s.io/kubernetes
    branches:
    - ${branch}
    labels:
      preset-service-account: "true"
      preset-azure-cred: "true"
      preset-azure-windows: "true"
      preset-k8s-ssh: "true"
      preset-dind-enabled: "true"
    extra_refs:
    - org: kubernetes-sigs
      repo: azuredisk-csi-driver
      base_ref: master
      path_alias: sigs.k8s.io/azuredisk-csi-driver
    spec:
      containers:
      - image: ${kubekins_e2e_image}-${release}
        command:
        - runner.sh
        - kubetest
        args:
        # Generic e2e test args
        - --test
        - --up
        - --down
        - --build=quick
        - --dump=\$(ARTIFACTS)
        # Azure-specific test args
        - --deployment=aksengine
        - --provider=skeleton
        - --aksengine-admin-username=azureuser
        - --aksengine-admin-password=AdminPassw0rd
        - --aksengine-creds=\$(AZURE_CREDENTIALS)
        - --aksengine-download-url=https://aka.ms/aks-engine/aks-engine-k8s-e2e.tar.gz
        - --aksengine-public-key=\$(K8S_SSH_PUBLIC_KEY_PATH)
        - --aksengine-private-key=\$(K8S_SSH_PRIVATE_KEY_PATH)
        - --aksengine-winZipBuildScript=\$(WIN_BUILD)
        - --aksengine-orchestratorRelease=${orchestrator_release}
        - --aksengine-template-url=https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/job-templates/kubernetes_in_tree_volume_plugins.json
        - --aksengine-win-binaries
        - --aksengine-deploy-custom-k8s
        - --aksengine-agentpoolcount=2
        # Specific test args
        - --test-azure-disk-csi-driver
        securityContext:
          privileged: true
        env:
        - name: AZURE_STORAGE_DRIVER
          value: kubernetes.io/azure-disk # In-tree Azure disk storage class
        - name: TEST_WINDOWS
          value: "true"
$(generate_presubmit_annotations ${branch} pull-kubernetes-e2e-aks-engine-azure-disk-windows-dockershim)
  - name: pull-kubernetes-e2e-aks-engine-azure-file-windows-dockershim
    decorate: true
    decoration_config:
      timeout: 2h
    always_run: false
    optional: true
    run_if_changed: 'azure.*\.go$'
    path_alias: k8s.io/kubernetes
    branches:
    - ${branch}
    labels:
      preset-service-account: "true"
      preset-azure-cred: "true"
      preset-azure-windows: "true"
      preset-k8s-ssh: "true"
      preset-dind-enabled: "true"
    extra_refs:
    - org: kubernetes-sigs
      repo: azurefile-csi-driver
      base_ref: master
      path_alias: sigs.k8s.io/azurefile-csi-driver
    spec:
      containers:
      - image: gcr.io/k8s-testimages/kubekins-e2e:v20210622-762366a-master
        command:
        - runner.sh
        - kubetest
        args:
        # Generic e2e test args
        - --test
        - --up
        - --down
        - --build=quick
        - --dump=\$(ARTIFACTS)
        # Azure-specific test args
        - --deployment=aksengine
        - --provider=skeleton
        - --aksengine-admin-username=azureuser
        - --aksengine-admin-password=AdminPassw0rd
        - --aksengine-creds=\$(AZURE_CREDENTIALS)
        - --aksengine-download-url=https://aka.ms/aks-engine/aks-engine-k8s-e2e.tar.gz
        - --aksengine-public-key=\$(K8S_SSH_PUBLIC_KEY_PATH)
        - --aksengine-private-key=\$(K8S_SSH_PRIVATE_KEY_PATH)
        - --aksengine-winZipBuildScript=\$(WIN_BUILD)
        - --aksengine-orchestratorRelease=${orchestrator_release}
        - --aksengine-template-url=https://raw.githubusercontent.com/kubernetes-sigs/windows-testing/master/job-templates/kubernetes_in_tree_volume_plugins.json
        - --aksengine-win-binaries
        - --aksengine-deploy-custom-k8s
        - --aksengine-agentpoolcount=2
        # Specific test args
        - --test-azure-file-csi-driver
        securityContext:
          privileged: true
        env:
        - name: AZURE_STORAGE_DRIVER
          value: kubernetes.io/azure-file # In-tree Azure file storage class
        - name: TEST_WINDOWS
          value: "true"
$(generate_presubmit_annotations ${branch} pull-kubernetes-e2e-aks-engine-azure-file-windows-dockershim)
EOF
done
