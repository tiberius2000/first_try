#! /bin/ksh

####################################################
# Name: Auto-Deploy				   				   #
# Author: Informatica Dude					       #
# Date: 11/09/2012				                   #
# Purpose: Read object names from file, add to	   #
# deployment group, and deploy automatically	   #
####################################################
# Created By: Todd Routledge 			           #
# Date: 11/9/2012				                   #
####################################################

# Define Variables

SRC_REPO=$1
TGT_REPO=$2
DEPLOY_FILE_NME=$3
DEPLOY_SCRIPT_LOC=$4
FOLDER_LIST=$DEPLOY_SCRIPT_LOC/Informatica_FolderList.dat
INFA_DEPLOY_LOC=$DEPLOY_SCRIPT_LOC/INFADeployment
DEPLOY_FILE_LOC=$INFA_DEPLOY_LOC/Objects
DEPLOY_FILE_ARCH_LOC=$INFA_DEPLOY_LOC/Objects/Archive
XML_FILE_LOC=$INFA_DEPLOY_LOC/XML
TMP_FILE_LOC=$INFA_DEPLOY_LOC/tmp
LOG_FILE_LOC=$INFA_DEPLOY_LOC/Logs

LOG_DATE=`date`
CUR_TIMESTAMP=`date +%Y%m%d%H%M%S`


#Determine SRC and TGT repository UID and PWD
if [[ $SRC_REPO = "TEST" ]] then
	SRC_UID="TEST_PMREP"
	SRC_PWD="test_pwx39"
elif [[ $SRC_REPO = "UAT" ]] then
	SRC_UID="UAT_PMREP"
	SRC_PWD="uat_pmrepu"
elif [[ $SRC_REPO = "PROD" ]] then
	SRC_UID="PROD_PMREP"
	SRC_PWD="PROD_PMREPb"
elif [[ $SRC_REPO = "VCT" ]] then
	SRC_UID="VCT_PMREP"
	SRC_PWD="vct_pwx39"
else
	SRC_UID=""
	SRC_PWD=""
fi

if [[ $TGT_REPO = "TEST" ]] then
	TGT_UID="TEST_PMREP"
	TGT_PWD="test_pwx39"
elif [[ $TGT_REPO = "UAT" ]] then
	TGT_UID="UAT_PMREP"
	TGT_PWD="uat_pmrepu"
elif [[ $TGT_REPO = "PROD" ]] then
	TGT_UID="PROD_PMREP"
	TGT_PWD="PROD_PMREPb"
elif [[ $TGT_REPO = "VCT" ]] then
	TGT_UID="VCT_PMREP"
	TGT_PWD="vct_pwx39"
else
	TGT_UID=""
	TGT_PWD=""
fi

#Set SRC_HOST/PORT variable (identifies the the source repository domain

if [[ $SRC_REPO = "TEST" || $SRC_REPO = "UAT" || $SRC_REPO = "VCT" ]] then
	    SRC_HOST="oratst01"
	    SRC_PORT="9005"
elif [[ $SRC_REPO = "PROD" ]] then
		SRC_HOST="oraprd01"
	    SRC_PORT="9005"
else
	SRC_DOMAIN="ERROR"
fi

#Set SRC_HOST/PORT variable (identifies the the source repository domain

if [[ $TGT_REPO = "TEST" || $TGT_REPO = "UAT" || $TGT_REPO = "VCT" ]] then
		TGT_HOST="oratst01"
		TGT_PORT="9005"
elif [[ $TGT_REPO = "PROD" ]] then
		TGT_HOST="oraprd01"
	    TGT_PORT="9005"
else
	TGT_DOMAIN="ERROR"
fi

#Test file entry for target environment and deployment status
function TestFileEntryTgtEnv
{
integer REC_CNT=0
while IFS=, read Folder ObjectName ObjectType Dependency QC Release DeployStatus
do
	if [[ $DeployStatus = "D" ]] then
		 REC_CNT=REC_CNT+1
	else
		if [[ $DeployStatus != "D" ]] then
			echo "\n$ObjectName of $ObjectType in $Folder for QC${QC}_REL${Release} with a target environment of $TargetEnv will not be added to a deployment group..." >> $LOG_FILE_NAME
			echo "\nThe file entry has a DeployStatus of X. It must be D to be added to a deployment group..." >> $LOG_FILE_NAME
		fi
	fi

	if [[ $REC_CNT -eq 0 ]] then
		echo "\nNone of the records in the DeploymentObjects_WF.dat file meet the criteria to be processed..." >> $LOG_FILE_NAME
		exit 0
	fi
done< $DEPLOY_FILE_LOC/$DEPLOY_FILE_NME


}

