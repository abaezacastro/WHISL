#!/bin/bash

java -Xmx8024m -cp NetLogo.jar org.nlogo.headless.Main \
     --model Risk_Attack_model_V6.nlogo \
     --experiment experiment \
     --setup-file $1 \
     --table $2 \
     --threads $3
