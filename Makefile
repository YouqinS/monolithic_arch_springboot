IMAGE:=mono-bs
TAG:=v1
IMAGE_TAGGED:=$(IMAGE):$(TAG)

help:
	@echo 'Targets'
	@echo '   install-mysql                 - deploy HELM chart for mysql'
	@echo '                                    user: root'
	@echo '                                    MYSQL_ROOT_PASSWORD=$$(kubectl get secret --namespace default my-release-mysql -o jsonpath="{.data.mysql-root-password}" | base64 -d)'
	@echo '                                    hostname: my-release-mysql.default.svc.cluster.local '
	@echo '   install-bs                    - deploy HELM chart for monolithic bookstore'
	@echo '   image                         - create docker image and upload it to minikube container registry'
	@echo '   configmap                     - create configmap to pass DB info to the application (set them in values.yaml -> configmap -> app) '
	@echo '   locust-configmap              - create 2 configmaps based /locust/main.py and locust/lib . Will be stored in /locust/helm'



install-mysql:
	minikube ssh docker pull docker.io/bitnami/mysql:8.0.36-debian-12-r8
	helm install my-release oci://registry-1.docker.io/bitnamicharts/mysql


install-bs:
	cd helm && helm package mono-bs
	cd helm && helm install  --generate-name  mono-bs --set image.pullPolicy=Never  --set image.repository=my-local/mono-bs --set image.tag=v1 --set db.username=root  --set db.password=O4AhJYCYYh --set db.url="jdbc:mysql://my-release-mysql.default.svc.cluster.local:3306/bookstore?useUnicode=true&characterEncoding=utf-8"  --set db.host=my-release-mysql.default.svc.cluster.local   --set db.database=bookstore  --set db.jobDbCreation.image="bitnami/mysql:8.0.36-debian-12-r8"  --set db.jobDbCreation.pullPolicy=Never


uninstall-bs:
	helm delete $(NAME)

image:
    # https://github.com/kubernetes/minikube/issues/18021
	docker build -t my-local/mono-bs:v1 .
	docker image save -o image.tar my-local/mono-bs:v1
	minikube image load image.tar
	rm -f image.tar
	#minikube image load my-local/mono-bs:v1

start:
	mvn spring-boot:run -Dspring-boot.run.profiles=mysql

curl:
	kubectl run mycurlpod --image=curlimages/curl -i --tty -- sh

configmap:
	cd helm/mono-bs/template && kubectl create configmap myConfigmap --from-literal=spring.datasource.url="myurl"  --from-literal=spring.datasource.username="myusername"  --from-literal=spring.datasource.password="mypw" --dry-run=client -o yaml > configmap.yaml

drop-schema:
	mysql -h "my-release-mysql.default.svc.cluster.local " -u"root" -p"O4AhJYCYYh" -e"DROP DATABASE bookstore ;"


locust-configmap:
	cd locust/helm && kubectl create configmap my-loadtest-locustfile --from-file ../main.py  --dry-run=client -o yaml > my-loadtest-locustfile.yaml
	cd locust/helm && kubectl create configmap my-loadtest-lib --from-file ../lib/ --dry-run=client -o yaml >  my-loadtest-lib.yaml

install-locust-configmap:
	kubectl apply -f locust/helm/my-loadtest-locustfile.yaml
	kubectl apply -f locust/helm/my-loadtest-lib.yaml


delete-locust-configmap:
	kubectl delete -f locust/helm/my-loadtest-locustfile.yaml
	kubectl delete -f locust/helm/my-loadtest-lib.yaml

install-locust:
	helm install deliveryhero/locust  --generate-name --set service.type=NodePort --set loadtest.name=my-loadtest  --set loadtest.locust_locustfile_configmap=my-loadtest-locustfile --set loadtest.locust_lib_configmap=my-loadtest-lib
