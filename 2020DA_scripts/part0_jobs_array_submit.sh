#!/bin/bash 
set -uex
ENV_FILE=${NEXTSIM_ENV_ROOT_DIR}/nextsim.ensemble.intel.src

##-------  Confirm working,data,ouput directories --------
    JOB_SETUP_DIR=$(cd `dirname $0`;pwd)       
    # observation CS2SMOS data discription
    OBSNAME_PREFIX=$NEXTSIMDIR/data/CS2_SMOS_v2.2/W_XX-ESA,SMOS_CS2,NH_25KM_EASE2_ 
    OBSNAME_SUFFIX=_r_v202_01_l4sit

    # experiment settings
    time_init=2018-11-11   # starting date of simulation
    duration=1    # tduration*duration is the total simulation time
    tduration=2   # number of forecast-analysis cycle. 
    ENSSIZE=2    # ensemble size  
    # $OUTPUT_DIR
    OUTPUT_DIR=${IO_nextsim}/test_Ne${ENSSIZE}_T${tduration}_D${duration}/I${INFLATION}_L${LOCRAD}_R${RFACTOR}_K${KFACTOR}   
    OUTPUT_DIR=${OUTPUT_DIR//./p}  ## replace . with p
    echo 'work path:' $OUTPUT_DIR 
    [ -d $OUTPUT_DIR ] && rm -rf $OUTPUT_DIR  
    mkdir -p ${OUTPUT_DIR}

## ----------- execute ensemble runs ----------
for (( iperiod=1; iperiod<=${tduration}; iperiod++ )); do
    if [ $iperiod -eq 1 ]; then 
        start_from_restart=false
        restart_from_analysis=false
    else
        start_from_restart=true
        restart_from_analysis=true
        time_init=$(date +%Y-%m-%d -d "${time_init} + ${duration} day")
    fi
    echo "period ${time_init} to $(date +%Y%m%d -d "${time_init} + ${duration}-1 day")"
    ENSPATH=${OUTPUT_DIR}/date${iperiod}  
    mkdir -p ${ENSPATH} 
    
    ## ----------------------------------------------
    # 0. create files strucure, copy and modify configuration files inside
        cp ${JOB_SETUP_DIR}/{part0_jobs_array_submit.sh,part1_create_file_system.sh}  ${ENSPATH} 
        source ${ENSPATH}/part1_create_file_system.sh

    XPID0=$(squeue -u chengsukun | grep -o chengsuk |wc -l) 
        
    # 1. submit the script for ensemble forecasts
        script=${ENSPATH}/slurm.jobarray.nextsim.sh
        cp $NEXTSIM_ENV_ROOT_DIR/slurm.jobarray.template.sh $script
        cmd="sbatch --array=1-${ENSSIZE} $script $ENSPATH $ENV_FILE "
        $cmd 2>&1 | tee sjob.id
        jobid=$( awk '{print $NF}' sjob.id)

    # 2.submit enkf after finishing the ensemble simulations 
        script=${ENSPATH}/slurm.enkf.nextsim.sh
        cp ${NEXTSIM_ENV_ROOT_DIR}/slurm.enkf.template.sh $script
        cmd="sbatch --dependency=afterok:${jobid} $script $FILTER $ENV_FILE"
        $cmd    

    # ------ wait the completeness in this cycle.
    XPID=$(squeue -u chengsukun | grep -o chengsuk |wc -l) 	
    while [[ $XPID -gt $XPID0 ]]; do 
        sleep 60
        XPID=$(squeue -u chengsukun | grep -o chengsuk |wc -l) # number of running jobs 
    done
    # ----------------------------------------------

    echo "  project *.nc.analysis on reference_grid.nc, move it and restart file to $NEXTSIMDIR/data/ for ensemble forecasts in the next cycle"
#<<'COMMENT'
    rm -f ${NEXTSIMDIR}/data/*.nc.analysis   
    [ -d $OUTPUT_DIR ] && rm -rf ${NEXTSIMDIR}/data/restart
    mkdir -p ${NEXTSIMDIR}/data/restart
    cd $ENSPATH
    for (( i=1; i<=${ENSSIZE}; i++ )); do
	    memname=$(printf "mem%.3d" ${i})
        cdo merge ${FILTER}/reference_grid.nc  ${FILTER}/prior/${memname}.nc.analysis  ${NEXTSIMDIR}/data/${memname}.nc.analysis 
        cp -f ${NEXTSIMDIR}/data/${memname}.nc.analysis ${ENSPATH} #backup
        # 
        cp -f ${ENSPATH}/${memname}/{field_*,mesh_*}  ${NEXTSIMDIR}/data/restart
    done   
#COMMENT
done