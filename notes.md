test first locally on a pc before deploying to GCP

# create db: mysql or maria db
- download docker image mysql: https://hub.docker.com/_/mysql


download docker image and run it:

$ docker run --name some-mysql -e MYSQL_ROOT_PASSWORD=my-secret-pw -d mysql:tag
-name: (some-mysql) the name you want to assign to your container,
-e: (my-secret-pw) the password to be set for the MySQL root user,
-d: run image in background
mysql: name of image to download and run
tag is the tag specifying the MySQL version you want. See the list above for relevant tags.

$ `docker run --name mysql -e MYSQL_ROOT_PASSWORD=my-secret-pw -d mysql`
$ `docker run --name mysql -e MYSQL_ROOT_PASSWORD=my-secret-pw  -p 3307:3306 -d mysql` (port 3306 is used, use another port 3307)

to see running containers:
youqin@youqin-Latitude-7490:~$ docker ps
CONTAINER ID   IMAGE     COMMAND                  CREATED         STATUS         PORTS                 NAMES
d0fdfeef7c45   mysql     "docker-entrypoint.s…"   3 minutes ago   Up 3 minutes   3306/tcp, 33060/tcp   mysql


to enter the container:
`docker exec -it mysql  sh`

to login as user root:
`mysql -u root -p`

to create a database:
`CREATE DATABASE bookstore;`

to create a user:
CREATE USER 'sammy'@'localhost' IDENTIFIED BY 'password';

to grant rights for user sammy:
GRANT CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, SELECT, REFERENCES, RELOAD on *.* TO 'sammy'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;

# configure app to use the db
update url, username and password in src/main/resources/application-mysql.yml
url: "jdbc:mysql://localhost:3307/bookstore?useUnicode=true&characterEncoding=utf-8" or url: "jdbc:mysql://127.0.0.1:3307/bookstore?useUnicode=true&characterEncoding=utf-8"
mysql: db container name
localhost(127.0.0.1): ip where db is running
3307: port to access db
bookstore: database name

run app with latest update:
`mvn spring-boot:run -Dspring-boot.run.profiles=mysql`

or compile and then run:
`mvn package`
`java -jar target/bookstore-monolithic-springboot-1.0.0-SNAPSHOT.jar --spring.profiles.active=mysql`

# create a schema for app, and then add table to the schema
- to create schema: https://dev.mysql.com/doc/refman/8.0/en/create-database.html [stage is before app is started]
- configure app to use Liquibase to create tables and insert data when the app is started
  - install Liquibase https://docs.liquibase.com/start/install/liquibase-linux-debian-ubuntu.html 

liquibase init project --format=xml --project-defaults-file=liquibase.properties --username=root --password=my-secret-pw --url="jdbc:mysql://localhost:3307/bookstore?useUnicode=true&characterEncoding=utf-8"
https://docs.liquibase.com/start/tutorials/mysql.html#:~:text=To%20use%20Liquibase%20and%20MySQL,xml%20file.
sudo cp /home/youqin/Downloads/mysql-connector-j-8.3.0.jar /usr/bin/lib
cd ~/Downloads/CSM_HU/_thesis/projects/bookstore/liquibase
liquibase generate-changelog --changelog-file=bookstore-changelog.xml
liquibase generate-changelog --changelog-file=bookstore-changelog-02.xml --diff-types=data


  - https://www.baeldung.com/liquibase-refactor-schema-of-java-app
  - https://docs.liquibase.com/concepts/home.html

- to create tables: Liquibase scripts. Liquibase is an open-source database-independent library for tracking, managing and applying database schema changes. https://www.liquibase.org/get-started/quickstart [stage is when app is started]
- to insert data : liquibase scripts [stage is when app is started]


# to test locally
- install helm
- create helm chart
  (DO NOT USE _ IN THE NAME BECAUSE IT IS FORBIDDEN, instead use - or . :  mono_bs -> mono-bs)
  youqin@youqin-Latitude-7490:~/Downloads/CSM_HU/_thesis/projects/bookstore/monolithic_arch_springboot/helm$ helm create mono-bs
  Creating mono-bs
- create docker image: create a Dockerfile if not done, docker build :youqin@youqin-Latitude-7490:~/Downloads/CSM_HU/_thesis/projects/bookstore/monolithic_arch_springboot$ docker build -t mono-bs .
- install kubernetes on PC (minikube)

