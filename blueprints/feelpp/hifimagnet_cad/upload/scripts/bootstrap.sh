#!/bin/bash -l

# set -euo pipefail
# set -x

# Custom logs
LOG_FILE=$0.log

echo "bootstrap" >> "${LOG_FILE}"
echo "parameters: $*" >> "${LOG_FILE}"

nargs=$#
echo "nargs: $nargs" >> "${LOG_FILE}"
echo "last arg: ${!nargs}" >> "${LOG_FILE}"

# params for singularity images:
# $1 - { get_input: sregistry_storage }
# $2 - { get_input: singularity_image_filename - aka collection/}
# $3 - { get_input: singularity_image_uri }
# $4 - { get_input: singularity_image_cleanup }
# $5 - { get_input: sregistry_client }
# $6 - { get_input: sregistry_secrets } 
# $7 - { get_input: sregistry_url }
# $8 - { get_input: sregistry_image } 

# params fo input data
# $9 - { get_input: mso4sc_datacatalogue_key }
# $10 - { get_input: mso4sc_dataset_model }

# input file
# $11 - {get_input: cadcfg}
# $12 - name of the job

export SREGISTRY_STORAGE=$1 >> "${LOG_FILE}"

IMAGE_NAME=$2
IMAGE_URI=$3
# IMAGE_CLEANUP=$4

export SREGISTRY_CLIENT=$5 >> "${LOG_FILE}"
export SREGISTRY_CLIENT_SECRETS=$6 >> "${LOG_FILE}"

SREGISTRY_URL=$7
SREGISTRY_IMAGE=$8

# Ckan:
DATASET=""
CATALOGUE_TOKEN=""
DATA=""

if [ "$nargs" -ge 10 ]; then
    DATASET=${10}
fi
if [ "$nargs" -ge 9 ]; then
    CATALOGUE_TOKEN=${9}
fi
if [ "$nargs" -ge 11 ]; then
    DATA=${11}
fi


# Singularity image retrieved from
# https://www.singularity-hub.org/collections/253

echo "CURRENT_WORKIR=$CURRENT_WORKDIR" >> "${LOG_FILE}"
echo "IMAGE_NAME=$IMAGE_NAME" >> "${LOG_FILE}"
echo "IMAGE_URI=$IMAGE_URI" >> "${LOG_FILE}"

echo "SREGISTRY_STORAGE=${SREGISTRY_STORAGE}" >> "${LOG_FILE}"
echo "SREGISTRY_URL=${SREGISTRY_URL}" >> "${LOG_FILE}"
echo "SREGISTRY_IMAGE=${SREGISTRY_IMAGE}" >> "${LOG_FILE}"

# Check if secrets exist
if [ ! -f "${SREGISTRY_CLIENT_SECRETS}" ]; then
    echo "No SRegistry secrets found: ${SREGISTRY_CLIENT_SECRETS}" >> "${LOG_FILE}"
    echo "You have to upload such file first on HPC resources" >> "${LOG_FILE}"
    exit 1
fi

if [ ! -d "${SREGISTRY_STORAGE}" ]; then
    mkdir -p "${SREGISTRY_STORAGE}"
fi

getimage(){

    local URI=$1
    URI_NAME=$(echo "${URI}" | tr '/' '-' |  tr ':' '-')

    echo "getimage: ${URI} (${SREGISTRY_STORAGE}/${URI_NAME})"
    
    # module should be optional:
    isSregistry=""
    isSingularity=""
    isModule=$(compgen -A function | grep  module)
    if [ "$isModule" != "" ]; then
	module load singularity >> "${LOG_FILE}"
    else
	isSregistry=$(which sregistry)
	isSingularity=$(which singularity)
	if  [ "$isSregistry" = "" ] &&  [ "$isSingularity" = "" ]; then
	    echo "either sregistry or singularity is mandatory: please install one of them" >> "${LOG_FILE}"
	    exit 1
	fi
    fi

    # Get Singularity image if not already installed
    if [ ! -f "${SREGISTRY_STORAGE}/${URI_NAME}".simg ]; then
	if  [ "$isSregistry" != "" ] && [ "${SREGISTRY_URL}" != "" ] && [ "${SREGISTRY_IMAGE}" != "" ]; then
	    echo "Get ${IMAGE} using sregistry-cli" >> "${LOG_FILE}"
	    # On Lnmci
	    sregistry pull "${URI}" >> "${LOG_FILE}" 2>&1
	    status=$?
	    if [ $status != "0" ]; then
		echo "sregistry pull ${URI}: FAILS" >> "${LOG_FILE}"
		exit 1
	    fi
	else
	    SREGISTRY_NAME=$(echo "${SREGISTRY_IMAGE}" | tr '/' '-' |  tr ':' '-')
	    if [ ! -f "${SREGISTRY_STORAGE}/${SREGISTRY_NAME}".simg ]; then
		echo "Get $SREGISTRY_IMAGE ($SREGISTRY_NAME) using intermediate shub://${SREGISTRY_URL}/${SREGISTRY_IMAGE}" >> "${LOG_FILE}"
		singularity run -B /mnt shub://"${SREGISTRY_URL}"/"${SREGISTRY_IMAGE}" --quiet pull "${SREGISTRY_IMAGE}" >> "${LOG_FILE}" 2>&1
		status=$?
		if [ $status != "0" ]; then
		    echo "singularity run -B /mnt shub://${SREGISTRY_URL}/${SREGISTRY_IMAGE} --quiet pull ${SREGISTRY_IMAGE}: FAILS" >> "${LOG_FILE}"
		    exit 1
		fi
	    fi
	    # On Cesga:
	    singularity run -B /mnt "${SREGISTRY_STORAGE}/${SREGISTRY_NAME}".simg --quiet pull "${URI}" >> "${LOG_FILE}" 2>&1
	    status=$?
	    if [ $status != "0" ]; then
		echo "singularity run -B /mnt ${SREGISTRY_STORAGE}/${SREGISTRY_NAME}.simg --quiet pull ${URI}: FAILS" >> "${LOG_FILE}"
		exit 1
	    fi
	fi
    fi
}

