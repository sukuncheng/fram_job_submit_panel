#!/bin/bash 
# set -uex  # uncomment for debugging
err_report() {
    echo "Error on line $1"
}
trap 'err_report $LINENO' ERR
function WaitforTaskFinish(){
    # ------ wait the completeness in this cycle.
    XPID=$(squeue -u chengsukun | grep -o chengsuk |wc -l) 	
    while [[ $XPID -gt $1 ]]; do 
        sleep 60
        XPID=$(squeue -u chengsukun | grep -o chengsuk |wc -l) # number of running jobs 
    done
}

##-------  Confirm working,data,ouput directories --------
JOB_SETUP_DIR=$(cd `dirname $0`;pwd)   
ENV_FILE=${NEXTSIM_ENV_ROOT_DIR}/nextsim.ensemble.intel.src
cd $NEXTSIMDIR/data
rm -f WindPerturbation_mem* mesh_mem* field_mem* mem*.nc.analysis 

>nohup.out  # empty this file

    # experiment settings
    time_init=2019-10-15   # starting date of simulation
    duration=7    # tduration*duration is the total simulation time
    tduration=12   # number of DA cycles. 
    ENSSIZE=30    # ensemble size  
    block=1
    jobsize=$((${ENSSIZE}/${block}))

    # randf in pseudo2D.nml, whether do perturbation
    [[ ${ENSSIZE} > 1 ]] && randf=true || randf=false 

    # OUTPUT_DIR
    OUTPUT_DIR=${simulations}/run_${time_init}_Ne${ENSSIZE}_T${tduration}_D${duration}/I${INFLATION}_L${LOCRAD}_R${RFACTOR}_K${KFACTOR}  
    echo 'work path:' $OUTPUT_DIR 
   [ -d $OUTPUT_DIR ] && rm -rf $OUTPUT_DIR  
    [ ! -d $OUTPUT_DIR ] && mkdir -p ${OUTPUT_DIR}
    #
    restart_path=$NEXTSIMDIR/data    #be consist with restart path defined in slurm.jobarray.template.sh

## ----- do data assimilation using EnKF
    UPDATE=1 # 1: active assimilationcd
    # observation CS2SMOS data discription
    OBSNAME_PREFIX=$NEXTSIMDIR/data/CS2_SMOS_v2.2/W_XX-ESA,SMOS_CS2,NH_25KM_EASE2_ 
    OBSNAME_SUFFIX=_r_v202_01_l4sit  # backup data is in NEXTSIM_DATA_DIR

