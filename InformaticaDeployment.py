## Informatica PowerCenter Deployment Script 
## Will create several functions and then execute them.
## CreateControlFile, CreateLabel, CreateDeploymentGroup, ListObjects, Apply Label, AddtoGroup, DeployDeploymentGroup.

import subprocess
import os
from subprocess import *
import sys
import platform


#Declare global variables
currentDir=''
pmrepPath=''
domainFile=''


#Function to connect to the repository expects name of repository , domain and user details
def connect_to_repo(Repository,Domain,User):
        RepoCommand="pmrep connect -r "+Repository+" -d "+Domain+" -n "+User+" -X DOMAIN_PWD"
        RepoCommand=RepoCommand.rstrip()
        p=subprocess.Popen(RepoCommand,stderr=subprocess.PIPE,stdin=subprocess.PIPE,stdout=subprocess.PIPE,shell=True)
        out,err=p.communicate()
        if p.returncode or err:
                print "\n\n ERROR : Connection Failed !!!" #
                sys.stdout.flush()
                sys.stdin.flush()
        else:
                print "\n\n***********************************************************************\n\nConnection Successful !!!"

                sys.stdout.flush()
                sys.stdin.flush()
        return p.returncode
#END OF FUNCTION connect_to_repo


#executes any OS command, here provided pre defined commands
def execute_pmrep_command(command,output_file_name):
        out=open(output_file_name,'a')
        return_code=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,shell=True)
        output,error=return_code.communicate()
        out.writelines(output.strip())
        out.close()
        return
#END OF FUNCTION execute_pmrep_command

#function to make output dirs , create if not exist
def create_output_directories():
        if platForm == 'Windows':
                try:
                        os.makedirs(currentDir.strip()+"\LogFiles")
                        print "\n\n***********************************OUTPUT******************************\n\nLog files generated and stored in 'LogFiles' directory" #
                except OSError:
                        print "\n\n***********************************OUTPUT******************************\n\nLog files generated and stored in 'LogFiles' directory" #
                        pass
        elif platForm == 'Linux':
                try:
                        os.makedirs(currentDir.strip()+"/LogFiles")
                        print "\n\n***********************************OUTPUT******************************\n\nLog files generated and stored in 'LogFiles' directory" #
                except OSError:
                        print "\n\n***********************************OUTPUT******************************\n\nLog files generated and stored in 'LogFiles' directory" #
                        pass
#END OF FUNCTION create_output_dirs

#checking for all necessary environment variables
def check_platform():
        global domainFile
        global currentDir
        global pmrepPath
        global platForm
        platForm=platform.system()
        print "Platform recognized : "+platForm
        if not os.getenv('INFA_HOME'):
                print "INFA_HOME environment variable is not set in your "+platForm+" platform." #
                print "\nPlease set INFA_HOME and run the script." #
                raw_input()
                sys.exit(0)
        elif not os.getenv('INFA_DOMAIN_INFO'):
                print "INFA_DOMAIN_INFO environment variable is not set in your "+platForm+" platform." #
                print "\nPlease set INFA_DOMAIN_INFO and run the script." #
                raw_input()
                sys.exit(0)
        elif not os.getenv('DOMAIN_PWD'):
                print "DOMAIN_PWD environment variable not set in your "+platForm+" platform." #
                print "\nPlease set DOMAIN_PWD and run the script." #
                raw_input()
                sys.exit(0)
        else:
                if platForm == 'Windows':
                        pmrepPath=os.getenv('INFA_HOME').strip()+"\clients\PowerCenterClient\client\\bin"
                elif platForm == 'Linux':
                        pmrepPath=os.getenv('INFA_HOME').strip()+"/server/bin"
                currentDir=os.getcwd()
                domainFile=os.getenv('INFA_DOMAIN_INFO').strip()
#END OF FUNCTION

                
#start of the main program body

## First check to what O/S is being used Windows or Linux
if platform.system()=='Windows':
          os.system('cls')
elif platform.system()=='Linux':
          os.system('clear')
print "Checking for all necessary environment variables ....\n"
check_platform()
lines=open(domainFile,'r').readlines()
os.chdir(pmrepPath)
if platForm == 'Windows':
        logFileLoc=currentDir.strip()+"\LogFiles\InfaAutoDeploy.txt"
elif platForm == 'Linux':
        logFileLoc=currentDir.strip()+"/LogFiles/InfaAutoDeploy.txt"
## Read input from environment files contained in set_env
for line in lines:
        fields=line.split(',')
        Repository=fields[0]
        Domain=fields[1]
        User=fields[2]
        return_code=connect_to_repo(Repository,Domain,User)
        if return_code:
                continue
        DeploymentFile="deploymentobjectlist.csv"  ##list deployment input file

        if platForm == 'Windows':
                DeploymentFile=currentDir.strip()+"\\"+DeploymentFile.strip()
        elif platForm == 'Linux':
                DeploymentFile=currentDir.strip()+"/"+DeploymentFile.strip()
        deploymentfile_lines=open(DeploymentFile,'r').readlines()
       deploymentfile_lines=deploymentfile_lines[1:]
        create_output_directories()
        for deployments in deploymentfile_lines:
                field=deployments.split(',')
                SRC_Repo=field[0].strip()
                TGT_Repo=field[1].strip()
		Folder=field[2].strip()
                ObjName=field[3].strip()
		ObjType=field[4].strip()
                GrpName=field[5].strip()
                Deploy=field[6].strip()
                ParentOnly=field[7].strip()
		command_label="pmrep createlabel -a "+labelname+" 
		command_group="pmrep createdeploymentgroup -p "+GrpName+" -t static
		command_listobjects="pmrep listobjectdependencies -n "+ObjName+" -p children -f "+Folder+" -u tempfilelocation
		command_apply=
		command_add="pmrep deploydeploymentgroup -p "+GrpName+" -r "+TGT_Repo+" -c "+xmlfile+" -n "user
                command_deploy="pmrep deploydeploymentgroup -p "+GrpName+" -r "+TGT_Repo+" -c "+xmlfile+" -n "user
                execute_pmrep_command(command_label,logFileLoc.strip())
		execute_pmrep_command(command_group,logFileLoc.strip())
		execute_pmrep_command(command_add,logFileLoc.strip())
		execute_pmrep_command(command_deploy,logFileLoc.strip())
        print "\n\nPermission is assigned to the objects. \n\nFor more details please refer 'InfaAutoDeploy.txt' in LogFiles directory.\n\n***********************************************************************"
		
#END PROGRAM


