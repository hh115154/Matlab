:: The bat file automatically calls CapabilityUploadScript.m from D:\Users\kz429\data crunching\GUI code\codeNew on W3-A22649 from
:: the command line to run the capability upload script. This bat file is run via the task scheduler
:: Author : Yiyuan Chen; Date: 2014/06/04

:: Change directory to D:\Users\kz429\data crunching\GUI code\codeNew
d:
cd Users\kz429\data crunching\GUI code\codeNew

:: Call Matlab script

matlab -r CapabilityUploadScript

