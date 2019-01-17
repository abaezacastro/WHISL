# Wildlife-Human Interactions in Shared Landscape (WHISL)

This model simulates a group of farmers that have encounters with individuals of a wildlife population. The model also simulates the movement of the individual of the wildlife population. Each farmer owns a set of patches that represent they farmland. A farm is a group of patches or cells. Each farmer must decide what cells inside their farm they will use to produce agriculture. The farmer must also decide if it will protect the cells from the individuals of the wildlife population entering their farm. We call this action "to fence". Each time that a cell is fenced, the changes of the individual to move to that cell is reduced. Each encounter reduces the productivity of the agriculture in a pach impacted. Farmers therefore can reduce the risk of encounters by excluding them by fencing. 

Each farmer calculates an expected economic return (or income) per cell by producing crops and expluding wildlife. This decisions are made considering the perception of risk of encounters. The perception of risk is subjective because it depends on past encounters and on the perception of risk from other farmers in the community. The community of farmers passes information about this risk throught in a social network. The effect of the opinions of others is represented by parameters (1-w1). The higher the effect of other agents the more they care about others' opinions. The model evaluates how social interactions affect the number of encounters and the suitability of the landscape for wildlife.


To run the model in cluster
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
