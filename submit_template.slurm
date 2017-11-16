#!/bin/bash
#SBATCH -J {run_id}_%a
#SBATCH -o log_slurm.{run_id}_%a
#SBATCH -n 1
#SBATCH --cpus-per-task={threads}
#SBATCH --array=1-{jobs}
#SBATCH -p {queue}
#SBATCH -t 12:00:00
#SBATCH --mail-type=END
#SBATCH --mail-user=andres.baeza@gmail.com
ulimit -v unlimited
ulimit -s unlimited

module load {modules}

