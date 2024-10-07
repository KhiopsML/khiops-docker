#!/bin/bash

if [ -z ${K_MPI_JOB_ROLE+x} ]; then

  echo Standard execution
  
  # Automatically determine the number of CPU cores usable by the Khiops binary - unless already set 
  # Note: when allocating less than 1 CPU to the Khiops container (e.g. in a k8s deployment), Khiops will refuse to run.
  # In such case it is recommended to set KHIOPS_PROC_NUMBER=1 in order to make Khiops believe that is has 1 CPU allocated.
  export KHIOPS_PROC_NUMBER=`/cpu_count.sh`
  echo KHIOPS_PROC_NUMBER=$KHIOPS_PROC_NUMBER

  # With OpenMPI, khiops fails to propagate credentials provided as env variables
  # Therefore we make "khiops" resolve to a custom script that propagates all variables
  # that can be relevant for khiops
  mkdir -p $HOME/sbin
  ln -s /usr/bin/khiops_local $HOME/sbin/khiops
  export PATH=$HOME/sbin:$PATH

  # for python scripts that invoke MODL directly we define the needed MPI variables
  KHIOPS_MPI_COMMAND_ARGS="--mca btl_vader_single_copy_mechanism none --allow-run-as-root --quiet -n ${KHIOPS_PROC_NUMBER}"
  for line in $(env | grep -E '^(KHIOPS|Khiops|AWS_|S3_|GOOGLE_)'); do
    name=${line%%=*}
    KHIOPS_MPI_COMMAND_ARGS="${KHIOPS_MPI_COMMAND_ARGS} -x ${name}"
  done
  export KHIOPS_MPIEXEC_PATH=/usr/bin/mpirun
  export KHIOPS_MPI_COMMAND_ARGS

else

  echo Distributed execution

  # The following is only relevant when started via a mpioperator job
  function resolve_host() {
    host="$1"
    check="nslookup $host"
    max_retry=10
    counter=0
    backoff=0.1
    until $check > /dev/null
    do
      if [ $counter -eq $max_retry ]; then
        echo "Couldn't resolve $host"
        return
      fi
      sleep $backoff
      echo "Couldn't resolve $host... Retrying"
      ((counter++))
      backoff=$(echo - | awk "{print $backoff + $backoff}")
    done
    echo "Resolved $host"
  }

  if [ "$K_MPI_JOB_ROLE" == "launcher" ]; then

    # By default khiops tries to determine locally available cores which breaks in distributed mode
    # Therefore we make "khiops" resolve to a custom script that honors the /etc/hostfile settings
    # In addition the script will propagate relevant khiops env variables properly to the workers
    mkdir -p $HOME/sbin
    ln -s /usr/bin/khiops_distributed $HOME/sbin/khiops
    export PATH=$HOME/sbin:$PATH

    # for python scripts that invoke MODL directly we define the needed MPI variables
    KHIOPS_MPI_COMMAND_ARGS="--mca btl_vader_single_copy_mechanism none --allow-run-as-root --quiet"
    for line in $(env | grep -E '^(KHIOPS|Khiops|AWS_|S3_|GOOGLE_)'); do
      name=${line%%=*}
      KHIOPS_MPI_COMMAND_ARGS="${KHIOPS_MPI_COMMAND_ARGS} -x ${name}"
    done
    export KHIOPS_MPIEXEC_PATH=/usr/bin/mpirun
    export KHIOPS_MPI_COMMAND_ARGS

    # Wait for name resolution to complete
    if [[ $HOSTNAME == *"-launcher-"* ]]; then
      resolve_host "$HOSTNAME"
    fi
    if [ -f /etc/mpi/hostfile ]; then
      cut -d ' ' -f 1 /etc/mpi/hostfile | while read -r host
      do
        resolve_host "$host"
      done
    fi

  elif [ "$K_MPI_JOB_ROLE" == "worker" ]; then
    # Configure sshd to propagate Khiops environment to ssh sessions 
    for line in $(env | grep -E '^(KHIOPS|Khiops|AWS_|S3_|GOOGLE_)'); do
        name=${line%%=*}
        value=${line#*=}
        echo "SetEnv ${name}=${value}" >> $HOME/.sshd_config
    done

  fi

fi

if [ $# -eq 0 ]
then
  # No arguments supplied, run as a service
  . /scripts/run_service.sh
else
  "$@"
fi
