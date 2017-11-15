# risk-perception-wildlife-attack
Rund the model in cluster
Log into the system:
ssh ncarter@r2.boisestate.edu

Move to risk model directory:
cd risk-perception-wildlife-attack

Generate input files in test directory:
python vhu.py --netlogo=$NETLOGO --threads=14 --workdir=/home/ncarter/test

Move to test directory:
cd ~/test

Submit job:
sbatch submit_all.sbatch

Check jobs:
squeue
sacct
