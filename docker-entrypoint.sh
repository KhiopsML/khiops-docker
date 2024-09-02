#!/bin/bash

# Automatically determine the number of CPU cores usable by the Khiops binary - unless already set 
# Note: when allocating less than 1 CPU to the Khiops container (e.g. in a k8s deployment), Khiops will refuse to run.
# In such case it is recommended to set KHIOPS_PROC_NUMBER=1 in order to make Khiops believe that is has 1 CPU allocated.
export KHIOPS_PROC_NUMBER=`/cpu_count.sh`
echo KHIOPS_PROC_NUMBER=$KHIOPS_PROC_NUMBER

if [ $# -eq 0 ]
then
  # No arguments supplied, run as a service
  . /scripts/run_service.sh
else
  "$@"
fi