## ----------- execute ensemble runs ----------
for (( iperiod=1; iperiod<=${tduration}; iperiod++ )); do
    ENSPATH=${OUTPUT_DIR}/date${iperiod}  
    mkdir -p ${ENSPATH}     
    start_from_restart=true
    restart_from_analysis=true

    if [ $iperiod -eq 1 ]; then
        # prepare and link restart files
        for (( i=1; i<=${ENSSIZE}; i++ )); do
            memname=mem${i}
            echo "UPDATE=1, project *.nc.analysis on reference_grid.nc, move it and restart file to $restart_path for ensemble forecasts"
            # 
            restart_source=/cluster/work/users/chengsukun/src/simulations/ensemble_forecasts_2019-09-03_7days_x_6cycles_memsize100/date6
            # restart_source=/nird/projects/nird/NS2993K/NORSTORE_OSL_DISK/NS2993K/chengsukun/ensemble_forecasts_2019-09-03_7days_x_6cycles_memsize100/date6
            #
            cd  ${restart_source}/filter/size40_I${INFLATION}_L${LOCRAD}_R${RFACTOR}_K${KFACTOR}
            rm -f ${memname}.nc.analysis   //should be done ahead
            cdo merge $NEXTSIMDIR/data/reference_grid.nc   $(printf "mem%.3d" $i).nc.analysis  ${memname}.nc.analysis       
            ln -sf ${restart_source}/filter/size40_I${INFLATION}_L${LOCRAD}_R${RFACTOR}_K${KFACTOR}/${memname}.nc.analysis   ${restart_path}/${memname}.nc.analysis   
            ln -sf ${restart_source}/${memname}/WindPerturbation_${memname}.nc        ${restart_path}/WindPerturbation_${memname}.nc   
            ln -sf ${restart_source}/${memname}/restart/field_final.bin  $restart_path/field_${memname}.bin
            ln -sf ${restart_source}/${memname}/restart/field_final.dat  $restart_path/field_${memname}.dat
            ln -sf ${restart_source}/${memname}/restart/mesh_final.bin   $restart_path/mesh_${memname}.bin
            ln -sf ${restart_source}/${memname}/restart/mesh_final.dat   $restart_path/mesh_${memname}.dat
        done
    else
        time_init=$(date +%Y-%m-%d -d "${time_init} + ${duration} day")
    fi 
    
    #
    echo "period ${time_init} to $(date +%Y%m%d -d "${time_init} + $((${duration})) day")"
    # 0. create files strucure, copy and modify configuration files inside
        cp ${JOB_SETUP_DIR}/{part0_forecast_from_reanalysis*,part1_create_file_system.sh}  ${ENSPATH} 
        source ${ENSPATH}/part1_create_file_system.sh

    XPID0=$(squeue -u chengsukun | grep -o chengsuk |wc -l) 
    # 1.a submit the script for ensemble forecasts
        cd $ENSPATH
        script=${ENSPATH}/slurm.jobarray.nextsim.sh
        cp $NEXTSIM_ENV_ROOT_DIR/slurm.jobarray.template.sh $script

        # a. use job array
        # cmd="sbatch --array=1-${jobsize} $script $ENSPATH $ENV_FILE ${block} -1"
        # $cmd 2>&1 | tee sjob.id
        # jobid=$( awk '{print $NF}' sjob.id)
        # WaitforTaskFinish $XPID0

        # b resubmit failed task in jobarray
        for (( j=1; j<=3; j++ )); do
            for (( i=1; i<=${ENSSIZE}; i++ )); do
                grep -q -s "Simulation done" ${ENSPATH}/mem${i}/task.log && continue
                [ $j -eq 3 ] && return
                cmd="sbatch $script $ENSPATH $ENV_FILE ${block} $i"  # change slurm.jobarray.template.sh: SLURM_ARRAY_TASK_ID=$4   #if not use jobarray
                $cmd 2>&1 
            done            
            WaitforTaskFinish $XPID0   
        done
        # sbatch /cluster/work/users/chengsukun/src/simulations/run_Ne40_T1_D7/date1/slurm.jobarray.nextsim.sh /cluster/work/users/chengsukun/src/simulations/run_Ne40_T1_D7/date1 ${NEXTSIM_ENV_ROOT_DIR}/nextsim.ensemble.intel.src 1 1

    ## 2.submit enkf after finishing the ensemble simulations 
        if [ ${UPDATE} -eq 1 ]; then
            cd ${ENSPATH}
            script=${ENSPATH}/slurm.enkf.nextsim.sh
            cp ${NEXTSIM_ENV_ROOT_DIR}/slurm.enkf.template.sh $script
            cmd="sbatch $script $ENSPATH"  # --dependency=afterok:${jobid}
            # cmd="sbatch $script $ENSPATH"
            $cmd    
        fi
        WaitforTaskFinish $XPID0
    
        # ----------------------------------------------
    echo "  project *.nc.analysis on reference_grid.nc, move it and restart file to $restart_path for ensemble forecasts in the next cycle"
#<<'COMMENT'
    for (( i=1; i<=${ENSSIZE}; i++ )); do
	    memname=mem${i}
        ln -sf ${ENSPATH}/${memname}/restart/field_final.bin  $restart_path/field_${memname}.bin
        ln -sf ${ENSPATH}/${memname}/restart/field_final.dat  $restart_path/field_${memname}.dat
        ln -sf ${ENSPATH}/${memname}/restart/mesh_final.bin   $restart_path/mesh_${memname}.bin
        ln -sf ${ENSPATH}/${memname}/restart/mesh_final.dat   $restart_path/mesh_${memname}.dat
        if [ ${UPDATE} -eq 1 ]; then
            cd  ${FILTER}
            cdo merge reference_grid.nc  prior/$(printf "mem%.3d" $i).nc.analysis  ${memname}.nc.analysis         
            ln -sf ${FILTER}/${memname}.nc.analysis               $restart_path/${memname}.nc.analysis 
            ln -sf ${ENSPATH}/${memname}/WindPerturbation_${memname}.nc $restart_path/WindPerturbation_${memname}.nc  # must use copy, it will be copied again to work path. The one in work path will be updated by the program.
        fi  
    done  
#COMMENT
done

cp ${JOB_SETUP_DIR}/nohup.out ${OUTPUT_DIR}


# H=()
#   H+=("neXtSIM will provide mem%3d.nc in which all state variables will be on a curvilinear regular grid")
#   H+=("mem%3d.nc will be linked into the FILTER directory")
#   H+=("all \*.prm files will be modified by a shell script and linked into the FILTER directory")
#   H+=("enkf_prep enkf_calc, enkf_update will be linked into the FILTER directory")
#   H+=("observations in the assimilation cycle will be linked into the FILTER/obs directory")
#   H+=("mem%3d.nc.analysis will be written by enkf-c")