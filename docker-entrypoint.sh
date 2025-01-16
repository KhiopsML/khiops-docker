#!/bin/bash

if [ -z ${K_MPI_JOB_ROLE+x} ]; then

  echo Standard execution
  
  # Automatically determine the number of CPU cores usable by the Khiops binary - unless already set 
  # Note: when allocating less than 1 CPU to the Khiops container (e.g. in a k8s deployment), Khiops will refuse to run.
  # In such case it is recommended to set KHIOPS_PROC_NUMBER=1 in order to make Khiops believe that is has 1 CPU allocated.
  export KHIOPS_PROC_NUMBER=`/cpu_count.sh`
  echo KHIOPS_PROC_NUMBER=$KHIOPS_PROC_NUMBER

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
    
    # List khiops related variables that need to be propagated by the launcher to the workers
    for line in $(env | grep -E '^(KHIOPS|Khiops|AWS_|S3_|GOOGLE_)'); do
      name=${line%%=*}
      KHIOPS_MPI_EXTRA_FLAGS="${KHIOPS_MPI_EXTRA_FLAGS} -x ${name}"
    done
    if ! [ -z ${KHIOPS_MPI_EXTRA_FLAGS+x} ]; then
      export KHIOPS_MPI_EXTRA_FLAGS
    fi

    # Turn on verbose MPI logs to ease debugging configuration issues
    export KHIOPS_MPI_VERBOSE=true

    mpi_host_file=/etc/mpi/hostfile

    # Temporary: pass KHIOPS_MPI_HOST_FILE even if it is the default file expected by mpiexec
    export KHIOPS_MPI_HOST_FILE=$mpi_host_file

    # Wait for name resolution to complete
    if [[ $HOSTNAME == *"-launcher-"* ]]; then
      resolve_host "$HOSTNAME"
    fi
    if [ -f $mpi_host_file ]; then
      cut -d ' ' -f 1 $mpi_host_file | while read -r host
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
