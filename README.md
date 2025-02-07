# khiops-docker

Khiops v10.3.0 is available as a docker container, with packaged dependencies.

## Base images

Two versions are proposed to simplify the integration of khiops:
 - [khiopsml/khiops-ubuntu](https://hub.docker.com/r/khiopsml/khiops-ubuntu): a minimal installation of khiops on ubuntu
 - [khiopsml/khiops-python](https://hub.docker.com/r/khiopsml/khiops-python): the same with khiops-python preinstalled

## Basic usage

By default (with no arguments), the docker image is configured to launch a khiops service.
If a single operation is desired, the chosen command must be specified. Alternatively,
if interactive mode is desired, the "bash" command can be run instead.

The following will run the specified scenario file found in the local directory.

```console
docker run -v $PWD:/my_data \
  -it khiopsml/khiops-ubuntu
  khiops -b -i /my_data/my_scenario.kh
```

Similarily, the python image can be used to launch a khiops-python script in the current directory.

```console
docker run -v $PWD:/my_volume \
  -it khiopsml/khiops-python
  python /my_volume/script.py
```

## Service usage
With no arguments, the container will start a Khiops service available for processing a series of scenarii without having to relaunch the container.

```console
docker run -v $PWD:/my_data -p 11000:11000 \
  -it khiopsml/khiops-ubuntu
```

A request to process a scenario can then be submitted by sending a message
at a REST endpoint using standard HTTP tools (cURL, wget, postman...)

```console
curl -k -X POST -d "{\"scenario\": \"/my_data/my_scenario.kh\"}" "https://localhost:11000/v1/batch" \
 -H "accept: application/json"
```

The API definition is served at https://localhost:11000.

Under the hood, the Khiops container will run the corresponding "khiops -b -i ..." command.



## Distributed usage

Khiops being a MPI-based program, it can be run distributed on multiple machines. In this section we present how to run a distributed execution on a k8s cluster. The good news about this is that the same container can be used.

### Prerequisites

To run distributed on top of k8s, we rely on the [MPI Operator](https://github.com/kubeflow/mpi-operator) to handle the provisioning of the worker nodes.

### Job definition

Once the MPI Operator is installed in the k8s cluster, it is possible to specify a MPI Job to be run with the desired code and the chosen amount of resources.

For example:

```
apiVersion: kubeflow.org/v2beta1
kind: MPIJob
metadata:
  name: khiops
spec:
  slotsPerWorker: 4
  runPolicy:
    cleanPodPolicy: Running
    ttlSecondsAfterFinished: 3600
  sshAuthMountPath: /home/ubuntu/.ssh
  mpiReplicaSpecs:
    Launcher:
      replicas: 1
      template:
        spec:
          containers:
          - image: khiopsml/khiops-ubuntu
            name: mpi-launcher
            securityContext:
              runAsUser: 1000
            args:
            - khiops
            - -s
            resources:
              limits:
                cpu: 1
                memory: 512Mi
    Worker:
      replicas: 2
      template:
        spec:
          containers:
          - image: khiopsml/khiops-ubuntu
            name: mpi-worker
            securityContext:
              runAsUser: 1000
            args:
            - /usr/sbin/sshd
            - -De
            - -f
            - /home/ubuntu/.sshd_config
            env:
            - name: KHIOPS_MEMORY_LIMIT
              valueFrom:
                resourceFieldRef:
                  divisor: "1Mi"
                  resource: requests.memory
            readinessProbe:
              tcpSocket:
                port: 2222
              initialDelaySeconds: 4
            resources:
              requests
                cpu: 4
                memory: 4Gi
```

In this example, the khiops-ubuntu container is launched as an MPI Job requesting 2 workers with 4 virtual CPUs and 4GiB of RAM each. 
The job can be launched on the cluster by requesting the specified yaml file:
```kubectl apply -f khiops_job.yaml```
The MPI Operator takes care of launching the pods and interconnecting them. Once ready, the launcher starts the execution. In this example it executes the "khiops -s" command which displays the allocated resources as seen by the khiops program. The output is similar to:
```
Khiops 10.3.0

Drivers:
 Remote driver (1.0.0) for URI scheme 'file'
 S3 driver (0.0.13) for URI scheme 's3'
 GCS driver (0.0.11) for URI scheme 'gs'
Environment variables:
 KHIOPS_MEMORY_LIMIT 4096
Internal environment variables:
 None
System resources :
 Host number 2
 Physical cores on system 16
 Logical processes on system 8
 Available memory on system 125.8 GB (Logical 78.6 GB)
 Available disk space on system 104.4 GB
 hostname MPI ranks logical memory disk cores
 khiops-worker-0 0,1,2,3 39.3 GB 79.1 GB 8
 khiops-worker-1 4,5,6,7 39.3 GB 25.3 GB 8
System
PRETTY_NAME="Ubuntu 22.04.5 LTS"
NAME="Ubuntu"
VERSION_ID="22.04"
system=Linux
release=4.18.0-147.5.1.6.h1194.eulerosv2r9.x86_64
version=#1 SMP Sat Mar 2 09:00:25 UTC 2024
```

Important! In the MPI Job definition, the MPI Operator allows setting independently the slotsPerWorker (the number of processes per worker pod) and the number of CPU cores of the worker. For best performance with khiops, we recommend always setting these to the same value, or at least to make sure the number of CPU per worker is greater or equal to the number of requested slots. In doubt, please refer to the MPI Operator documentation.

### Job customizations

Once we are able to run khiops distributed, in order to perform some actual work, we essentially need to replace the "khiops -s" command with the desired program, for example "pyton my_script.py". 

Assuming we have build a custom image including a python script, we would replace the container image of the launcher with this custom image. Since the workers will always act as pure khiops slaves, there is no need to change their image from the standard khiops.

If accessing data residing on a cloud storage such as S3, the credentials can be provided either as environment variables or as a mounted volume containing the standard AWS configuration files.

Therefore a more realistic job definition would look like this:
```
apiVersion: kubeflow.org/v2beta1
kind: MPIJob
metadata:
  name: khiops
spec:
  slotsPerWorker: 4
  runPolicy:
    cleanPodPolicy: Running
    ttlSecondsAfterFinished: 3600
  sshAuthMountPath: /home/ubuntu/.ssh
  mpiReplicaSpecs:
    Launcher:
      replicas: 1
      template:
        spec:
          containers:
          - image: my-custom-khiops-python-image
            name: mpi-launcher
            securityContext:
              runAsUser: 1000
            args:
            - python
            - my_script.py
            resources:
              limits:
                cpu: 1
                memory: 512Mi
            envFrom:
            - secretRef:
                name: aws-secrets
    Worker:
      replicas: 2
      template:
        spec:
          containers:
          - image: khiopsml/khiops-ubuntu
            name: mpi-worker
            securityContext:
              runAsUser: 1000
            args:
            - /usr/sbin/sshd
            - -De
            - -f
            - /home/ubuntu/.sshd_config
            env:
            - name: KHIOPS_MEMORY_LIMIT
              valueFrom:
                resourceFieldRef:
                  divisor: "1Mi"
                  resource: requests.memory
            readinessProbe:
              tcpSocket:
                port: 2222
              initialDelaySeconds: 4
            resources:
              requests
                cpu: 4
                memory: 4Gi
```