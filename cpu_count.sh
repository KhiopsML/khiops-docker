#!/bin/bash

if [ -z "$KHIOPS_PROC_NUMBER" ] || [ "$KHIOPS_PROC_NUMBER" == 'KHIOPS_PROC_NUMBER' ]
then
  quota='-1'
  period='-1'
  # Try to determine number of CPUs allocated to Khiops
  if [ -e /sys/fs/cgroup/cpu.max ]
  then
    # Parse cpu allocation in the form "number_quota|'max' number_period"
    quota=`cut -d ' ' -f 1 /sys/fs/cgroup/cpu.max`
    period=`cut -d ' ' -f 2 /sys/fs/cgroup/cpu.max`
    # if quota == 'max' we have no quota limit
    if [ "$quota" = "max" ]; then quota='-1'; fi
  else
    if [ -e /sys/fs/cgroup/cpu/cpu.cfs_quota_us ]
    then
      quota=`cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us`;
    fi
    if [ -e /sys/fs/cgroup/cpu/cpu.cfs_period_us ]
    then
      period=`cat /sys/fs/cgroup/cpu/cpu.cfs_period_us`;
    fi
  fi
  if [ -e /sys/fs/cgroup/cpuset/cpuset.cpus ]
  then
    cpuset=`cat /sys/fs/cgroup/cpuset/cpuset.cpus`;
  fi
  if [ -e /sys/fs/cgroup/cpuset.cpus.effective ]
  then
    cpuset=`cat /sys/fs/cgroup/cpuset.cpus.effective`
  fi

  numphysicalcores=$(lscpu -b -p=Core,Socket | grep -v '^#' | sort -u | wc -l)
  numcores=0
  # Here we determine the number of cores allowed by cpuset (e.g. 1-3,5,8)
  regex="([0-9]+)-([0-9]+)"
  sets=$(echo $cpuset | tr "," "\n")
  for s in $sets
  do
      if [[ $s =~ $regex ]]
      then
        start=${BASH_REMATCH[1]}
        end=${BASH_REMATCH[2]}
        num=$(expr $end - $start + 1)
      else
        num=1
      fi
      numcores=$(expr $numcores + $num)
  done
  # we don't want more processes than physical cores
  numcores=$(( $numphysicalcores < $numcores ? $numphysicalcores : $numcores ))

  awk "
  # Define intuitive (nearest integer) rounding function as per awk manual
  function round(x, ival, aval, fraction)
  {
      ival = int(x)    # integer part, int() truncates

      # see if fractional part
      if (ival == x)   # no fraction
          return ival   # ensure no decimals

      if (x < 0) {
          aval = -x     # absolute value
          ival = int(aval)
          fraction = aval - ival
          if (fraction >= .5)
            return int(x) - 1   # -2.5 --> -3
          else
            return int(x)       # -2.3 --> -2
      } else {
          fraction = x - ival
          if (fraction >= .5)
            return ival + 1
          else
            return ival
      }
  }
  BEGIN {
    if ($quota!=-1) {assigned=round($quota/$period)} else {assigned=$numcores};
    if (assigned>$numcores) {assigned=$numcores}
    if (assigned<1) {assigned=1}
    print assigned;
  }"
else
  echo $KHIOPS_PROC_NUMBER
fi
