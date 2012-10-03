function Get-ServicesWithOwnProcess { 
	<#
		.Synopsis
            Возвращает массив идентификаторов служб, выделенных нами в отдельный процесс.
		.Description
            Возвращает массив идентификаторов служб, выделенных нами в отдельный процесс.
		.Example
			Get-ServicesWithOwnProcess `
            | Set-ServiceCommonProcess
	#>
  
    get-itemProperty `
         -path HKLM:'\Software\Microsoft\Windows NT\CurrentVersion\Svchost' `
    | get-member -memberType NoteProperty `
    | ? {$_.name -match 'netsvc_(?<svc>.+)'} `
    | % {
         $matches['svc'];
    }; 
};

function Get-ServicesWithCommonProcess { 
	<#
		.Synopsis
            Возвращает массив идентификаторов служб, использующих процесс svchost.exe (группа netsvcs).
		.Description
            Возвращает массив идентификаторов служб, использующих процесс svchost.exe (группа netsvcs).
		.Example
			Get-ServicesWithCommonProcess `
            | Set-ServiceOwnProcess
	#>
  
    (Get-ItemProperty `
        -path HKLM:'\Software\Microsoft\Windows NT\CurrentVersion\Svchost' `
        -name netsvcs `
    ).netsvcs `
    | ? {Test-Path HKLM:"\SYSTEM\CurrentControlSet\Services\$($_)"} `
    ;
};


function Set-ServiceOwnProcess { 
	<#
		.Synopsis
            Выделение для указанного сервиса собственного процесса svchost.exe.
		.Description
            Выделение для указанного сервиса собственного процесса svchost.exe.
		.Parameter service
		    Идентификатор службы
		.Example
			Set-ServiceOwnProcess `
                -service 'AppMgmt' 
	#>
  
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Low'
    )]
    param (
    	[Parameter(
            Mandatory=$true,
            Position=0,
            ValueFromPipeline=$true,
            HelpMessage="Идентификатор службы."
		)]
        [string]$service
    )

    $service `
    | ? {Test-Path HKLM:"\SYSTEM\CurrentControlSet\Services\$($_)"} `
    | ? {
        (Get-ItemProperty `
            -path HKLM:'\Software\Microsoft\Windows NT\CurrentVersion\Svchost' `
            -name netsvcs `
        ).netsvcs -contains $_ `
    } `
    | % {
        $newSvcGroupKey = New-ItemProperty `
            -path HKLM:'\Software\Microsoft\Windows NT\CurrentVersion\Svchost' `
            -name "netsvc_$($_)" `
            -value ([System.String[]]@($_)) `
            -force `
        ;
        Set-ItemProperty `
            -path HKLM:"\SYSTEM\CurrentControlSet\Services\$($_)" `
            -name ImagePath `
            -value “%systemroot%\system32\svchost.exe -k netsvc_$($_)” `
            -force `
        ;

        Set-ItemProperty `
            -path HKLM:'\Software\Microsoft\Windows NT\CurrentVersion\Svchost' `
            -name netsvcs `
            -value ( `
                (Get-ItemProperty `
                    -path HKLM:'\Software\Microsoft\Windows NT\CurrentVersion\Svchost' `
                    -name netsvcs `
                ).netsvcs -notmatch $_ `
            ) `
            -force `
        ;
    }; 
};

function Set-ServiceCommonProcess { 
	<#
		.Synopsis
            Возвращаем сервис в "групповой" процесс svchost.exe (группа netsvc).
		.Description
            Возвращаем сервис в "групповой" процесс svchost.exe (группа netsvc).
		.Parameter service
		    Идентификатор службы
		.Example
			Set-ServiceCommonProcess `
                -service 'AppMgmt' 
	#>
  
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Low'
    )]
    param (
    	[Parameter(
            Mandatory=$true,
            Position=0,
            ValueFromPipeline=$true,
            HelpMessage="Идентификатор службы."
		)]
        [string]$service
    )

    $service `
    | ? {Test-Path HKLM:"\SYSTEM\CurrentControlSet\Services\$($_)"} `
    | ? {
        (Get-ItemProperty `
            -path HKLM:'\Software\Microsoft\Windows NT\CurrentVersion\Svchost' `
            -name netsvcs `
        ).netsvcs -notcontains $_ `
    } `
    | % {
        Set-ItemProperty `
            -path HKLM:'\Software\Microsoft\Windows NT\CurrentVersion\Svchost' `
            -name netsvcs `
            -value ( `
                (Get-ItemProperty `
                    -path HKLM:'\Software\Microsoft\Windows NT\CurrentVersion\Svchost' `
                    -name netsvcs `
                ).netsvcs + $_ `
                | sort -unique `
            ) `
            -force `
        ;

        Set-ItemProperty `
            -path HKLM:"\SYSTEM\CurrentControlSet\Services\$($_)" `
            -name ImagePath `
            -value “%systemroot%\system32\svchost.exe -k netsvcs” `
            -force `
        ;

        Remove-ItemProperty `
            -path HKLM:'\Software\Microsoft\Windows NT\CurrentVersion\Svchost' `
            -name "netsvc_$($_)" `
        ;
    }; 
};

Export-ModuleMember `
    Get-ServicesWithOwnProcess, `
    Get-ServicesWithCommonProcess, `
    Set-ServiceOwnProcess, `
    Set-ServiceCommonProcess