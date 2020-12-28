#!/bin/bash
##set -eux
err_report() {
    echo "Error on line $1"
}
trap 'err_report $LINENO' ERR
## Tune factors (refer to Todo 9)
# 1. Incresing R-factor decreases the impact of observation. Ensemble spread/sqrt(R-factor)
# 2. Incresing K-factor increases the impact of ensemble spread. background check. 2.7.3. 
#    Modifies observation error so that the increment for this observation would not exceed KFACTOR * <ensemble spread> (all in observation space) after assimilating this observation only.
# 3. Inflation . The ensemble anomalies (A=E-x.1') for any model state element will be inflated to avoid collapses. 
#     (x_a - x\bar)*inflation + x\bar
#     capping of inflation: inflation = 1+inflation*( std_f/std_a-1)
# 4. localisation radii defines the impact area size of observation. Increasing it increases the number of local observations

>nohup.out  # empty this file

KFACTORs=("2" "1")  # default as 2 in topaz
RFACTORs=("2" )   #1
INFLATIONs=("1" "1.03" "1.09")  # <1.1 for 100 members
LOCRADs=("100" "300" "600")  # meaning, radius 2.3*

#start ensemble from sep.
#
RUNPATH=$(cd `dirname $0`;pwd)       # path of this.sh
for (( m1=0; m1<${#KFACTORs[@]};   m1++ )); do
for (( k1=0; k1<${#RFACTORs[@]};   k1++ )); do
for (( j1=0; j1<${#LOCRADs[@]};    j1++ )); do
for (( i1=0; i1<${#INFLATIONs[@]}; i1++ )); do
    INFLATION=${INFLATIONs[$i1]}
    LOCRAD=${LOCRADs[$j1]}
    RFACTOR=${RFACTORs[$k1]}
    KFACTOR=${KFACTORs[$m1]}  
    echo "========= " $m1 $k1 $j1 $i1 
    cd ${RUNPATH}
    source part0_weekly_runs.sh
done
done
done
done
