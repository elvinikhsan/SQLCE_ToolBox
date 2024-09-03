#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Witness Lost - Primary Lost - Secondary Left Exposed.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 3.0 Initial version for SQL 2016 release
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Execute-WitnessLost_PrimaryLost_SecondaryExposed()
{ 
 <# 
   .Synopsis 
    Performs scoping of the environment
   .Description
    This function is just a shortcut for rescoping the environment with the already entered information
	TestCaseLevel:Availability Groups
   .Notes  
	If you do not want to perform scoping it is still possible to execute the test cases
	using the -IgnoreScoping switch
   .Example 
    Execute-WitnessLost_PrimaryLost_SecondaryExposed
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0

if ($PSBoundParameters['Verbose']) {
	Execute-GenerateBSOD -WitnessLost_PrimaryLost_SecondaryExposed -Verbose
}
else {
	Execute-GenerateBSOD -WitnessLost_PrimaryLost_SecondaryExposed
}

}
