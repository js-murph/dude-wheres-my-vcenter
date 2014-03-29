# I don't know dude, where is your vCenter?
param (
    [switch]$help = $false
)

Set-StrictMode -Version 2.0

function locate_vcenter {
    $hshNagVars = @{"hostname" = hostname; 
                    "service" = $objMainConf['nagios']['serviceName']; 
                    "state" = "0"; 
                    "output" = ""; 
                    "activecheck" = "1";
                    "nrdpurl" = $objMainConf['nagios']['nrdpUrl'];
                    "nrdptoken" = $objMainConf['nagios']['nrdpToken']}
                    
    $hshNagVars['hostname'] = $hshNagVars['hostname'].ToLower()

    if ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null) {
        Add-PSSnapin VMware.VimAutomation.Core
    }

    $adDe = New-Object System.DirectoryServices.DirectoryEntry($objMainConf['AD']['ldapString'], $objMainConf['AD']['ldapUser'], $objMainConf['AD']['ldapPass'])
    $strLdapFilter = "(&(objectcategory=computer)(name=" + $objMainConf['AD']['ldapEsxNameFilter'] + "))"
    $adSearcher = New-Object System.DirectoryServices.DirectorySearcher($adDe,$strLdapFilter)
    
    $aryEsxServers = $adSearcher.findall() | ForEach-Object {$_.Properties.name}
    
    Disconnect-ViServer -Server * -Force -Confirm:$false -WarningAction SilentlyContinue -ErrorAction SilentlyContinue    
    Set-PowerCLIConfiguration -DefaultVIServerMode multiple -Confirm:$false
    Connect-ViServer -server $aryEsxServers -User $objMainConf['esx']['esxUser'] -Password $objMainConf['esx']['esxPass'] -WarningAction SilentlyContinue

    $vmVSC = Get-Vm $hshNagVars['hostname']
    
    $esxhost = ""
    foreach ($vmVC in $vmVSC) {
        $vmVCIntCount = Get-NetworkAdapter -VM $vmVC | Measure
    
        if ($vmVCIntCount.Count -gt 0) {
            $esxHost = $vmVC.VMHost.Name
        }
    }
    
    if ([string]::IsNullOrEmpty($esxHost)) {
        $strMessage = "Something bad happened and I can't find the virtual center server."
        $hshNagVars['state'] = 2
        $hshNagVars['output'] = $strMessage
        Write-Host $strMessage
        $xmlPost = generate_alert_xml $hshNagVars
        send_alert_to_nagios $xmlPost $hshNagVars
        exit $hshNagVars['state']
    } else {         
        $strMessage = $hshNagVars['hostname'] + " is currently running on " + $esxHost
        $hshNagVars['state'] = 0
        $hshNagVars['output'] = $strMessage
        Write-Host $strMessage
        $xmlPost = generate_alert_xml $hshNagVars
        send_alert_to_nagios $xmlPost $hshNagVars
        exit $hshNagVars['state']
    }
}

function send_alert_to_nagios([String]$xmlPost, [Hashtable]$hshNagVars) {
   $webAgent = New-Object System.Net.WebClient
   $nvcWebData = New-Object System.Collections.Specialized.NameValueCollection
   $nvcWebData.Add('token', $hshNagVars['nrdpToken'])
   $nvcWebData.Add('cmd', 'submitcheck')
   $nvcWebData.Add('XMLDATA', $xmlPost)
   $strWebResponse = $webAgent.UploadValues($hshNagVars['nrdpUrl'], 'POST', $nvcWebData)
   $strReturn = [System.Text.Encoding]::ASCII.GetString($strWebResponse)
   if ($strReturn.Contains("<message>OK</message>")) {
        $strMessage = "SUCCESS - DWMVC checks succesfully sent, NRDP returned: " + $strReturn + ")"
        Write-Host $strMessage
        return $true
   } else {
        $strMessage = "ERROR - DWMVC checks failed to send, NRDP returned: " + $strReturn + ")"
        Write-Host $strMessage
        return $false
   }
}

function generate_alert_xml([Hashtable]$hshNagVars) {
    $xmlBuilder = "<?xml version='1.0'?>`n<checkresults>"
    $xmlBuilder += "`n`t<checkresult type='service' checktype='" + $hshNagVars['activecheck'] + "'>"
    $xmlBuilder += "`n`t`t<hostname>" + $hshNagVars['hostname'] + "</hostname>"
    $xmlBuilder += "`n`t`t<servicename>" + $hshNagVars['service'] + "</servicename>"
    $xmlBuilder += "`n`t`t<state>" + $hshNagVars['state'] + "</state>"
    $xmlBuilder += "`n`t`t<output>" + $hshNagVars['output'] + "</output>"
    $xmlBuilder += "`n`t</checkresult>"
    $xmlBuilder += "`n</checkresults>"
    return $xmlBuilder
}

function import_main_config([String]$strExecutingPath) {
    $strConfigFile = $strExecutingPath + "dwmvc.ini"
    
    if (Test-Path $strConfigFile) {
        $aryIniContents = @{}
        switch -regex -file $strConfigFile {
            "^\[(.+)\]$" {
                $strHeading = $Matches[1]
                $aryIniContents[$strHeading] = @{}
            }
            "(.+?)\s*=\s*(.*)" {
                $strKey = $Matches[1]
                $strValue = $Matches[2]
                $aryIniContents[$strHeading][$strKey] = $strValue.Trim()
            }
        }
    } else {
        Write-Host "Unable to find main config file at path: $strConfigFile"
        exit 2
    }

    return $aryIniContents
}

function help {
    $strVersion = "v0.1 b050314"
    $strNRDPVersion = "1.2"
    Write-Host "DWMVC version: $strVersion for NRDP version: $strNRDPVersion"
    Write-Host "By John Murphy <john.murphy@roshamboot.org>, GNU GPL License"
    Write-Host "Usage: ./DudeWheresMyVcenter.ps1`n"
    Write-Host @'
-help
	Display this help text.
'@
    exit 0
}

##########################################
### BEGIN MAIN
##########################################
if($help) {
    help
}

$strExecutingPath = Split-Path -Parent $script:MyInvocation.MyCommand.Path
Set-Location -Path $strExecutingPath

if (!("\" -eq $strExecutingPath.Substring($strExecutingPath.Length - 1, 1))) {
    $strExecutingPath = $strExecutingPath + "\"
}

$objMainConf = import_main_config($strExecutingPath)
Set-Variable -Name $objMainConf -Scope Global

locate_vcenter