################################################################################
# see: https://github.com/MSO4SC/resources/blob/master/blueprint-examples/opm-flow-logger/scripts/singularity_bootstrap_run-flow-generic.sh
# add a "filters": [] within each filename
# eg:
# "filters": [
#     {pattern: "^================    End of simulation     ===============", severity: "OK",   progress: 100},
#     {pattern: "^Time step",  severity: "INFO"},
#     {pattern: "^Report step",  severity: "WARNING", progress: "+1"},
#     {pattern: "^[\\\\s]*[:|=]", verbosity: 2},
#     {pattern: "^Keyword", verbosity: 2},
#     {pattern: "[\\\\s\\\\S]*", verbosity: 1},
# ]
#
# Add logging part

if [ ! -f ${12}_logfilter.yaml ]; then
    JOB_LOG_FILTER_FILE="${12}_logfilter.yaml"
    read -r -d '' JOB_LOG_FILTER <<"EOF"
[   
    {
        "filename": "${12}.log",
        "filters": []
    },
]
EOF
    echo "${JOB_LOG_FILTER}" > $JOB_LOG_FILTER_FILE
    echo "[INFO] $(hostname):$(date) JOb log fiter: Created" >> "${LOG_FILE}"


    getimage "mso4sc/remotelogger-cli:latest" 
    status=$?
    if [ $status != "0" ]; then
	exit 1
    fi

    # singularity pull --name remotelogger-cli.simg shub://sregistry.srv.cesga.es/mso4sc/remotelogger-cli:latest
    echo "[INFO] $(hostname):$(date) Remotelogger-cli: Downloaded"  >> "${LOG_FILE}"
    echo "[INFO] $(hostname):$(date) Bootstrap finished succesfully!" >> "${LOG_FILE}"
fi

##################

getimage "${IMAGE_URI}"
status=$?
if [ $status != "0" ]; then
    exit 1
fi

# Get data from ckan
echo "DATASET=${DATASET}" >> "${LOG_FILE}"
echo "CATALOGUE_TOKEN=${CATALOGUE_TOKEN}" >> "${LOG_FILE}"
echo "DATA=${DATA}" >> "${LOG_FILE}"

ARCHIVE=${DATASET}
ARCHIVE=$(echo "$ARCHIVE" | perl -pi -e "s|.*/||")
isstatus=$?
if [ "$isstatus" == 1 ]; then
    exit 1
fi    
echo "ARCHIVE=$ARCHIVE"  >> "${LOG_FILE}"

OPTIONS=""
if [ "$CATALOGUE_TOKEN" ]; then
    OPTIONS="-H \"Authorization: ${CATALOGUE_TOKEN}\""
fi

if [ "x$DATASET" != "x" ] && [ "$DATASET" != "None" ]; then
    isDownloaded=1
    echo "curl $OPTIONS $DATASET -o $ARCHIVE" >> "${LOG_FILE}"
    if [ "$CATALOGUE_TOKEN" ]; then
	curl -H "Authorization: ${CATALOGUE_TOKEN}" "$DATASET" -o "$ARCHIVE"
	isDownloaded=$?
    else
	curl "$DATASET" -o "$ARCHIVE"
	isDownloaded=$?
    fi
    if [ "$isDownloaded" == 1 ]; then
	echo "curl $OPTIONS $DATASET -o $ARCHIVE : FAILS" >> "${LOG_FILE}"
        exit 1
    fi
    
    TYPE=$(file "$ARCHIVE" | perl -pi -e "s|$ARCHIVE: ||")
    echo "type($ARCHIVE)=$TYPE"  >> "${LOG_FILE}"

    tar zxvf "$ARCHIVE" >> "${LOG_FILE}"
    status=$?
    if [ $status != "0" ]; then
	echo "tar zxvf $ARCHIVE : FAILS" >> "${LOG_FILE}"
	exit 1
    fi

    # check if input file is present
    if [ ! -f "$DATA" ]; then
	echo "$DATA: no such file in dataset $DATASET"
	exit 1
    fi
fi

# ctx logger info "Some logging"
# # read access
# ctx node properties tasks
