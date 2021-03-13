#!/bin/bash
set -eux
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
# 4. Increasing the localisation radius increases the number of local observations and hence the overall impact of observations. To compensate this in a system with horizontal localisation one has to change the R-factor as the square of the localisation radius.
# Covariance localization remedies sampling errors due to limited ensemble size in ensemble data assimilation


# reference settings
# KFACTORs=("2" "1")  # default as 2 in topaz
# RFACTORs=("2" "1")   #1
# LOCRADs=("100" "300" "600")  # meaning, radius 2.3*
# INFLATIONs=("1" "1.03" "1.09")  # <1.1 for 100 members
JOB_SETUP_DIR=$(cd `dirname $0`;pwd)
>${JOB_SETUP_DIR}/nohup.out  # empty this file
# >${JOB_SETUP_DIR}/result.md

ENSPATH=/cluster/work/users/chengsukun/src/simulations/ensemble_forecasts_2019-09-03_7days_x_6cycles_memsize100/date6
# ENSPATH=/nird/projects/nird/NS2993K/NORSTORE_OSL_DISK/NS2993K/chengsukun/ensemble_forecasts_2019-09-03_7days_x_6cycles_memsize100/date6
#
FILTER=${ENSPATH}/filter
mkdir
cp ~/src/nextsim/modules/enkf/enkf-c/bin/* ${FILTER}/
#
script=${ENSPATH}/slurm.enkf.nextsim.sh
cp ${NEXTSIM_ENV_ROOT_DIR}/slurm.enkf.template.sh $script
echo "parameters combination     type  NumberofObs.  [for.inn.]  [an.inn.]   for.inn.   an.inn.  for.spread    an.spread" > result.md
option=1
# set 1 Using 100 member
if [ $option == 1 ]
then
    KFACTORs=("2")  # default as 2 in topaz
    RFACTORs=("2")   #1
    LOCRADs=( "300")  # meaning, radius 2.3*
    INFLATIONs=("1" )  # <1.1 for 100 members
    ENSSIZE=100
    mv $FILTER/prior/files/*.nc $FILTER/prior/
else
    #set 2 using 40 member
    KFACTORs=("2")  # default as 2 in topaz
    RFACTORs=("2")   #1
    LOCRADs=("10"  "50" "100" "300" "600")  # meaning, radius 2.3*
    INFLATIONs=("1" )  # <1.1 for 100 members
    ENSSIZE=40
    # ENSPATH=/cluster/work/users/chengsukun/src/simulations/run_Ne40_T4_D7/I1_L100_R2_K2/date1
fi

#
for (( k1=0; k1<${#KFACTORs[@]};   k1++ )); do
for (( r1=0; r1<${#RFACTORs[@]};   r1++ )); do
for (( l1=0; l1<${#LOCRADs[@]};    l1++ )); do
for (( i1=0; i1<${#INFLATIONs[@]}; i1++ )); do
    cd ${FILTER}
    INFLATION=${INFLATIONs[$i1]}
    LOCRAD=${LOCRADs[$l1]}
    RFACTOR=${RFACTORs[$r1]}
    KFACTOR=${KFACTORs[$k1]}  
    echo "========= " $k1 $r1 $l1 $i1 
    
    sed -i "s;^ENSSIZE.*$;ENSSIZE = ${ENSSIZE};g"  enkf.prm
    sed -i "s;^INFLATION.*$;INFLATION = ${INFLATION};g"  enkf.prm
    sed -i "s;^LOCRAD.*$;LOCRAD = ${LOCRAD};g"  enkf.prm
    sed -i "s;^RFACTOR.*$;RFACTOR = ${RFACTOR};g"  enkf.prm
    sed -i "s;^KFACTOR.*$;KFACTOR = ${KFACTOR};g"  enkf.prm

    make clean
    
    # if [ $option == 1 ]
    # then
    #     ./enkf_prep --no-superobing enkf.prm 2>&1 | tee prep.out
    #     ./enkf_calc --use-rmsd-for-obsstats --ignore-no-obs enkf.prm 2>&1 | tee calc.out
    #     ./enkf_update --calculate-spread enkf.prm 2>&1 | tee update.out
    # #
    # else
        ## 2.submit enkf after finishing the ensemble simulations
        XPID0=$(squeue -u chengsukun | grep -o chengsuk |wc -l) 
        ##------- 
        sbatch $script $ENSPATH 
        # ------ wait the completeness in this cycle.
        XPID=$(squeue -u chengsukun | grep -o chengsuk |wc -l) 	
        while [[ $XPID -gt $XPID0 ]]; do 
            sleep 60
            XPID=$(squeue -u chengsukun | grep -o chengsuk |wc -l) # number of running jobs 
        done
    # fi

    string=$( tail -3 ${FILTER}/calc.out|head -1 )
    echo "I${INFLATION}_L${LOCRAD}_R${RFACTOR}_K${KFACTOR}  $string" >> ${JOB_SETUP_DIR}/result.md
    OUTPUT_DIR=${FILTER}/size${ENSSIZE}_I${INFLATION}_L${LOCRAD}_R${RFACTOR}_K${KFACTOR}
    
    [ ! -d $OUTPUT_DIR ] && mkdir $OUTPUT_DIR
    mv ${FILTER}/*.out ${OUTPUT_DIR}
    mv ${FILTER}/prior/*.analysis ${OUTPUT_DIR}
    mv ${FILTER}/*.nc  ${OUTPUT_DIR}
done
done
done
done

mv ${JOB_SETUP_DIR}/nohup.out $FILTER
mv $[FILTER]/prior/{mem05*,mem06*,mem07*,mem08*,mem09*,mem100.nc} $[FILTER]/prior/files/*.nc