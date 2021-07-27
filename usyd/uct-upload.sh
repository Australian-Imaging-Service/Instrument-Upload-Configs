#!/bin/bash
##!/bin/bash -x
# U-CT upload workflow

# Sample path ./PROJECT_SUBJECT/2018-08-14_17h21_TB_N_70minPostIP_DataDdrive/Results/CT_2018-08-14_17h21_TB_N_70minPostIP_80um.nii
# Project = PROJECT
# Subject = SUBJECT
# Session = 2018-08-14_17h21_TB_N_70minPostIP_DataDdrive
# Date = 2018-08-14_17h21
# Acquisition Site = Sydney Imaging (static)

# Session level resources:
# Root level has the format of 2018-08-14_17h21_TB_N_70minPostIP_DataDdrive

# Result files are in Results directory at root level
# Any nii files in Results uploaded as they are
# Any log files in Results uploaded as they are

# Raw data includes any individual files and ct-data directory at root level
# Any raw data uploaded as rawdata.zip except ct-data/corr and ct-data/prev

# For server which doesn't have zip 
# yum install zip -y

# When data migration, DAYSWITHIN needs to set far back to include all old data

# BASEDIR=$(pwd)

if [[ $# -ne 3 ]]; then
    echo "Illegal number of parameters"
    echo "Usage: uct-debug.sh DATA_PATH TMP_DIR LAST_X_DAYS"
    exit 1
fi
# OIFS="$IFS"
# IFS=$'\n'

DEBUG=true
TMPUUID=$(uuidgen)

DATAPATH=${1}
TMPPATH=${2}/${TMPUUID}
LAST_X_DAYS=${3}
mkdir -p ${TMPPATH}
TARGETDIR=${DATAPATH}

for i in $(ls ${TARGETDIR}/); do
    MYPROJ=$(echo ${i} | cut -f1 -d'_')
    MYSUBJ=$(echo ${i} | cut -f2- -d'_')

    if [[ ${DEBUG} ]]; then
        echo Project ${MYPROJ} User ${MYSUBJ}
    fi
    cd ${TARGETDIR}/${i}

    for thisdir in $(ls -1 | grep '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]h[0-9][0-9][A-Za-z0-9_-.]*$'); do
        # MYSESSION=${thisdir}
        # MYSESSION=$(echo ${thisdir} | sed -e 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_[0-9]\{2\}h[0-9]\{2\}_//')
        MYSESSION=$(echo ${thisdir} | sed -e 's/\./_/g')
        MYDATE=${thisdir:0:10}
        MYTIME=${thisdir:11:5}
        MYSCAN=${thisdir}

        if ${DEBUG}; then
            VERBOSE="--verbose"
            echo Debug PROJ: ${MYPROJ} SUBJ: ${MYSUBJ}
            echo Debug SESS: ${MYSESSION} SCAN: ${MYSCAN}
            echo Debug DATE: ${MYDATE} TIME: ${MYTIME}
        fi

        fieldb64=$(echo '{"date":"'${MYDATE}'"}' | base64 -i)
        
        # Results nifti files
        echo ----upload nifti files-------------------------------------------
        resource=nifti
        for thisfile in $(find ${thisdir}/Results -name *.nii ! -name ".*" -mtime -${LAST_X_DAYS}); do 
            echo "xnat-uploader --project ${MYPROJ} --subject ${MYSUBJ} --session ${MYSESSION} --scan Results \
            --bsessionfields ${fieldb64} --bscanfields ${fieldb64} --timeout 3600 ${VERBOSE} \
            --datatype ct --resource ${resource} ./${thisfile}"
            xnat-uploader --project ${MYPROJ} --subject ${MYSUBJ} --session ${MYSESSION} --scan Results \
            --bsessionfields ${fieldb64} --bscanfields ${fieldb64} --timeout 3600 ${VERBOSE} \
            --datatype ct --resource ${resource} ./${thisfile}
        done
        
        # Results Log files
        echo ----upload log files---------------------------------------------
        resource=log
        for thisfile in $(find ${thisdir}/Results -name *.log ! -name ".*" -mtime -${LAST_X_DAYS}); do 
            echo "xnat-uploader --project ${MYPROJ} --subject ${MYSUBJ} --session ${MYSESSION} --scan Results \
            --bsessionfields ${fieldb64} --bscanfields ${fieldb64} --timeout 3600 ${VERBOSE} \
            --datatype ct --resource ${resource} ./${thisfile}"
            xnat-uploader --project ${MYPROJ} --subject ${MYSUBJ} --session ${MYSESSION} --scan Results \
            --bsessionfields ${fieldb64} --bscanfields ${fieldb64} --timeout 3600 ${VERBOSE} \
            --datatype ct --resource ${resource} ./${thisfile}
        done

        #Upload all raw data, exclude corr, prev
        echo ----upload all raw data-------------------------------------------
        resource=zip
        if [[ -d ./${thisdir}/ct-data ]]; then
            newfilecount=0
            newfilecount=$(find ${thisdir} -type f ! -path "${thisdir}/Results/*" ! -path "${thisdir}/ct-data/corr/*" ! -path "${thisdir}/ct-data/prev/*" ! -name ".*" -mtime -${LAST_X_DAYS} | wc -l)
            if [[ $newfilecount -ne 0 ]]; then
                tmpfilename=${TMPPATH}/${MYSESSION}.zip
                find ${thisdir} -type f ! -path "${thisdir}/Results/*" ! -path "${thisdir}/ct-data/corr/*" ! -path "${thisdir}/ct-data/prev/*" ! -name ".*" | zip -q ${tmpfilename} -@ > /dev/null
                echo "xnat-uploader --project ${MYPROJ} --subject ${MYSUBJ} --session ${MYSESSION} --scan Rawdata \
                --bsessionfields ${fieldb64} --bscanfields ${fieldb64} --timeout 3600 ${VERBOSE} \
                --datatype ct --resource ${resource} ${tmpfilename}"
                xnat-uploader --project ${MYPROJ} --subject ${MYSUBJ} --session ${MYSESSION} --scan Rawdata \
                --bsessionfields ${fieldb64} --bscanfields ${fieldb64} --timeout 3600 ${VERBOSE} \
                --datatype ct --resource ${resource} ${tmpfilename}
                rm ${tmpfilename}
            fi
        fi
    done
    # cd ${BASEDIR}
done

rmdir ${TMPPATH}
exit 0