- install db on kubernetes cluster : mysql helmchart: https://bitnami.com/stack/mysql/helm
  helm install my-release oci://registry-1.docker.io/bitnamicharts/mysql
  echo Primary: my-release-mysql.default.svc.cluster.local:3306
  Execute the following to get the administrator credentials:
  echo Username: root
  MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace default my-release-mysql -o jsonpath="{.data.mysql-root-password}" | base64 -d)
  To connect to your database:
  1. Run a pod that you can use as a client:
     kubectl run my-release-mysql-client --rm --tty -i --restart='Never' --image  docker.io/bitnami/mysql:8.0.36-debian-12-r8 --namespace default --env MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD --command -- bash
  2. To connect to primary service (read/write):
     mysql -h my-release-mysql.default.svc.cluster.local -uroot -p"$MYSQL_ROOT_PASSWORD"

 PB: deployment failed because image couldn't be pulled from docker registry (not enough time, timeout: Failed to pull image "docker.io/bitnami/mysql:8.0.36-debian-12-r8": rpc error: code = Canceled desc = context canceled)
 SOLUTION: minikube ssh docker pull docker.io/bitnami/mysql:8.0.36-debian-12-r8
           (beforehand did : docker pull docker.io/bitnami/mysql:8.0.36-debian-12-r8 )

- install app on kubernetes
   need to upload the image on the local docker registry to the minikube container registry otherwise image won't be able to be pulled: minikube image load mono-bs.tar (coz error with docker version 25)
   configure Helm chart:
     - db url+user+pw: because pod will crash if it cannot connect to database --> create a configmap which gets url/pw/name from values.yaml and pass them to application as environment variables.

- install locust on kubernetes cluster: https://github.com/deliveryhero/helm-charts/tree/master/stable/locust
  - helm repo add deliveryhero https://charts.deliveryhero.io/

  - specify own main test script to run: take configmap "example-locustfile " file main.py and mount it to /mnt/locust  and then use environemnt variable: LOCUST_LOCUSTFILE to point to it
  - specify libraries used by main test: take configmap "example-lib" and mount it to /mnt/locust/lib
  
   IT IS POSSIBLE TO SWITCH THESE 2 CONFIGMAPS which contains test script and supporting libraries with you own configmap which you contains your own testing script (bookstore test script):"
   1) create the configmaps:
      - create directory locust/lib, create _init_.py and example_functions.py (for locust test cases)
      - `kubectl create configmap my-loadtest-locustfile --from-file path/to/your/main.py`
      - `kubectl create configmap my-loadtest-lib --from-file path/to/your/lib/`
   2) tell the locust helm chart to use your configmaps from step 1)
      `helm install deliveryhero/locust  --generate-name --set service.type=NodePort --set loadtest.name=my-loadtest  --set loadtest.locust_locustfile_configmap=my-loadtest-locustfile --set loadtest.locust_lib_configmap=my-loadtest-lib`
      
- run manual tests to verify app is accessible (browser)
  - check the external ULR of locust: youqin@youqin-Latitude-7490:~$ `minikube service --all`
  |-----------|------------|-------------|--------------|
  | NAMESPACE |    NAME    | TARGET PORT |     URL      |
  |-----------|------------|-------------|--------------|
  | default   | kubernetes |             | No node port |
  |-----------|------------|-------------|--------------|
  😿  service default/kubernetes has no node port
  |-----------|-------------------|----------------|---------------------------|
  | NAMESPACE |       NAME        |  TARGET PORT   |            URL            |
  |-----------|-------------------|----------------|---------------------------|
  | default   | locust-1708882959 | master-p1/5557 | http://192.168.49.2:32368 |
  |           |                   | master-p2/5558 | http://192.168.49.2:31544 |
  |           |                   | master-p3/8089 | http://192.168.49.2:31336 |
  |-----------|-------------------|----------------|---------------------------|
  - open http://192.168.49.2:31336 with browser (not all 3 external URLs work)
  - specify app IP to test: 
    - youqin@youqin-Latitude-7490:~$ `kubectl get svc`
      NAME                        TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                                        AGE
      kubernetes                  ClusterIP   10.96.0.1      <none>        443/TCP                                        58d
      locust-1708882959           NodePort    10.108.52.76   <none>        5557:32368/TCP,5558:31544/TCP,8089:31336/TCP   75s
      mono-bs-1708822033          ClusterIP   10.96.126.16   <none>        80/TCP                                         16h
      my-release-mysql            ClusterIP   10.106.72.25   <none>        3306/TCP                                       20h
      my-release-mysql-headless   ClusterIP   None           <none>        3306/TCP                                       20h
    - http://10.96.126.16:80


# to prepare for cloud deployment
- create jar file with `mvn package`
- create docker image
- create helm chart


push docker image to dockerhub
youqin@youqin-Latitude-7490:~/Downloads/CSM_HU/_thesis/projects/bookstore/monolithic_arch_springboot$ docker login -u xiaoouit
Password: (BBvv2623)
WARNING! Your password will be stored unencrypted in /home/youqin/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded



# load testing
- install Locust in kubernets
  https://docs.locust.io/en/stable/installation.html
  https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

- configure Locust for load testing (specify how many nodes, ports....)
- run load testing: write test cases (for different endpoints)

# test cases/scenarios:
- one instance - load testing and collect results (CPU, memory, responsiveness)
- scale (two instances?) - repeat the same tests




