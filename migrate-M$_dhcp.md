### Params
```
$curDhcpServer = "10.10.1.10"
$newDhcpServer = "10.10.1.20"
$backUpFileName = "C:\dhcp-config\dhcp-cobfiles.xml"
$backUpFolderPath = "C:\dhcp-config\backup"
```

### Backup server scopes
```
Export-DHCPServer -ComputerName $curDhcpServer -File $backUpFileName
```

### Restore server scopes
```
Import-DHCPServer -ComputerName $newDhcpServer -File $backUpFileName -BackupPath $backUpFolderPath
```

### Look server scopes
```
Get-DhcpServerv4Scope –ComputerName $curDhcpServer
$Scope = <paste ScopeId info from query>
```

### Transfer current leases
enumerate scopes by ScopeId
```
@(Get-DHCPServerv4Lease  -ComputerName $curDhcpServer -ScopeId $Scope).where({$_.AddressState -eq "Active"}) | Add-DhcpServerv4Lease -ComputerName $newDhcpServer
```

