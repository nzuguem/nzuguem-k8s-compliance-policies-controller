default: help

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

generate-certificate-for-dev: ## Generate certificate for development properties
	@./k8s/generate-and-set-ca-bundle.sh "host.minikube.internal" "src/main/resources" "external"

deploy-external-webhook-configuration-for-dev: undeploy-internal-webhook-configuration ## Deploy webhook configuration, who bind on local application in development
	@kubectl apply -f k8s/nzuguem-k8s-compliance-policies-validating-external.yml
	@kubectl apply -f k8s/nzuguem-k8s-compliance-policies-mutating-external.yml

undeploy-external-webhook-configuration-for-dev: ## Undeploy webhook configuration, who bind on local application in development
	@kubectl delete -f k8s/nzuguem-k8s-compliance-policies-validating-external.yml || echo
	@kubectl delete -f k8s/nzuguem-k8s-compliance-policies-mutating-external.yml || echo

create-ns-on-minikube-for-test: ## Create and label the namespace containing test resources
	@kubectl get ns | grep  -q "^game" || kubectl create ns game
	@kubectl label ns/game mutating-webhook=enabled validating-webhook=enabled --overwrite=true

delete-ns-on-minikube-from-test: ## Delete namespace containing test resources
	@kubectl delete ns/game --force --grace-period 0

run-local-controller: ## Run webhook controller on local (NOT on cluster kubernetes)
	@./mvnw quarkus:dev

dry-run-good-manifest: ## Apply & Test good manifest
	@kubectl apply -f src/test/resources/deploy/game-2048-good.yml --dry-run=server

dry-run-bad-labels-manifest: ## Apply & Test bad manifest (labels missing)
	@kubectl apply -f src/test/resources/deploy/game-2048-bad-labels.yml --dry-run=server

dry-run-bad-image-manifest: ## Apply & Test bad manifest (image wrong)
	@kubectl apply -f src/test/resources/deploy/game-2048-bad-image.yml --dry-run=server

dry-run-bad-labels-and-image-manifest: ## Apply & Test bad manifest (labels missing and image wrong)
	@kubectl apply -f src/test/resources/deploy/game-2048-bad-labels-and-image.yml --dry-run=server


undeploy-internal-webhook-configuration: ## Undeploy webhook configuration, the one that bind to the kubernetes service
	@kubectl delete -f k8s/nzuguem-k8s-compliance-policies-validating-internal.yml || echo
	@kubectl delete -f k8s/nzuguem-k8s-compliance-policies-mutating-internal.yml || echo

deploy-internal-webhook-configuration: undeploy-external-webhook-configuration-for-dev ## Deploy webhook configuration, the one that bind to the kubernetes service
	@kubectl apply -f k8s/nzuguem-k8s-compliance-policies-validating-internal.yml
	@kubectl apply -f k8s/nzuguem-k8s-compliance-policies-mutating-internal.yml

generate-certificate-on-minikube-for-deploy-controller: ## Generate & Create secret for controller on minikube
	@./k8s/generate-and-set-ca-bundle.sh "nzuguem-k8s-compliance-policies-controller.compliance-policies-system.svc" "." "internal"
	@kubectl get ns | grep  -q "^compliance-policies-system" || kubectl create ns compliance-policies-system
	@kubectl create secret tls nzuguem-k8s-compliance-policies-controller-secret --key nzuguem-compliance-policies-controller.key \
            --cert nzuguem-compliance-policies-controller.crt -n compliance-policies-system

delete-ns-on-minikube-from-deploy-controller: undeploy-controller-from-minikube ## Delete namespace containing all controller ressources
	@kubectl delete -n compliance-policies-system secret/nzuguem-k8s-compliance-policies-controller-secret || echo
	@kubectl delete ns/compliance-policies-system --force --grace-period 0 || echo

build-image-generate-manifests-for-deploy-controller: ## Build docker image and generate kubernetes manifests for controller
	@eval $$(minikube -p minikube docker-env) ;\
	./mvnw clean package -Dquarkus.container-image.build=true

deploy-controller-on-minikube: ## Deploy controller on minikube
	@kubectl apply -f target/kubernetes/minikube.yml

logs-controller-on-minikube: ## Following logs of controller on minikube
	@kubectl logs -f -n compliance-policies-system deploy/nzuguem-k8s-compliance-policies-controller

undeploy-controller-from-minikube: ## Undeploy controller from minikube
	@kubectl delete -f target/kubernetes/minikube.yml || echo

delete-image-docker-of-controller:
	@eval $$(minikube -p minikube docker-env) ;\
	docker rmi -f ${USER}/nzuguem-k8s-compliance-policies-controller:1.0.0

