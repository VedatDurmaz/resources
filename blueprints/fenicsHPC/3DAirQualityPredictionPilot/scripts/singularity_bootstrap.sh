#!/bin/bash -l

module load singularity/2.4.2
module load git

echo $1 > bootstrap_log
echo $2 >> bootstrap_log
echo $3 >> bootstrap_log
echo $4 >> bootstrap_log
echo $5 >> bootstrap_log
echo $6 >> bootstrap_log
echo $7 >> bootstrap_log
echo $8 >> bootstrap_log
echo $9 >> bootstrap_log
echo $10 >> bootstrap_log
echo $11 >> bootstrap_log

REMOTE_URL=${11}
IMAGE_URI=$1
IMAGE_NAME=$2

# cd $CURRENT_WORKDIR ## not needed, already started there
singularity pull --name $IMAGE_NAME $IMAGE_URI

git clone https://bitbucket.org/fenics-hpc/unicorn.git

cd unicorn
git fetch --all
git checkout 3DAirQualityPredictionPilot

cd 3DAirQualityPredictionPilot
if [ ${REMOTE_URL} != "NONE" ] && [ ${REMOTE_URL}x != "x" ] 
then
	wget $REMOTE_URL
	ARCHIVE=$(basename $REMOTE_URL)
	tar zxvf $ARCHIVE
else
	wget www.csc.kth.se/~ncde/meshS.tar.gz
	tar -xvzf meshS.tar.gz
fi


echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > parameters.xml
echo -e "" >> parameters.xml
echo -e "<dolfin xmlns:dolfin=\"http://fenicsproject.org\">" >> parameters.xml
echo -e "  <parameters name=\"parameters\">" >> parameters.xml 
echo -e "    <parameter name=\"T\" type=\"real\" value=\"$3\"/>" >> parameters.xml
echo -e "    <parameter name=\"alpha\" type=\"real\" value=\"$4\"/>" >> parameters.xml
echo -e "    <parameter name=\"cfl_target\" type=\"real\" value=\"$5\"/>" >> parameters.xml
echo -e "    <parameter name=\"trip_factor\" type=\"real\" value=\"$6\"/>" >> parameters.xml
echo -e "    <parameter name=\"discrete_tolerance\" type=\"real\" value=\"$7\"/>" >> parameters.xml
echo -e "    <parameter name=\"Uinx\" type=\"real\" value=\"$8\"/>" >> parameters.xml
echo -e "    <parameter name=\"Uiny\" type=\"real\" value=\"$9\"/>" >> parameters.xml
echo -e "    <parameter name=\"Uinz\" type=\"real\" value=\"${10}\"/>" >> parameters.xml
echo -e "  </parameters>" >> parameters.xml
echo -e "</dolfin>" >> parameters.xml



cd ../..


