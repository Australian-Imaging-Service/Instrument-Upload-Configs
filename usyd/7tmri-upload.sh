#!/bin/bash

# Requirement: dcmtk

if [[ $# -ne 4 ]]; then
    echo "Illegal number of parameters"
    echo "Usage: 7tmri-upload_makeup.sh CONFIG_PATH DATA_PATH LOG_PATH NEWERTHAN"
    exit 1
fi

CONFIG_PATH=${1}
DATA_PATH=${2}
LOG_PATH=${3}
NEWERTHAN=${4}

exec > "${LOG_PATH}/7T$(date +%Y%m%d%H%m).log" 2>&1
DEFAULTPROJECT="7T_Uncat"
DEFAULTSUBJECT="Preclinical7T_Uncategorised_Images"
VERBOSE='--verbose'

## Crete Lockfile to avoid multiple scripts running at the same time
LCKFILE="/tmp/Lockfile_DailyUpload"
if [ -e ${LCKFILE} ]; then
   echo "${LCKFILE} exists, exiting"
   echo "Lockfile contains:"
   cat ${LCKFILE}
   date
   exit 1
fi
# create a lock file so only one of these runs at a time
echo $$ > ${LCKFILE}

# go to where the data directory is
cd $DATA_PATH
basepath=`pwd`

for i in $(ls -1 Data); do
    # echo $i
    cd ${basepath}/Data/${i}
    THISSUBJECTID=${i}
    echo "Analyzing suject ID: ${THISSUBJECTID}"

    # if both dicom and spect exist, then special case. 
    # Cycle through every session and compare the two.
    # If dicom exists, then send to label within
    # If no dicom exists, default project
    if [[ -d ./DICOM/ ]] && [[ -d ./Spectroscopy ]]; then
        # Combination of dicom/spect
        # Cycle through all scans in spectroscopy
        echo "Both Dicom and Spectroscopy data found for subject ID: ${THISSUBJECTID}"
       
        for THISSESSION in $(ls ./Spectroscopy/); do

            # example: 2654_20200408
            # On Mac
            #XNATSESSION=${THISSESSION}_$(stat -f "%Sm" -t "%Y.%m.%d" ./Spectroscopy/${THISSESSION} | sed "s/\.//g")
            XNATSESSION=${THISSESSION}_$(stat -c %y ./Spectroscopy/${THISSESSION} | cut -f 1 -d " " | sed -r "s/-//g")
            # Check for dicom
            if [[ -d ./DICOM/${THISSESSION} ]]; then
                mysample=$(xnat-uploader-dicom --project ${DEFAULTPROJECT} --subject ${DEFAULTSUBJECT} \
                --splitlabel "(0010,0010)" --splitsample ./DICOM/${THISSESSION}/)

                ## For blank DICOM folder situation, the xnat will send to default project subject
                ## Otherwise, project subject is set based on 0010,0010
                ## FX: DICOM folder seems always empty???
                if [[ ! -z ${mysample} ]]; then
                    THISPROJECT=$(echo ${mysample} | jq .project | tr -d '"')
                    THISSUBJECT=$(echo ${mysample} | jq .subjectlabel | tr -d '"')
                    echo Found DICOM, project:${THISPROJECT}, subject:${THISSUBJECT}
                else
                    THISPROJECT=${DEFAULTPROJECT}
                    THISSUBJECT=${THISSUBJECTID}
                fi
            else
                THISPROJECT=${DEFAULTPROJECT}
                THISSUBJECT=${THISSUBJECTID}
            fi

            # Push spectrography from non-dicom data by parsing json ingestion map
            echo ">>> xnat-uploader ${VERBOSE} -i ${CONFIG_PATH}/7tmri-spec.json --project ${THISPROJECT} \
                  --subject ${THISSUBJECT} --session ${XNATSESSION} --newerthan ${NEWERTHAN} ./Spectroscopy/${THISSESSION}"
            xnat-uploader ${VERBOSE} -i ${CONFIG_PATH}/7tmri-spec.json --project ${THISPROJECT} \
              --subject ${THISSUBJECT} --session ${XNATSESSION} --newerthan ${NEWERTHAN} ./Spectroscopy/${THISSESSION}
        done

        echo "For DICOM folder now"
        for THISSESSION in $(ls ./DICOM/); do
            mysample=$(xnat-uploader-dicom --project ${DEFAULTPROJECT} --subject ${DEFAULTSUBJECT} \
                     --splitlabel "(0010,0010)" --splitsample ./DICOM/${THISSESSION}/)

            ## For the blank DICOM folder situation, the xnat will send to default project subject
            ## FX: DICOM folder seems always empty???
            if [[ ! -z ${mysample} ]]; then
                THISPROJECT=$(echo ${mysample} | jq .project | tr -d '"')
                THISSUBJECT=$(echo ${mysample} | jq .subjectlabel | tr -d '"')
                echo Found DICOM, project:${THISPROJECT}, subject:${THISSUBJECT}
            else
                THISPROJECT=${DEFAULTPROJECT}
                THISSUBJECT=${THISSUBJECTID}
            fi

            XNATSESSION=''
            # Build XNAT Session value
            if [ -z $XNATSESSION ]; then
                for THISSCAN in $(ls ./DICOM/${THISSESSION}/1/); do 
                    date=$(dcmdump +P 0008,0020 ./DICOM/${THISSESSION}/1/${THISSCAN} | sed -n 's/.*\[\(.*\)\].*/\1/p')
                    XNATSESSION=${THISSESSION}_${date}
                    if [ ! -z $XNATSESSION ]; then
                        break
                    fi
                done
            fi 

            # Upload dicom
            echo ">>> xnat-uploader ${VERBOSE} -i ${CONFIG_PATH}/7tmri-dcm.json --project ${THISPROJECT} \
                    --subject ${THISSUBJECT} --session ${XNATSESSION} --newerthan ${NEWERTHAN} ./DICOM/${THISSESSION}/"
            xnat-uploader ${VERBOSE} -i ${CONFIG_PATH}/7tmri-dcm.json --project ${THISPROJECT} \
                --subject ${THISSUBJECT} --session ${XNATSESSION} --newerthan ${NEWERTHAN} ./DICOM/${THISSESSION}/
        done

        # Next in loop, no other combinations possible. this is different now 20200208
        continue
    fi

    # TODO: need to find the Subject ID which contains only Spectrocoty subfolder and test
    echo "Only Spectroscopy folder existed for subject ID: ${THISSUBJECTID}"
    if [[ -d ./Spectroscopy ]]; then
        # Just spectroscopy, upload and continue
        echo "Spectroscopy data found for Subject ID ${THISSUBJECTID}, filing to ${DEFAULTPROJECT}/${DEFAULTSUBJECT}"
        for THISSESSION in $(ls ./Spectroscopy/); do
            # On Mac
            #XNATSESSION=${THISSESSION}_$(stat -f "%Sm" -t "%Y.%m.%d" ./Spectroscopy/${THISSESSION} | sed "s/\.//g")
            XNATSESSION=${THISSESSION}_$(stat -c %y ./Spectroscopy/${THISSESSION} | cut -f 1 -d " " | sed -r "s/-//g")
            # Push spectrography from non-dicom data by parsing json ingestion map
            echo ">>>xnat-uploader ${VERBOSE} -i ${CONFIG_PATH}/7tmri-spec.json --project ${DEFAULTPROJECT} \
            --subject ${THISSUBJECTID} --session ${XNATSESSION} --newerthan ${NEWERTHAN} ./Spectroscopy/"
            xnat-uploader ${VERBOSE} -i ${CONFIG_PATH}/7tmri-spec.json --project ${DEFAULTPROJECT} \
            --subject ${THISSUBJECTID} --session ${XNATSESSION} --newerthan ${NEWERTHAN} ./Spectroscopy/
        done
    fi

    # Some combination of dicom/image/mrd
    echo "Only DICOM folder existed for subject ID: ${THISSUBJECTID}"
    if [[ -d ./DICOM/ ]]; then
        echo "xnat-uploader-dicom --project ${DEFAULTPROJECT} --subject ${DEFAULTSUBJECT} \
         --splitlabel \"(0010,0010)\" --splitsample ./DICOM/"
        mysample=$(xnat-uploader-dicom --project ${DEFAULTPROJECT} --subject ${DEFAULTSUBJECT} \
         --splitlabel "(0010,0010)" --splitsample ./DICOM/)
        ### This is to handle the the blank DICOM folder situation, the xnat will send to default project subject
        if [[ ! -z ${mysample} ]]; then
            THISPROJECT=$(echo ${mysample} | jq .project | tr -d '"')
            THISSUBJECT=$(echo ${mysample} | jq .subjectlabel | tr -d '"')
            echo Found DICOM, project:${THISPROJECT}, subject:${THISSUBJECT}
        else
            THISPROJECT=${DEFAULTPROJECT}        
            THISSUBJECT=${THISSUBJECTID}            
        fi
    else
        THISPROJECT=${DEFAULTPROJECT}
        THISSUBJECT=${THISSUBJECTID}
    fi
    
    echo "Subject ID:${i}, PROCESSING mixed folder w/ ${THISPROJECT} ${THISSUBJECT}"
    if [[ -d ./DICOM/ ]]; then
        echo ${i}: DICOM
        # Spider dicom and use special tag for project/subject.
        # Fall back to default project UPLOADTEST and subject DEFAULT if no tag is present
        for THISSESSION in $(ls ./DICOM/); do
            XNATSESSION=''
            # Build XNAT Session value
            if [ -z $XNATSESSION ]; then
                for THISSCAN in $(ls ./DICOM/${THISSESSION}/1/); do 
                    date=$(dcmdump +P 0008,0020 ./DICOM/${THISSESSION}/1/${THISSCAN} | sed -n 's/.*\[\(.*\)\].*/\1/p')
                    XNATSESSION=${THISSESSION}_${date}
                    if [ ! -z $XNATSESSION ]; then
                        break
                    fi
                done
            fi 
            # Push spectrography from non-dicom data by parsing json ingestion map
            echo ">>>xnat-uploader ${VERBOSE} --deletesessions -i ${CONFIG_PATH}/7tmri-dcm.json --project ${THISPROJECT} \
                  --subject ${THISSUBJECT} --session ${XNATSESSION} --newerthan ${NEWERTHAN} ./DICOM/${THISSESSION}"
            xnat-uploader ${VERBOSE} -i ${CONFIG_PATH}/7tmri-dcm.json --project ${THISPROJECT} \
            --subject ${THISSUBJECT} --session ${XNATSESSION} --newerthan ${NEWERTHAN} ./DICOM/${THISSESSION}

            if [[ -d ../../MRD/${THISSUBJECTID}/${THISSESSION} ]]; then
                echo ${i}: MRD
                # Push MRD files from mrd from non-dicom data by parsing json ingestion map
                echo ">>>xnat-uploader ${VERBOSE} -i ${CONFIG_PATH}/7tmri-mrd.json --project ${THISPROJECT} \
                     --subject ${THISSUBJECT} --session ${XNATSESSION} --newerthan ${NEWERTHAN} ../../MRD/${THISSUBJECTID}/${THISSESSION}"
                xnat-uploader ${VERBOSE} -i ${CONFIG_PATH}/7tmri-mrd.json --project ${THISPROJECT} \
                --subject ${THISSUBJECT} --session ${XNATSESSION} --newerthan ${NEWERTHAN} ../../MRD/${THISSUBJECTID}/${THISSESSION}
            else
                echo "Alert: The Dicom folder has no corresponding MRD folder"
            fi

            # no need to upload ./Image
        done
    fi

done

echo Done

# Remove Lockfile in the end 
rm -f ${LCKFILE}
