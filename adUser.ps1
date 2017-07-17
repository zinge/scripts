Import-Module ActiveDirectory
$domName = "<EDIT>.<EDIT>.<EDIT>"
$ouName = "ou=<EDIT>,dc=<EDIT>,dc=<EDIT>,dc=<EDIT>"

function recurseFunction{
    [string]$action  = Read-Host "Повторим?(Y|N)"

    if($action -match "[yY]|[дД]"){
        mainFunction
    }elseif($action -match "[nN]|[нН]"){
        Write-Host -f Green "Пока"
    }else{
        Write-Host -f Yellow "Ничего не понял, на всякий случай СТОП"
    }
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
            #Инфомация о пользователе, по начальным буквам Name (в ответе возможны множественные данные)
            [string]$uName = Read-Host "Введи начало фамилии"

            if($uName -eq [string]::Empty){
                [string ]$allAction = Read-Host "Посмотрим всех ?(Y|N)"
                
                if($allAction -match "[yY]|[дД]"){
                    $userFilter = "*"
                }else{
                    Write-Host -f red "Нужны данные для продолжения"
                    $userFilter = ""
                }
            }else{

                $userFilter = $($uName+"*")
            }

            if($userFilter -ne [string]::Empty){
                $matchUsers = Get-ADUser -Filter {Name -like $userFilter} -Server $domName -SearchBase $ouName -Properties `
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

                if($matchUsers){
                    $matchUsers | format-list
                }else{
                    write-host -f red "Ничего не найдено"
                }
            }

            recurseFunction      
        }
        2 {
            #Смена пароля, принимает SamAccountName
            [string]$samName = Read-Host "Введи имя учетки"

            if($samName -eq [string]::Empty){
                Write-Host -f red "Нужны данные для продолжения"
            }else{
                if($uObj = Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName){
                    $pass = Read-Host -AsSecureString "Введи пароль для пользователя"
                    try{
                        Set-ADAccountPassword $uObj -Reset -NewPassword $pass
                    }
                    catch{
                        Write-Host -f red "Cмена пароля завершилась ошибкой"
                    }
                    finally{
                    Write-Host -f Cyan "Для '$samName' меняли пароль:" (Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName -Properties PasswordLastSet).PasswordLastSet
                    }
                }else{
                    Write-Host -f Red "Поиск пользователя закончился неудачей"
                }
            }

            recurseFunction
        }
        3 {
            #Блокировка пользователя, принимает SamAccountName
            [string]$samName = Read-Host "Введи имя учетки"
            
            if($samName -eq [string]::Empty){
                Write-Host -f red "Нужны данные для продолжения"
            }else{

                try{
                    Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName | Disable-ADAccount
                }
                catch{
                    Write-Host -f red "Блокировка пользователя завершилась ошибкой"
                }
                finally{
                    if ((Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName).Enabled){
                        Write-Host -f Cyan "'$samName' не заблокирован"
                    }else{
                        Write-Host -f Cyan "'$samName' заблокирован"
                    }
                }
            }

            recurseFunction
        }
        4 {
            #Разблокировка пользователя, принимает SamAccountName
            [string]$samName = Read-Host "Введи имя учетки"
            if($samName -eq [string]::Empty){
                Write-Host -f red "Нужны данные для продолжения"
            }else{

                try{
                    Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName | Unlock-ADAccount
                    Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName | Enable-ADAccount
                }
                catch{
                    Write-Host "Разблокировка пользователя завершилась ошибкой"
                }
                 finally{
                    if ((Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName).Enabled){
                        Write-Host -f Cyan "'$samName' не заблокирован"
                    }else{
                        Write-Host -f Cyan "'$samName' заблокирован"
                    }
                }
            }
            recurseFunction
        }
        5 {
            #Показать заблокированных пользователей
            $matchUsers = Get-ADUser -Filter {enabled -eq "False"} -Server $domName -SearchBase $ouName -Properties `
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
            if($matchUsers){
                $matchUsers | format-list
            }else{
                write-host -f red "Ничего не найдено"
            }

            recurseFunction
        }
        6 {
            #Показать информацию о группах
            [string]$groupName = Read-Host "Введи часть имени группы"
            
            if($groupName -eq [string]::Empty){
                $groupFilter = "*"
            }else{
                $groupFilter = $("*"+$groupName+"*")
            }

            $matchGroups = Get-ADGroup -Filter {Name -like $groupFilter} -Server $domName -SearchBase $ouName | Select-Object Name
            
            if($matchGroups){
                $matchGroups | Format-List
            }else{
                Write-Host -f Red "Ничего не найдено"
            }

            recurseFunction
        }
        7 {
            #добавить в группу
            [string]$samName = Read-Host "Введи имя учетки"
            [string]$groupName = Read-Host "Введи имя группы"
            
            if(($samName -eq [string]::Empty) -OR ($groupName -eq [string]::Empty)){
                Write-Host -f red "Нужны данные для продолжения"
            }else{
                $userObj = Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName
                if($userObj){
                    $groupObj = Get-ADGroup -Filter {Name -eq $groupName} -Server $domName -SearchBase $ouName
                    if($groupObj){
                        try{
                            Add-ADGroupMember -Identity $groupObj -Members $userObj -Server $domName
                        }
                        catch{
                            Write-Host -f Red `
                            "
                            добавление пользователя
                            >> '$userObj.SamAccountName'
                            в группу
                            >> '$groupName.SamAccountName'
                            закончилось ошибкой
                            "
                        }finally{
                            Write-Host -f Cyan "Пользователь '$samName' состоит в следующих группах:"
                            (Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName -Properties MemberOf).MemberOf
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
            [string]$samName = Read-Host "Введи имя учетки"
            [string]$groupName = Read-Host "Введи имя группы"

            if(($samName -eq [string]::Empty) -OR ($groupName -eq [string]::Empty)){
                Write-Host -f red "Нужны данные для продолжения"
            }else{
                $userObj = Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName
                if($userObj){
                    $groupObj = Get-ADGroup -Filter {Name -eq $groupName} -Server $domName -SearchBase $ouName
                    if($groupObj){
                        try{
                            Remove-ADGroupMember -Identity $groupObj -Members $userObj -Server $domName
                        }
                        catch{
                            Write-Host -f Red `
                            "
                            удаление пользователя
                            >> '$userObj.SamAccountName'
                            из группы
                            >> '$groupName.SamAccountName'
                            закончилось ошибкой
                            "
                        }finally{
                            Write-Host -f Cyan "Пользователь '$samName' состоит в следующих группах:"
                            (Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName -Properties MemberOf).MemberOf
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
                    New-ADGroup -Path "OU=ФункциональныеГруппы,$ouName" -GroupScope Global -GroupCategory Security -SamAccountName $groupSamName -DisplayName $groupName -Name $groupSamName -Description $groupName
                }
                catch{
                    Write-Host -f Red "что-то пошло не так(("
                }
                finally{
                    Get-ADGroup -Filter * -Server $domName -SearchBase $ouName 
                }
            }
            recurseFunction
        }
        10 {
            #в каких группах состоит пользователь
            [string]$samName = Read-Host "Введи имя учетки"

            if($samName -eq [string]::Empty){
                Write-Host -f red "Нужны данные для продолжения"
            }else{          
                $userObj = Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName
                if($userObj){
                    Write-Host -f Cyan "Пользователь '$samName' состоит в следующих группах:"
                    (Get-ADUser -Filter {SamAccountName -eq $samName} -Server $domName -SearchBase $ouName -Properties MemberOf).MemberOf
                }else{
                    Write-Host -f Red "что-то не находит пользователя '$samName'"
                }
            }
            recurseFunction
        }
        11 {
            #какие пользователи состоят в группе
            [string]$groupName = Read-Host "Введи имя группы"

            if($groupName -eq [string]::Empty){
                Write-Host -f red "Нужны данные для продолжения"
            }else{          
                $groupObj = Get-ADGroup -Filter {name -eq $groupName} -Server $domName -SearchBase $ouName
                if($groupObj){
                    Write-Host -f Cyan "В группе '$groupName' состоят следующие пользователи:"
                    ($groupObj | Get-ADGroupMember).distinguishedName
                }else{
                    Write-Host -f Red "что-то не находит группу '$groupName'"
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