# Connect to the repository
function ConnectRepository
{
REPO=$1
HOST=$2
PORT=$3
UID=$4
PWD=$5

  echo "\nConnecting to INFA Repository..." >> $LOG_FILE_NAME
  pmrep connect -r $REPO -h $HOST -o $PORT -n $UID -x $PWD  >> $LOG_FILE_NAME

  INFA_RETURN_CODE=$?

   if [[ $INFA_RETURN_CODE -ne 0 ]] then
		echo "\nFailed to connect to INFA Repository..." >> $LOG_FILE_NAME
		exit 1
	else
		echo "\nSuccessfully connected to INFA Repository..." >> $LOG_FILE_NAME
  fi
}

function CreateLabel
{
while IFS=, read Folder ObjectName ObjectType Dependency QC Release DeployStatus
do
	if [[ $DeployStatus = "D" ]] then
		integer LABEL_COUNTER=0
		pmrep listobjects -o label -c "" |sed -e 's/label//' > $TMP_FILE_LOC/SrcLabel.lst

		LABEL_NAME="lbl_REL${Release}_QC${QC}_${CUR_TIMESTAMP}"
		#echo $LABEL_NAME
			while IFS=, read LblNme
				do
					if [[ $LABEL_NAME = $LblNme ]] then
						LABEL_COUNTER=$LABEL_COUNTER+1
					fi
			done < $TMP_FILE_LOC/SrcLabel.lst

		if [[ $LABEL_COUNTER -eq 0 ]] then
			pmrep createlabel -a ${LABEL_NAME} >> $LOG_FILE_NAME
			echo "\nLabel ${LABEL_NAME} has been created in the $SRC_REPO repository..." >> $LOG_FILE_NAME
		else
			echo "\nLabel REL${Release}/QC${QC} already exists..." >> $LOG_FILE_NAME
		fi
	fi


	#rm $TMP_FILE_LOC/SrcLabel.lst
done < $DEPLOY_FILE_LOC/$DEPLOY_FILE_NME
}

function CreateDeploymentGroup
{
set -A group
integer groupindex=0

while IFS=, read Folder ObjectName ObjectType Dependency QC Release DeployStatus
do
	if [[ $DeployStatus = "D" ]] then
		integer GROUP_COUNTER=0

		pmrep listobjects -o deploymentgroup -c "" |sed -e 's/deployment_group//' > $TMP_FILE_LOC/DplGroup.grp

		GROUP_NAME="dpl_REL${Release}_QC${QC}_${CUR_TIMESTAMP}"
		#echo $GROUP_NAME
			while IFS=, read GrpNme
				do
					if [[ $GROUP_NAME = $GrpNme ]] then
						GROUP_COUNTER=$GROUP_COUNTER+1
					fi
			done < $TMP_FILE_LOC/DplGroup.grp
		#echo $GROUP_COUNTER
		if [[ $GROUP_COUNTER -eq 0 ]] then
			pmrep createdeploymentgroup -p ${GROUP_NAME} -t static >> $LOG_FILE_NAME
			group[groupindex]=$GROUP_NAME
			groupindex=$groupindex+1
			echo "\nDeployment Group ${GROUP_NAME} has been created in $SRC_REPO repository..." >> $LOG_FILE_NAME
		else
			echo "\nREL${Release}_QC${QC} is associated with more than one entry in the file. Deployment group already exists..." >> $LOG_FILE_NAME
		fi
	fi
	#set | grep group
	#rm $TMP_FILE_LOC/DplGroup.grp
done < $DEPLOY_FILE_LOC/$DEPLOY_FILE_NME
}

