#!/usr/bin/env sh
# SLURM workload manager aliases and functions
# For HPC cluster job management

! command -v sacct >/dev/null 2>&1 && return

export SACCT_FORMAT="jobid,jobname,user,account,alloccpus,elapsed,partition,nodelist,state,exitcode"

# Aliases
alias gpuq='squeue --partition=gpu -o "%.18i %Q %.9q %.8j %.8u %.10a %.2t %.10M %.10L %.6C %R" | more'
alias myq='squeue -u $USER --start -a'
alias sacct2='sacct --format="JobID,JobName%30,elapsed"'
# Quick queue overviews (inspired by common HPC setups)
alias sq='squeue -o "%.18i %Q %.9q %.15j %.8u %.10a %.2t %.10M %.10L %.6C %R" | more'   # full cluster queue, compact
alias sqme='squeue -u $USER -o "%.18i %Q %.9q %.15j %.8u %.10a %.2t %.10M %.10L %.6C %R"' # your jobs only, nice format
alias sqgpu='squeue --partition=gpu -o "%.18i %Q %.9q %.15j %.8u %.10a %.2t %.10M %.10L %.6C %R" | more' # gpu queue

# Node/partition info
alias sinfo='sinfo -o "%20P %5D %6t %8z %10m %10d %11l %32f %N"'   # clean partition/node summary
alias sinfol='sinfo -o "%20P %5D %14F %8z %10m %10d %11l %32f %N"' # long format with more details

# Accounting shortcuts
alias sacctm='sacct --format="JobID,JobName%30,User,Account,AllocCPUs,Elapsed,State,ExitCode"' # more useful default
alias saccttoday='sacct --starttime $(date +%F) --format="JobID,JobName%30,elapsed,state"'     # today's jobs only
alias seff='seff'  # just for completeness (shows efficiency of a completed job)

# Cancel shortcuts
alias scancelme='scancel -u $USER'                    # kill all your jobs (be careful!)
alias scancelpend='scancel -u $USER -t PENDING'       # only pending ones
alias scancelrun='scancel -u $USER -t RUNNING'        # only running ones

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

# Watch your own jobs with nicer formatting + start times
wmyqfull() {
  watch -n 10 -d 'squeue -u $USER --start -o "%.7i %.7Q %.7q %.20j %.12u %.10a %.20S %.6D %.5C %R"'
}

# Compact "what's happening on the cluster" watcher (top pending + running)
wcluster() {
  watch -n 15 -d 'echo "=== PENDING ==="; squeue --start --states=PENDING --sort=S -o "%.7i %.15j %.12u %R" | head -15; echo; echo "=== RUNNING ==="; squeue --states=RUNNING -o "%.7i %.15j %.12u %.6D %R" | head -10'
}

# GPU-specific cluster watcher
wgpustats() {
  watch -n 10 -d 'echo "GPU QUEUE:"; squeue --partition=gpu --states=PENDING,RUNNING -o "%.7i %.15j %.12u %.6D %.5C %R" | head -25'
}

# Job efficiency for a specific job (or last few)
sefflast() {
  local jobid=${1:-$(sacct -n -X --format=JobID --state=COMPLETED | tail -1 | awk '{print $1}')}
  echo "Efficiency for job $jobid:"
  seff "$jobid"
}

# List nodes currently used by your running jobs (nicer than unique_hosts)
mynodes() {
  squeue -u $USER -t RUNNING -o "%N" | tr ',' '\n' | sort | uniq -c | sort -nr
}

# Overview of system + your procs on unique RUNNING-job nodes
# Usage: nodestats [--gpu|-g] [--cpu|-c]   (default: both; u0XX = GPU)
nodestats() {
  local want_gpu=0 want_cpu=0 node kind
  for arg in "$@"; do
    case "$arg" in
      --gpu|-g) want_gpu=1 ;;
      --cpu|-c) want_cpu=1 ;;
    esac
  done
  [ "$want_gpu" -eq 0 ] && [ "$want_cpu" -eq 0 ] && want_gpu=1 && want_cpu=1

  local nodes me=$USER
  nodes=$(squeue -u "$me" -t RUNNING -h -o "%N" 2>/dev/null | tr ',' '\n' | sort -u)
  [ -z "$nodes" ] && { echo "No RUNNING nodes."; return 0; }

  for node in $nodes; do
    case "$node" in
      u0[0-9][0-9]) [ "$want_gpu" -eq 0 ] && continue; kind=GPU ;;
      *)            [ "$want_cpu" -eq 0 ] && continue; kind=CPU ;;
    esac
    echo
    echo "=== $node ($kind) ==="
    ssh -o ConnectTimeout=8 -o BatchMode=yes "$node" "
      uptime
      free -h
      if command -v nvidia-smi >/dev/null 2>&1; then
        echo
        nvidia-smi --query-gpu=index,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader
        nvidia-smi --query-compute-apps=pid,process_name,used_gpu_memory --format=csv,noheader 2>/dev/null
      fi
      echo
      echo '-- node top --'
      ps -eo user,pid,%cpu,%mem,rss,comm --sort=-%cpu | head -n 8
      echo
      echo '-- your procs --'
      ps -u $me -o pid,%cpu,%mem,rss,etime,comm --sort=-%mem | head -n 20
    " 2>/dev/null || echo "  ssh failed: $node"
  done
}

# Quick summary of your resource usage over last N days (default 7)
myusage() {
  local days=${1:-7}
  echo "=== Your usage last $days days ==="
  sacct --starttime "$(date -d "$days days ago" +%F)" -u $USER --format="JobID,JobName%20,AllocCPUs,Elapsed,State" | grep -E "(RUNNING|COMPLETED|FAILED)"
}

# Kill jobs by name pattern (very handy!)
killbyname() {
  if [ -z "$1" ]; then
    echo "Usage: killbyname <jobname-pattern>"
    return 1
  fi
  for jid in $(squeue -u $USER -h -o "%A" -n "$1"); do
    echo "Canceling job $jid (name matches $1)"
    scancel "$jid"
  done
}

# Show pending jobs with estimated start time, sorted nicely
pending() {
  squeue --start --states=PENDING --sort=S -o "%.7i %.20j %.12u %.20S %.6D %R" | egrep -v "N/A" | head -30
}

# Full job details for one or more jobs
jobinfo() {
  if [ -z "$1" ]; then
    echo "Usage: jobinfo <jobid> [jobid ...]"
    return 1
  fi
  for id in "$@"; do
    echo "=== Job $id ==="
    scontrol show job "$id" | cat
    echo
  done
}

export UV_LINK_MODE=copy
export UV_CACHE_DIR="$HOME/wt"
