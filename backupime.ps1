#
# Copyright (C), 2017, All Rights Reserved
# Author: V. Mullachery
# Date: Nov 8, 2017
#
# Usage: 
# 	D:\>Powershell backup_idm.ps1
#
# Backups are created in D:\Backup\<yyyy-MM-dd_HH-mm>\*.xml
# Tested on Powershell v4
# 
$BackupLocation = 'D:\Backup'
$User = 'me'
$Pwd = 'mypassword'
$ImUrl = 'https://identity-test.mycompany.com/iam/immanage/'
$AuthUrl = 'https://msa-test.mycompany.com/siteminderagent/forms/login-myt-internet-ent.fcc'
$Fields = @{'USER'=$User;'PASSWORD'=$Pwd;'target'=$ImUrl}
$cDomain = '.mycompany.com'

$ydm = Get-Date -format yyyy-MM-dd_HH-mm
$BackupLocation = $BackupLocation + '\' + $ydm
$myRes = mkdir $BackupLocation

#
# Management Console
#
$ManagementConsole = 'Management Console'
$myRes = Invoke-RestMethod -Uri $AuthUrl -Method Post -Body $Fields -SessionVariable sessionVar
if ($myRes -eq $null -Or $myRes -NotMatch $ManagementConsole) {
	Write-Error "Failed Authenticating to IDM Management Console"
	#exit 1
}

#
# Save Cookies
# Courtesy: https://stackoverflow.com/questions/39320581/powershell-invoke-restmethod-missing-cookie-values
#
$CookieJar = New-Object System.Net.CookieContainer
$CookieHeader = ""
$webRequest=[System.Net.HTTPWebRequest]::Create($AuthUrl)
$webRequest.CookieContainer = $CookieJar
$webResponse = $webRequest.GetResponse()
$cookies = $CookieJar.GetCookies($AuthUrl)

#Add the cookies to sessionVar
foreach ($c in $cookies) { 
	$sessionVar.Cookies.Add((Create-Cookie -name $($c.name)  -value $($c.value) -domain $cDomain ))
}

#
# list directories
#
$dirs = @('mytProvDirectory', 'mytUserDirectory')
$myRes = Invoke-RestMethod -Uri ($ImUrl + 'dir.do?method=listDirs') -Method Get -WebSession $sessionVar 
if ( ($myRes -eq $null) -Or ($myRes -NotMatch $ManagementConsole) ) {
	Write-Error "Failed Fetching IDM Directories"
	#exit 2
}
foreach ($item in $listDirs) {
	if ($myRes -NotMatch $item) {
		Write-Error "Failed Fetching IDM Directory: " $item
		#exit 3
	}
}

#
# mytProvDirectory View
#
$mytProv = 'mytProvDirectory'
$myRes = Invoke-RestMethod -Uri ($ImUrl + 'dir.do?method=editDir&diroid=5') -Method Get -WebSession $sessionVar
if ( ($myRes -eq $null) -Or ($myRes -NotMatch $ManagementConsole) ) {
	Write-Error "Failed to fetch mytProvDirectory"
	#exit 4
}

#
# mytProvDirectory Export, diroid=5
#
$mytProv = 'mytProvDirectory'
$mytProvXml = $BackupLocation + '\mytProvDirectory.xml'
$myRes = Invoke-RestMethod -Uri ($ImUrl + 'dir.do?method=exportDir&diroid=5') -Method Get -WebSession $sessionVar -OutFile $mytProvXml
if ( (Get-Item $mytProvXml).length -le 35kb ) {
	Write-Error "Failed to export mytProvDirectory"
	#exit 5
}

#
# mytUserDirectory View
#
$myRes = Invoke-RestMethod -Uri ($ImUrl + 'dir.do?method=editDir&diroid=4') -Method Get -WebSession $sessionVar
if ( ($myRes -eq $null) -Or ($myRes -NotMatch $ManagementConsole) ) {
	Write-Error "Failed to fetch mytUserDirectory"
	#exit 6
}


#
# mytUserDirectory Export, diroid=4
#
$mytUserXml = $BackupLocation + '\mytUserDirectory.xml'
$myRes = Invoke-RestMethod -Uri ($ImUrl + 'dir.do?method=exportDir&diroid=4') -Method Get -WebSession $sessionVar -OutFile $mytUserXml
if ( (Get-Item $mytUserXml).length -le 35kb ) {
	Write-Error "Failed to export mytUserDirectory"
	#exit 7
}

#
# mytProv Environment Advanced Settings View, envoid=21
#
$myRes = Invoke-RestMethod -Uri ($ImUrl + 'envsettings.do?method=getSettings&envoid=21&envname=mytProv') -Method Get -WebSession $sessionVar
if ( ($myRes -eq $null) -Or ($myRes -NotMatch $ManagementConsole) ) {
	Write-Error "Failed to fetch mytProv environment"
	#exit 8
}

#
# mytProv Environment Export Advanced Settings, envoid=21
#
$mytProvAdvSettingsXml = $BackupLocation + '\mytProvAdvSettings.xml'
$myRes = Invoke-RestMethod -Uri ($ImUrl + 'envsettings.do?method=exportSettings&envoid=21&envname=mytProv') -Method Get -WebSession $sessionVar -OutFile $mytProvAdvSettingsXml
if ( (Get-Item $mytProvAdvSettingsXml).length -le 40kb ) {
	Write-Error "Failed to export mytProv Environment"
	#exit 9
}

#
# mytProv Environment Roles Settings View, envoid=21
#
$myRes = Invoke-RestMethod -Uri ($ImUrl + 'env.do?method=editRoles&envoid=21&envname=mytProv') -Method Get -WebSession $sessionVar
if ( ($myRes -eq $null) -Or ($myRes -NotMatch $ManagementConsole) ) {
	Write-Error "Failed to fetch mytProv environment"
	#exit 10
}

#
# mytProv Environment Export Roles Settings, envoid=21
#
$mytProvRolesXml = $BackupLocation + '\mytProvRoles.xml'
$myRes = Invoke-RestMethod -Uri ($ImUrl + 'env.do?method=exportRoles&envoid=21&envname=mytProv') -Method Get -WebSession $sessionVar -OutFile $mytProvRolesXml
if ( (Get-Item $mytProvRolesXml).length -le 6Mb ) {
	Write-Error "Failed to export mytProv Environment Roles"
	#exit 11
}

#
# Export the AD Account Templates 
#
$adsAccountTemplates = $BackupLocation + '\ADSPolicies.ldif'
$dxsearch = "D:\Program Files\CA\Directory\dxserver\bin\dxsearch.exe"
$pwd='mypassword'
$dxargs = (" -LLL -D " + '"eTGlobalUserName=idmadmin,eTGlobalUserContainerName=Global Users,eTNamespaceName=CommonObjects,dc=im,dc=eta"' +  " -w " + $pwd + " -h provdir..mycompany.com -p 20389 -b  " + '"eTADSPolicyContainerName=Active Directory Policies,eTNamespaceName=CommonObjects,dc=im,dc=eta"'  + " -x -s sub " + '"(eTADSPolicyName=*)"' + " " ) 
& $dxsearch $dxargs.split(" ") > $adsAccountTemplates
if ( (Get-Item $adsAccountTemplates).length -le 1Mb ) {
	Write-Error "Failed to export ADS Account Templates"
	exit 12
}