function Apply_Label_Add_to_Group
{
set -A fail
integer failindex=0

while IFS=, read Folder ObjectName ObjectType	Dependency QC Release DeployStatus
do
	if [[ $DeployStatus = "D" ]] then
		PROCESS_FLG="TRUE"
		LABEL_NAME="lbl_REL${Release}_QC${QC}_${CUR_TIMESTAMP}"
		GROUP_NAME="dpl_REL${Release}_QC${QC}_${CUR_TIMESTAMP}"

				for i in ${fail[@]}
					do
						if [[ $LABEL_NAME = $i ]] then
						PROCESS_FLG="FALSE"
						fi
					done
					#echo $PROCESS_FLG

					if [[ $PROCESS_FLG = "TRUE" ]] then
						#echo "PROCESSING"
						pmrep listobjectdependencies -n $ObjectName -o $ObjectType -f "$Folder" -p $ObjectType -u $TMP_FILE_LOC/ObjectDep.lst >> $ LOG_FILE_NAME

	##INFA_RETURN_CODE=$?

###	if [[ $INFA_RETURN_CODE -ne 0 ]] then
##			fail[failindex]=$LABEL_NAME
####echo "\nUnable to list object dependencies for ${Folder}.${ObjectName}..." >> $LOG_FILE_NAME
####	echo "\nNo further processing will occur for objects related to REL${Release}_QC${QC}..." >> $LOG_FILE_NAME
####	echo "\nPerforming cleanup for objects related to REL${Release}_QC${QC}..." >> $LOG_FILE_NAME
####	pmrep deletelabel -a $LABEL_NAME -f >> $LOG_FILE_NAME
####	echo "\nLabel $LABEL_NAME has been deleted from the $SRC_REPO repository" >> $LOG_FILE_NAME
####	pmrep deletedeploymentgroup -p $GROUP_NAME -f >> $LOG_FILE_NAME
####	echo "\nDeployment group $GROUP_NAME has been deleted from the $SRC_REPO repository" >> $LOG_FILE_NAME
####		continue
####		else
####	echo "\nSuccessfully listed object dependencies for ${Folder}.${ObjectName}..." >> $LOG_FILE_NAME
#### fi


						pmrep applylabel -a $LABEL_NAME -n $ObjectName -o $ObjectType -f "$Folder" >> $LOG_FILE_NAME

						INFA_RETURN_CODE=$?

						if [[ $INFA_RETURN_CODE -ne 0 ]] then
							fail[failindex]=$LABEL_NAME
							failindex=$failindex+1
							echo "\nUnable to apply labels to ${Folder}.${ObjectName}..." >> $LOG_FILE_NAME
							echo "\nNo further processing will occur for objects related to REL${Release}_QC${QC}..." >> $LOG_FILE_NAME
							echo "\nPerforming cleanup for objects related to REL${Release}_QC${QC}..." >> $LOG_FILE_NAME
							pmrep deletelabel -a $LABEL_NAME -f >> $LOG_FILE_NAME
							echo "\nLabel $LABEL_NAME has been deleted from the $SRC_REPO repository" >> $LOG_FILE_NAME
							pmrep deletedeploymentgroup -p $GROUP_NAME -f >> $LOG_FILE_NAME
							echo "\nDeployment group $GROUP_NAME has been deleted from the $SRC_REPO repository" >> $LOG_FILE_NAME
							continue
						else
							echo "\nSuccessfully applied label $LABEL_NAME to for ${Folder}.${ObjectName}..." >> $LOG_FILE_NAME
						fi

						pmrep addtodeploymentgroup -p $GROUP_NAME -n $ObjectName -o $ObjectType -f "$Folder" -d "non-reusable" >> $LOG_FILE_NAME

						INFA_RETURN_CODE=$?

						if [[ $INFA_RETURN_CODE -ne 0 ]] then
							fail[failindex]=$LABEL_NAME
							failindex=$failindex+1
							echo "\nUnable to add ${Folder}.${ObjectName} to deployment group $GROUP_NAME..." >> $LOG_FILE_NAME
							echo "\nNo further processing will occur for objects related to REL${Release}_QC${QC}..." >> $LOG_FILE_NAME
							echo "\nPerforming cleanup for objects related to REL${Release}_QC${QC}..." >> $LOG_FILE_NAME
							pmrep deletelabel -a $LABEL_NAME -f >> $LOG_FILE_NAME
							echo "\nLabel $LABEL_NAME has been deleted from the $SRC_REPO repository" >> $LOG_FILE_NAME
							pmrep deletedeploymentgroup -p $GROUP_NAME -f >> $LOG_FILE_NAME
							echo "\nDeployment group $GROUP_NAME has been deleted from the $SRC_REPO repository" >> $LOG_FILE_NAME
						else
							echo "\nSuccessfully added ${Folder}.${ObjectName} to deployment group $GROUP_NAME..." >> $LOG_FILE_NAME
						fi
					fi
	fi
done < $DEPLOY_FILE_LOC/$DEPLOY_FILE_NME

#set | grep fail
#set | grep duplicate
}

