<# 
.SYNOPSIS 
Dump/Restore share permissions to $sharesXmlFile file. 
 
.DESCRIPTION 
The function for share permissions migration. 
 
.PARAMETER $srvName 
Specifies the server name for export share permissions to $sharesXmlFile.

.PARAMETER $sharesXmlFile
Specifies the file name for export share permissions, xml format.
 
.INPUTS 
None. You cannot pipe objects for function. 
 
.OUTPUTS 
Dump-Shares function is generate $sharesXmlFile. 
 
.EXAMPLE 
C:\PS> Dump-Shares -srvName RemoteServerName -sharesXmlFile "c:\shareXmlInfo.xml"
 
.EXAMPLE 
C:\PS> Restore-Shares -srvName RemoteServerName -sharesXmlFile "c:\shareXmlInfo.xml"
 
#> 

function Dump-Shares{

    Param (
            [parameter(Mandatory = $true)] 
            [string]$srvName,

            [parameter(Mandatory = $true)] 
            [string]$sharesXmlFile
    )
  
    Process{
        
        $cim = New-CimSession -ComputerName $srvName
        $shares = Get-SmbShare -CimSession $cim
    
        Remove-Item -Path $sharesXmlFile -EA SilentlyContinue
        $GeneralStatsXML = "<?xml version=""1.0"" encoding=""utf-8""?>`n" 
        $GeneralStatsXML += "<Result>`n" 
    
        if ($shares){
            foreach($share in $shares){
                $shareName = $share.Name
                $sharePath = $share.Path
                   
                $GeneralStatsXML += "`t<OperationResult>`n" 
                $GeneralStatsXML += "`t`t<ShareName>$shareName</ShareName>`n" 
                $GeneralStatsXML += "`t`t`t<Path>$sharePath</Path>`n"
            
                $sharePerms = Get-SmbShareAccess -CimSession $cim -Name $shareName
                
                    if ($sharePerms){
                        foreach($sharePerm in $sharePerms){
                            $shareUser = $sharePerm.AccountName
                            $shareRight = $sharePerm.AccessRight
                        
                            $GeneralStatsXML += "`t`t`t`t<User>`n"
                            $GeneralStatsXML += "`t`t`t`t`t<Name>$shareUser</Name>`n" 
                            $GeneralStatsXML += "`t`t`t`t`t<Right>$shareRight</Right>`n" 
                            $GeneralStatsXML += "`t`t`t`t</User>`n"
                        }
                    }
                        $GeneralStatsXML += "`t</OperationResult>`n" 
            } 
            
                $GeneralStatsXML += "</Result>`n" 
        }
    
        Add-Content -Encoding UTF8 -Value $GeneralStatsXML -Path $sharesXmlFile 
        Write-Host "Save XML file to $sharesXmlFile" 
    } 
}

function Restore-Shares{

    Param (
            [parameter(Mandatory = $true)] 
            [string]$srvName,

            [parameter(Mandatory = $true)] 
            [string]$sharesXmlFile
    )

    Process{
        
        $cim = New-CimSession -ComputerName $srvName
        
        [xml]$shareSettings = Get-Content $sharesXmlFile 

        foreach( $setShare in $shareSettings.Result.OperationResult){
            $shareName = $setShare.ShareName 
            $sharePath = $setShare.Path 

            $shareIsPreset = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue -CimSession $cim
            
            foreach( $user in $setShare.User){

                $userName = $user.Name
                $userRight = $user.Right
                if($shareIsPreset){
                    Grant-SmbShareAccess -Name $shareName -AccountName $userName -AccessRight $userRight -Confirm:$false -CimSession $cim
                }else{
                    if($userRight -eq "Full"){
                        New-SmbShare -Name $shareName -Path $sharePath -FullAccess $userName -Confirm:$false -CimSession $cim
                    }elseif($userRight -eq "Change") {
                        New-SmbShare -Name $shareName -Path $sharePath -ChangeAccess $userName -Confirm:$false -CimSession $cim
                    }else{
                        New-SmbShare -Name $shareName -Path $sharePath -ReadAccess $userName -Confirm:$false -CimSession $cim
                    }

                    $shareIsPreset = $true
                }
            }
        }
    }
}
