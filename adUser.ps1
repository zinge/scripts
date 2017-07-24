Import-Module ActiveDirectory
$domName = "<EDIT>.<EDIT>.<EDIT>"
$ouName = "ou=<EDIT>,dc=<EDIT>,dc=<EDIT>,dc=<EDIT>"

function recurseFunction{
    [string]$action  = Read-Host "Показать меню?(Y|N)"

    if($action -match "[yY]|[дД]"){
        mainFunction
    }elseif($action -match "[nN]|[нН]"){
        Write-Host -f Green "Пока"
    }else{
        Write-Host -f Yellow "Ничего не понял, на всякий случай СТОП"
    }
}

function createFilter($question){
    <#
        if(samAccountName){
            $sam = $true
        }else{
            $sam = $false
        }

        $question = @([string]$questionString, [bool]$sam)
    #>
    [string]$filterName = Read-Host $question[0]
    
    if($question[1]){

        if($filterName -eq [string]::Empty){
            Write-Host -f red "Нужны данные для продолжения"
            $stop = Read-Host "Стоп?(Y|N)"
            if($stop -match "[yY]|[дД]"){
                $filter = ""
            }else{
                $filter = createFilter($question)
            }

        }else{
            $filter = $filterName
        }
    }else{

        if($filterName -eq [string]::Empty){
            [string]$all = Read-Host "Посмотрим всех ?(Y|N)"
                
            if($all -match "[yY]|[дД]"){
                $filter = "*"
            }else{
                Write-Host -f red "Нужны данные для продолжения"
                $stop = Read-Host "Стоп?(Y|N)"
                if($stop -match "[yY]|[дД]"){
                    $filter = ""
                }else{
                    $filter = createFilter($question)
                }
            }
        }else{
            $filter = $($filterName+"*")
        }
    }

    return $filter
}