function CreateXMLFile
{
FILE_NAME=$1
TGT_LABEL_NAME=$2
PREV_FOLDER = ''
integer REC_CNT=0

  XMLFILE=/home/dwetl/scripts/INFADeployment/XML/$FILE_NAME.xml
  echo '<?xml version="1.0" encoding="UTF-8"?>' > $XMLFILE
  echo "<!DOCTYPE DEPLOYPARAMS SYSTEM \"$INFA_HOME/server/bin/depcntl.dtd\">" >> $XMLFILE
  echo '<DEPLOYPARAMS DEFAULTSERVERNAME = ""' >> $XMLFILE
  echo '   COPYPROGRAMINFO="YES"' >> $XMLFILE
  echo '   COPYMAPVARPERVALS="NO"' >> $XMLFILE
  echo '   COPYWFLOWVARPERVALS="NO"' >> $XMLFILE
  echo '   COPYWFLOWSESSLOGS="NO"' >> $XMLFILE
  echo '   COPYDEPENDENCY="NO"' >> $XMLFILE
  echo '   LATESTVERSIONONLY="YES"' >> $XMLFILE
  echo '   RETAINGENERATEDVAL="NO"' >> $XMLFILE
  echo '   RETAINSERVERNETVALS="NO"' >> $XMLFILE
  echo '   DEPLOYTIMEOUT="-1">' >> $XMLFILE
  echo '<DEPLOYGROUP CLEARSRCDEPLOYGROUP="NO">' >> $XMLFILE

#  while IFS=, read Folder ObjectName ObjectType	Dependency QC Release DeployStatus
  while read Folder
  do
			 echo " <OVERRIDEFOLDER SOURCEFOLDERNAME=\"$Folder\"" >> $XMLFILE
			 echo "	  SOURCEFOLDERTYPE=\"LOCAL\"" >> $XMLFILE
			 echo "	  TARGETFOLDERNAME=\"$Folder\"" >> $XMLFILE
			 echo '   MODIFIEDMANUALLY ="YES"' >> $XMLFILE
			 echo "	  TARGETFOLDERTYPE=\"LOCAL\"/>" >> $XMLFILE
			 			 

#done < $DEPLOY_FILE_LOC/$DEPLOY_FILE_NME
done < $FOLDER_LIST
			 
  echo '<APPLYLABEL SOURCELABELNAME=""' >> $XMLFILE
  echo '   SOURCEMOVELABEL="NO"' >> $XMLFILE
  echo "   TARGETLABELNAME=\"$TGT_LABEL_NAME\"" >> $XMLFILE
  echo '   TARGETMOVELABEL="NO" />' >> $XMLFILE
  echo '</DEPLOYGROUP>' >> $XMLFILE
  echo '</DEPLOYPARAMS>' >> $XMLFILE
}

function DeployDeploymentGroup
{
pmrep listobjects -o deploymentgroup -c "" |sed -e 's/deployment_group//' > $TMP_FILE_LOC/TgtDplGroup.grp

while read DeployGroup
do
	for i in ${group[@]}
		do
			if [[ $DeployGroup = $i ]] then
				PROCESS_FLG="TRUE"
				GROUP_LABEL_NAME=$(echo $DeployGroup | sed 's/dpl/lbl/')

				ConnectRepository $TGT_REPO $TGT_HOST $TGT_PORT $TGT_UID $TGT_PWD
				pmrep createlabel -a $GROUP_LABEL_NAME >> $LOG_FILE_NAME
				echo "\nLabel $GROUP_LABEL_NAME created in $TGT_REPO..." >> $LOG_FILE_NAME

				CreateXMLFile $DeployGroup $GROUP_LABEL_NAME
				ConnectRepository $SRC_REPO $SRC_HOST $SRC_PORT $SRC_UID $SRC_PWD

				pmrep deploydeploymentgroup -p $DeployGroup -r $TGT_REPO -c $XMLFILE -h $TGT_HOST -o $TGT_PORT -n $TGT_UID -x $TGT_PWD >> $LOG_FILE_NAME

				INFA_RETURN_CODE=$?

				if [[ $INFA_RETURN_CODE -ne 0 ]] then
							echo "\nDeployment group $DeployGroup failed to deploy..." >> $LOG_FILE_NAME
							echo "\nPerforming cleanup for objects related to $DeployGroup..." >> $LOG_FILE_NAME
							pmrep deletelabel -a $GROUP_LABEL_NAME -f >> $LOG_FILE_NAME
							echo "\nLabel $LABEL_NAME has been deleted from the $SRC_REPO repository" >> $LOG_FILE_NAME
							pmrep deletedeploymentgroup -p $DeployGroup -f >> $LOG_FILE_NAME
							echo "\nDeployment group $GROUP_NAME has been deleted from the $SRC_REPO repository" >> $LOG_FILE_NAME
							ConnectRepository $TGT_REPO $TGT_HOST $TGT_PORT $TGT_UID $TGT_PWD
							pmrep deletelabel -a $GROUP_LABEL_NAME -f >> $LOG_FILE_NAME
							echo "\nLabel $GROUP_LABEL_NAME has been deleted from the $TGT_REPO repository" >> $LOG_FILE_NAME
							exit 1
				else
						echo "\nSuccessfully deployed $DeployGroup..." >> $LOG_FILE_NAME
				fi
			fi
		done
done < $TMP_FILE_LOC/TgtDplGroup.grp
}

