# SQLRES Workshop Toolset

The SQLRES Workshop toolset is intended to demonstrate disaster scenarios and recovery practices.

This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment._
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
the object code form of the Sample Code, provided that you agree:

(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;

(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and

(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code.

---------------------------
## 1. Getting started
### 1.1 TOOLS MACHINE
On the tools machine you only need to enable the execution of PowerShell scripts.
To enable the execution of PowerShell script you can set the ExecutionPolicy to Unrestricted or to RemoteSigned.
Unrestricted allows the execution of all PowerShell scripts.
RemoteSigned would prevent the execution of downloaded scripts from the internet.
First check the current ExecutionPolicy:
```
Get-ExecutionPolicy
```
If the ExecutionPolicy is already set to Unrestricted or RemoteSigned you do not need to change anything.
If the ExecutionPolicy is set to Restricted or AllSigned you need to change the ExecutionPolicy to at least RemoteSigned.
You need to use an elevated PowerShell session.
```
Set-ExecutionPolicy RemoteSigned
```
http://technet.microsoft.com/en-us/library/ee176961.aspx
If you copied the toolset over the Internet the execution of the scripts may be blocked.
You need to Unblock the scripts to be able to execute them.
To unblock all files, you can use the following PowerShell command:
```
dir -s *.ps* | Unblock-File
```

### 1.2 TARGET MACHINE(S)
On the target machines you need to enable PowerShell Remoting. To enable PowerShell on the target machines there are two ways. Using PowerShell (you need to use an elevated PowerShell session):
```
Enable-PSRemoting –force
```
Or you can use the Server Manager.
On the summary screen you will find the link “Configure Server Remote Management”
Firewall exceptions will be created as well. For external firewalls you need to contact the firewall administrators.
http://blogs.technet.com/b/christwe/archive/2012/06/20/what-port-does-powershell-remoting-use.aspx

## 2. Scoping the environment
---------------------------
Before you can start to run the first test cases you need to scope the environment. During scoping the target objects get marked with the flag SQLRES = TRUE.
The machines involved in the cluster or the machine for the standalone SQL Server are flagged with the system environment variable SQLRES = TRUE.
For instance related test cases the master database gets flagged with the extended property SQLRES = TRUE.
For user database related test cases the user database gets flagged with the extended property SQLRES = TRUE.
The test cases will check if the scoping information is available otherwise test case execution will be aborted.
To launch SQLRES toolset simply double-click on the SQLRES shortcut. You can see two faces on the icon of the shortcut.
When you start SQLRES toolset for the first time you will get a warning message stating that scoping was not yet performed.
Call Scope-Environment to start the scoping process.

## 3. Run your first test case
---------------------------
To get a list of all available test case function execute the following PowerShell command:
```
Get-Command –module SQLRES
```
To get information on the single test cases just write
```
Get-help Execute-TCPBlockPort
```
or
```
Get-help Execute-TCPBlockPort -detailed
```
or
```
Get-help Execute-TCPBlockPort -full
```
Now we can execute the first test case.
You can execute test cases by entering the function name Execute-{test case name}
or by navigating through the test cases by entering the command Launch-TestCase.
Launch-TestCase lets you chose the test case level and after that the test case you wish to execute.
Currently the following test case level are available:
* Azure: for Azure related test cases
* Server: for server related test cases
* Cluster: for cluster related test cases
* Instance: for instance related test cases
* Availability Group: for Availability Group related test cases
* Database: for database related test cases
* @Admin: the admin section shows administration tasks like 
	Scoping, creating database clones, backup and restore of databases.

During execution you can see execution information (colored white). The scoping check will be displayed in dark green. The result of the test case will be shown in green or red depending on the outcome.
The last message on this screen shows the student task to perform when the test case was successful.
Please do not tell the students what the test case did in the background.
This is a very important part for the students to find out what happened and to find out where to find this information.

## **Enjoy the SQLRES workshop!!!**

©2018 Microsoft
http://www.microsoft.com/en-us/microsoftservices/