function mainFunction{
    [int]$action = Read-Host `
"
    Пользователи:
    -------------
    1 -> Показать информацию о пользователе
    2 -> Сменить пароль
    3 -> Блокировать
    4 -> Разблокировать
    5 -> Показать только блокированных
    12 -> Сменить номер телефона пользователя

    Группы:
    -------------
    6 -> Показать информацию о группах
    7 -> Добавить пользователя в группу
    8 -> Удалить пользователя из группы
    9 -> Создать группу
    10 -> Показать информацию о группах пользователя
    11 -> Показать пользователей в группе

    другое -> очистить экран
"

    switch ($action)
    {
        1 {
            #Инфомация о пользователе (в ответе возможны множественные данные)
            $userFilter = createFilter(@("Введи часть ФИО (можно использовать '*' вначале)", $false))
            
            if($userFilter -ne [string]::Empty){
                $usrObj = Get-ADUser -Filter {Name -like $userFilter} -Server $domName -SearchBase $ouName -Properties `
                        SamAccountName, enabled, DistinguishedName, Name, wWWHomePage, `
                        whenCreated, lastLogon, Department, mail, telephoneNumber | `
                    Select-object `
                        @{N="Учетная запись";E={$_.SamAccountName}}, `
                        @{N="Активная ?";E={$_.enabled}},`
                        @{N="Расположение";E={$_.DistinguishedName}}, `
                        @{N="ФИО";E={$_.Name}}, `
                        @{N="Последний ПК";E={$_.wWWHomePage}}, `
                        @{N="Создано";E={$_.whenCreated[0]}}, `
                        @{N="Заходил в последний раз";E={[datetime]::FromFileTime($_.lastLogon)}}, `
                        @{N="Отдел";E={$_.Department}}, `
                        @{N="Почта";E={$_.mail}}, `
                        @{N="Телефон";E={$_.telephoneNumber}}

                if($usrObj){
                    $usrObj | Format-List

                    $pingAction = Read-Host "ПИНГануть ПК пользователй?(Y|N)"
                    if($pingAction -match "[yY]|[дД]"){
                        $userPCs = $usrObj."Последний ПК"
                        $pingAction = Read-Host "ПИНГануть все ПК найденных пользователей?(Y|N)"
                        if($pingAction -match "[nN]|[нН]"){
                            Write-Host -f Cyan "Ок. Тогда можно ПИНГануть следующие ПК:"
                            for($i=0; $i -le $userPCs.length-1; $i++){
                                "Имя ПК [{0}] => {1}" -f $i, $userPCs[$i]
                            }
                            $selectedPCs = read-host "Для выбора, введи цифру из []"
                            try{
                                Test-Connection -ComputerName $userPCs[${selectedPCs}] -Count 1 | Select-Object Address, IPV4Address, ReplySize, ResponseTime -ErrorAction SilentlyContinue | ft
                            }
                            catch [System.Net.NetworkInformation.PingException]{
                                Write-Host -f Red $Error[0].Exception.Message
                            }
                        }else{
                            $userPCs | %{Test-Connection $_ -Count 1 | Select-Object Address, IPV4Address, ReplySize, ResponseTime}
                        }
                    }
                }else{
                    write-host -f red "Ничего не найдено"
                }
            }
            recurseFunction      
        }
        2 {
            #Смена пароля, принимает SamAccountName
            $samFilter = createFilter(@("Введи имя учетки", $true))

            if($samFilter -ne [string]::Empty){
                if($usrObj = Get-ADUser -Filter {SamAccountName -eq $samFilter} -Server $domName -SearchBase $ouName){
                    $pass = Read-Host -AsSecureString "Введи пароль для пользователя"
                    try{
                        $usrObj | Set-ADAccountPassword -Reset -NewPassword $pass -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue
                    }
                    catch{
                        Write-Host -f red "Cмена пароля завершилась ошибкой"
                    }
                    finally{
                    Write-Host -f Cyan "Для '$samFilter' меняли пароль:" (Get-ADUser -Filter {SamAccountName -eq $samFilter} -Server $domName -SearchBase $ouName -Properties PasswordLastSet).PasswordLastSet
                    }
                }else{
                    Write-Host -f Red "Поиск пользователя закончился неудачно"
                }
            }
            recurseFunction
        }
        3 {
            #Блокировка пользователя, принимает SamAccountName
            $samFilter = createFilter(@("Введи имя учетки", $true))

            if($samFilter -ne [string]::Empty){
                if($usrObj = Get-ADUser -Filter {SamAccountName -eq $samFilter} -Server $domName -SearchBase $ouName){

                    try{
                        $usrObj | Disable-ADAccount -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue
                    }
                    catch{
                        Write-Host -f red "Блокировка пользователя завершилась ошибкой"
                    }
                    finally{
                        if ((Get-ADUser -Filter {SamAccountName -eq $samFilter} -Server $domName -SearchBase $ouName).Enabled){
                            Write-Host -f Cyan "'$samFilter' не заблокирован"
                        }else{
                            Write-Host -f Cyan "'$samFilter' заблокирован"
                        }
                    }
                }else{
                    Write-Host -f Red "Поиск пользователя закончился неудачно"
                }
            }
            recurseFunction
        }
        4 {
            #Разблокировка пользователя, принимает SamAccountName
            $samFilter = createFilter(@("Введи имя учетки", $true))
            
            if($samFilter -ne [string]::Empty){
                if($usrObj = Get-ADUser -Filter {SamAccountName -eq $samFilter} -Server $domName -SearchBase $ouName){

                    try{  
                        $usrObj | Unlock-ADAccount -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue
                        $usrObj | Enable-ADAccount -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue
                    }
                    catch{
                        Write-Host "Разблокировка пользователя завершилась ошибкой"
                    }
                        finally{
                        if ((Get-ADUser -Filter {SamAccountName -eq $samFilter} -Server $domName -SearchBase $ouName).Enabled){
                            Write-Host -f Cyan "'$samFilter' не заблокирован"
                        }else{
                            Write-Host -f Cyan "'$samFilter' заблокирован"
                        }
                    }
                }else{
                    write-host -f red "Поиск пользователя закончился неудачно"    
                }
            }
            recurseFunction
        }
        5 {
            #Показать заблокированных пользователей
            $usrObj = Get-ADUser -Filter {enabled -eq "False"} -Server $domName -SearchBase $ouName -Properties `
                    SamAccountName, enabled, DistinguishedName, Name, wWWHomePage, `
                    whenCreated, lastLogon, Department, mail, telephoneNumber | `
                Select-object `
                    @{N="Учетная запись";E={$_.SamAccountName}}, `
                    @{N="Активная ?";E={$_.enabled}},`
                    @{N="Расположение";E={$_.DistinguishedName}}, `
                    @{N="ФИО";E={$_.Name}}, `
                    @{N="Последний ПК";E={$_.wWWHomePage}}, `
                    @{N="Создано";E={$_.whenCreated[0]}}, `
                    @{N="Заходил в последний раз";E={[datetime]::FromFileTime($_.lastLogon)}}, `
                    @{N="Отдел";E={$_.Department}}, `
                    @{N="Почта";E={$_.mail}}, `
                    @{N="Телефон";E={$_.telephoneNumber}}
            if($usrObj){
                $usrObj | format-list
            }else{
                write-host -f red "Ничего не найдено"
            }

            recurseFunction
        }
        6 {
            #Показать информацию о группах
            $groupFilter = createFilter(@("Введи часть имени группы", $false))

            if($groupFilter -ne [string]::Empty){
            
                $groupObj = Get-ADGroup -Filter {Name -like $groupFilter} -Server $domName -SearchBase $ouName | Select-Object Name
            
                if($groupObj){
                    $groupObj | Format-List
                }else{
                    Write-Host -f Red "Ничего не найдено"
                }
            }

            recurseFunction
        }
        7 {
            #добавить в группу
            [string]$userName = Read-Host "Введи имя учетки"
            [string]$groupName = Read-Host "Введи имя группы"
            
            if(($userName -eq [string]::Empty) -OR ($groupName -eq [string]::Empty)){
                Write-Host -f red "Нужны данные для продолжения"
            }else{
                $userObj = Get-ADUser -Filter {SamAccountName -eq $userName} -Server $domName -SearchBase $ouName
                if($userObj){
                    $groupObj = Get-ADGroup -Filter {Name -eq $groupName} -Server $domName -SearchBase $ouName
                    if($groupObj){
                        try{
                            Add-ADGroupMember -Identity $groupObj -Members $userObj -Server $domName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue
                        }
                        catch{
                            Write-Host -f Red `
                            "
                            добавление пользователя
                            >> '$userName'
                            в группу
                            >> '$groupName'
                            закончилось ошибкой
                            "
                        }finally{
                            Write-Host -f Cyan "Пользователь '$userName' состоит в следующих группах:"
                            (Get-ADUser -Filter {SamAccountName -eq $userName} -Server $domName -SearchBase $ouName -Properties MemberOf).MemberOf
                        }
                    }else{
                        Write-Host -f Red "Ошибка в имени группы"
                    }
                }else{
                    Write-Host -f Red "Ошибка в учетной записи"
                }
            }
            recurseFunction
        }
        8 {
            #удалить из группы
            [string]$userName = Read-Host "Введи имя учетки"
            [string]$groupName = Read-Host "Введи имя группы"

            if(($userName -eq [string]::Empty) -OR ($groupName -eq [string]::Empty)){
                Write-Host -f red "Нужны данные для продолжения"
            }else{
                $userObj = Get-ADUser -Filter {SamAccountName -eq $userName} -Server $domName -SearchBase $ouName
                if($userObj){
                    $groupObj = Get-ADGroup -Filter {Name -eq $groupName} -Server $domName -SearchBase $ouName
                    if($groupObj){
                        try{
                            Remove-ADGroupMember -Identity $groupObj -Members $userObj -Server $domName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue
                        }
                        catch{
                            Write-Host -f Red `
                            "
                            удаление пользователя
                            >> '$userName'
                            из группы
                            >> '$groupName'
                            закончилось ошибкой
                            "
                        }finally{
                            Write-Host -f Cyan "Пользователь '$userName' состоит в следующих группах:"
                            (Get-ADUser -Filter {SamAccountName -eq $userName} -Server $domName -SearchBase $ouName -Properties MemberOf).MemberOf
                        }
                    }else{
                        Write-Host -f Red "Ошибка в имени группы"
                    }
                }else{
                    Write-Host -f Red "Ошибка в учетной записи"
                }
            }
            recurseFunction
        }
        9 {
            #создать группу(безопасности, глобальную)
            [string]$groupName = Read-Host "Введи имя группы"
            [string]$groupSamName = Read-Host "Короткое имя группы"
            
            if(($groupSamName -eq [string]::Empty) -OR ($groupName -eq [string]::Empty)){
                Write-Host -f red "Нужны данные для продолжения"
            }else{
                try{
                    New-ADGroup -Path "OU=ФункциональныеГруппы,$ouName" -GroupScope Global -GroupCategory Security -SamAccountName $groupSamName -DisplayName $groupName -Name $groupSamName -Description $groupName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue
                }
                catch{
                    Write-Host -f Red "что-то пошло не так(("
                }
                finally{
                    Write-Host -f Cyan "На текущий момент существуют следующие группы:"
                    Get-ADGroup -Filter * -Server $domName -SearchBase $ouName 
                }
            }
            recurseFunction
        }
        10 {
            #в каких группах состоит пользователь

            $userFilter = createFilter(@("Введи имя учетки", $true))

            if($userFilter -ne [string]::Empty){
       
                if($userObj = Get-ADUser -Filter {SamAccountName -eq $userFilter} -Server $domName -SearchBase $ouName -Properties MemberOf){
                    Write-Host -f Cyan "Пользователь '$userFilter' состоит в следующих группах:"
                    ($userObj).MemberOf
                }else{
                    Write-Host -f Red "что-то не находит этого пользователя"
                }
            }
            recurseFunction
        }
        11 {
            #какие пользователи состоят в группе
            $groupFilter = createFilter(@("Введи имя группы", $true))

            if($groupFilter -ne [string]::Empty){       
                if($groupObj = Get-ADGroup -Filter {name -eq $groupFilter} -Server $domName -SearchBase $ouName){
                    Write-Host -f Cyan "В группе '$groupFilter' состоят следующие пользователи:"
                    ($groupObj | Get-ADGroupMember).distinguishedName
                }else{
                    Write-Host -f Red "что-то не находит эту группу"
                }
            }
            recurseFunction
        }
        12 {
            #Смена телефона, принимает SamAccountName
            $userFilter = createFilter(@("Введи имя учетки", $true))

            if($userFilter -ne [string]::Empty){
                if($usrObj = Get-ADUser -Filter {SamAccountName -eq $userFilter} -Server $domName -SearchBase $ouName){
                    $phone = Read-Host "Введи номер телефона для пользователя"
                    try{
                        $usrObj | Set-ADUser -OfficePhone $phone -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -InformationAction SilentlyContinue
                    }
                    catch{
                        Write-Host -f red "Cмена номера завершилась ошибкой"
                    }
                    finally{
                    Write-Host -f Cyan "Для '$userFilter' телефонный номер:" (Get-ADUser -Filter {SamAccountName -eq $userFilter} -Server $domName -SearchBase $ouName -Properties telephoneNumber).telephoneNumber
                    }
                }else{
                    Write-Host -f Red "Поиск пользователя закончился неудачно"
                }
            }

            recurseFunction
        }
        default {
            clear
            recurseFunction
        }
    }
}

mainFunction
