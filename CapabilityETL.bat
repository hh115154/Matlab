:: The bat file automatically pulls the latest Capability scripts and
:: calls CapabilityUploadScript.m from D:\Users\kz429\data crunching\GUI code\codeNew on W3-A22649 from
:: the command line to run the capability upload script. This bat file is run via the task scheduler
:: Author : Yiyuan Chen; Date: 2014/07/29

:: change the directory to D:\Users\kz429\data crunching\GUI code\codeNew
d:
cd Users\kz429\data crunching\GUI code\codeNew

git.exe pull origin master
git.exe pull --tags origin master

:: Call Matlab script
matlab -r CapabilityUploadScript