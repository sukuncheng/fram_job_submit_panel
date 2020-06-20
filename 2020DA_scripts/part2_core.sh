#!/bin/bash
# #------ PART 1: ensemble forecast ------------
# echo "ensemble runs start"
# for (( mem=1; mem<=${ESIZE}; mem++ )); do
#     cd ${ENSPATH}/${ENSEMBLE[${mem}]}  #MEMPATH
#     # update time_init per time step
#     sed -i "s;^time_init=.*$;time_init="${time_init}";g" ./nextsim.cfg
#     sed -i "s;^restart_from_analysis=.*$;restart_from_analysis="${restart_from_analysis}";g" ./nextsim.cfg 
   
#     # submit job        
#     source $ENVFRAM/run.fram.sh ./nextsim.cfg 1 -e $ENVFRAM/nextsim.src       
#     # barrier of max instants
#     job_list=$(squeue -u chengsukun)
#     XPID=$(grep -o chengsuk <<<$job_list |wc -l)  # number of current running jobs
#     echo $XPID    
#     while [[ $XPID -ge $maximum_instants ]]; do # maximum of running instants
#         sleep 20
#         job_list=$(squeue -u chengsukun)
#         XPID=$(grep -o chengsuk <<<$job_list |wc -l)  # number of current running jobs
#     done        
# done # ensemble loop
# # wait for finish of all ensemble simulations
# while [[ $XPID -ge 1 ]]; do #
#     sleep 20
#     job_list=$(squeue -u chengsukun)
#     XPID=$(grep -o chengsuk <<<$job_list |wc -l)  # number of current running jobs
# done  
# echo "ensemble forecast done" 
# #    . run.fram.sh $cfg 1 -e ~/nextsim.ensemble.src                  
# #    1 - copy nextsim.exec from NEXTSIMDIR/model/bin to current path
# #   -t test run without submit to fram
# #   -e ~/nextsim.ensemble.src      # envirmonental variables


#-------  PART 2: enkf - UPDATE ENSEMBLE  ---------
if [ ${UPDATE} -gt 0 ]; then
    echo "link mem00*/prior.nc to /filter/prior/mem00*.nc"
    for (( mem=1; mem<=${ESIZE}; mem++ )); do
        mv  ${ENSPATH}/${ENSEMBLE[${mem}]}/prior.nc \
            ${FILTER}/prior/${ENSEMBLE[${mem}]}'.nc'
    done
    #
    cd $FILTER
    echo "link observations to ENSPATH/filter/obs, and obs.prm"
    tind=${duration} # $(echo "(${duration}+1)/1"|bc)
    #  for (( tind = 0; tind < ${???}; tind++ )); do
    SMOSOBS=${OBSNAME_PREFIX}$(date +%Y%m%d -d "${time_init} + ${tind} day")_$(date +%Y%m%d -d "${time_init} + ${tind+7} day")${OBSNAME_SUFFIX}.nc
    if [ -f ${SMOSOBS} ]; then
        sed -i "s;^.*FILE.*$;FILE ="${SMOSOBS}";g"  obs.prm 
    else
        echo "WARNING: ${SMOSOBS} is not found. "
    fi
    sed -i "s;^.*FILE.*$;FILE =/cluster/home/chengsukun/src/nextsim/data/CS2_SMOS_v2.1/W_XX-ESA,SMOS_CS2,NH_25KM_EASE2_20181105_20181111_r_v201_01_l4sit.nc;g"  obs.prm 

    #  done   
    echo "run enkf, outputs: $filter/prior/*.nc.analysis, $filter/enkf.out" 
    make clean #must clean previous results like observation*.nc
#    make enkf  ########$NEXTSIMDIR/data:/data##### change data address in .prm files
./enkf_prep --no-superobing enkf.prm 2>&1 | tee prep.out
./enkf_calc --use-rmsd-for-obsstats enkf.prm 2>&1 | tee calc.out
./enkf_update --calculate-spread --output-increment enkf.prm 2>&1 | tee update.out
    #
    echo "merge reference_grid.nc and *.nc.analysis /NEXTSIMDIR/data/"
    # nextsim will read /NEXTSIMDIR/data/**.nc.analysis data in next DA cycle
    mkdir -p ${ENSPATH}/DAdata/${time_init}  # save analysis results to DAdata
    rm ${NEXTSIMDIR}/data/*.nc.analysis
    for (( mem=1; mem<=${ESIZE}; mem++ )); do
        cdo merge ${FILTER}/reference_grid.nc  ${FILTER}/prior/${ENSEMBLE[${mem}]}.nc.analysis ${NEXTSIMDIR}/data/${ENSEMBLE[${mem}]}.nc.analysis
        cp ${NEXTSIMDIR}/data/${ENSEMBLE[${mem}]}.nc.analysis ${ENSPATH}/DAdata/${time_init}/${ENSEMBLE[${mem}]}.nc.analysis
    done
    echo "enkf done"
fi #UPDATE 