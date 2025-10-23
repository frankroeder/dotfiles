#!/usr/bin/env sh
# SLURM workload manager aliases and functions
# For HPC cluster job management

! command -v sacct >/dev/null 2>&1 && return

export SACCT_FORMAT="jobid,jobname,user,account,alloccpus,elapsed,partition,nodelist,state,exitcode"

# Aliases
alias gpuq='squeue --partition=gpu -o "%.18i %Q %.9q %.8j %.8u %.10a %.2t %.10M %.10L %.6C %R" | more'
alias myq='squeue -u $USER --start -a'
alias sacct2='sacct --format="JobID,JobName%30,elapsed"'

# Functions
wmyq() {
  watch -n 10 -d 'squeue -u $USER --start'
}

wq() {
  watch -n 10 -d 'squeue --start --format="%.7i %.7Q %.7q %.15j %.12u %.10a %.20S %.6D %.5C %R" --sort=S --states=PENDING | egrep -v "N/A" | head -20'
}

wgpuq() {
  watch -n 10 -d 'squeue --start --partition=gpu --format="%.7i %.7Q %.7q %.15j %.12u %.10a %.20S %.6D %.5C %R" --sort=S --states=PENDING | egrep -v "N/A" | head -20'
}

wacct() {
  watch -n 5 -d 'sacct'
}

tacct() {
  watch -n 5 -d 'sacct | tail -n 40'
}

unique_hosts() {
  sacct | grep RUNNING | cut -d ' ' -f50 | uniq | sort
}

sacct30days() {
  sacct --starttime $(date -d '30 days ago' +%F)
}

sii() {
  echo "CURRENT TRIALS RUNNING: $(sacct | grep RUNNING | wc -l)"
  echo "CURRENT TRIALS PENDING $(sacct | grep PENDING | wc -l)"
}

# Cancel all jobs
killallslurm() {
  for SLURMID in $(sacct -n | awk '{print $1}'); do
    echo "Canceling $SLURMID"
    scancel $SLURMID
  done
}

export UV_LINK_MODE=copy
export UV_CACHE_DIR="$HOME/wt"