##########################
#Main Body
##########################

#create log file for current session run
LOG_FILE_NAME="$LOG_FILE_LOC/${CUR_TIMESTAMP}_WF_AUTO_DEPLOY_${SRC_REPO}_TO_${TGT_REPO}.log"

echo "VW Credit Auto-Deploy" > $LOG_FILE_NAME
echo "$LOG_DATE\n" >> $LOG_FILE_NAME
echo "Source Repository - $SRC_REPO" >> $LOG_FILE_NAME
echo "Target Repository - $TGT_REPO" >> $LOG_FILE_NAME
echo "Source File - $DEPLOY_FILE_NME" >> $LOG_FILE_NAME

#Valid Repository Test
if [[ $SRC_DOMAIN = "ERROR" ]] then
	echo "\nSource repository $SRC_REPO does not exist. Operation cancelled..." >> $LOG_FILE_NAME
	exit 1
elif [[ $TGT_DOMAIN = "ERROR" ]] then
	echo "\nTarget repository $TGT_REPO does not exist. Operation cancelled..." >> $LOG_FILE_NAME
	exit 1
fi

#if [[ $SRC_REPO = $TGT_REPO ]] then
#	echo "\nSource and Target Repository match. Operation cancelled..." >> $LOG_FILE_NAME
#	exit 1
#fi

#MAIN BODY

if [[ -f $DEPLOY_FILE_LOC/$DEPLOY_FILE_NME ]] then
	if [[ -r $DEPLOY_FILE_LOC/$DEPLOY_FILE_NME ]] then

		#Test file entries for correct environment and deployment status
		TestFileEntryTgtEnv

		#Connect to source repository
		ConnectRepository $SRC_REPO $SRC_HOST $SRC_PORT $SRC_UID $SRC_PWD

		#Create Labels in source repository
		CreateLabel

		#Create deployment groups in source respitory
		CreateDeploymentGroup

		#Apply labels and add objects to deplopment groups in source repository
		Apply_Label_Add_to_Group

		#Deploy deployment groups from source repository to target repository
		DeployDeploymentGroup
		cp $

		mv $DEPLOY_FILE_LOC/DeploymentObjects_WF.dat $DEPLOY_FILE_ARCH_LOC/${CUR_TIMESTAMP}_DeploymentObjects_WF.dat

		if [[ -z $(ls -A $XML_FILE_LOC) ]] then
			echo "" >> $LOG_FILE_NAME
		else
			rm $XML_FILE_LOC/*
		fi

		if [[ -z $(ls -A $TMP_FILE_LOC) ]] then
			echo "" >> $LOG_FILE_NAME
		else
			rm $TMP_FILE_LOC/*
		fi
	else
		echo "\n$DEPLOY_FILE_LOC/$DEPLOY_FILE_NME is not readable..." >> $LOG_FILE_NAME
		exit 1
	fi
else
	echo "\n$DEPLOY_FILE_LOC/$DEPLOY_FILE_NME does not exist..." >> $LOG_FILE_NAME
	exit 1
fi

if [[ -z $(ls -A $XML_FILE_LOC) ]] then
	echo "" >> $LOG_FILE_NAME
else
	rm $XML_FILE_LOC/*
fi

if [[ -z $(ls -A $TMP_FILE_LOC) ]] then
	echo "" >> $LOG_FILE_NAME
else
	rm $TMP_FILE_LOC/*
fi

exit
