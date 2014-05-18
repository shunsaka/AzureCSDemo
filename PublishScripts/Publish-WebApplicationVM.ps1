#Requires -Version 3.0

<#
.SYNOPSIS
Visual Studio Web プロジェクトに Windows Azure 仮想マシンを作成して配置します。
詳細については、次を参照してください: http://go.microsoft.com/fwlink/?LinkID=394472 

.EXAMPLE
PS C:\> .\Publish-WebApplicationVM.ps1 `
-Configuration .\Configurations\WebApplication1-VM-dev.json `
-WebDeployPackage ..\WebApplication1\WebApplication1.zip `
-VMPassword @{Name = "admin"; Password = "password"} `
-AllowUntrusted `
-Verbose


#>
[CmdletBinding(HelpUri = 'http://go.microsoft.com/fwlink/?LinkID=391696')]
param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [String]
    $Configuration,

    [Parameter(Mandatory = $false)]
    [String]
    $SubscriptionName,

    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [String]
    $WebDeployPackage,

    [Parameter(Mandatory = $false)]
    [Switch]
    $AllowUntrusted,

    [Parameter(Mandatory = $false)]
    [ValidateScript( { $_.Contains('Name') -and $_.Contains('Password') } )]
    [Hashtable]
    $VMPassword,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ !($_ | Where-Object { !$_.Contains('Name') -or !$_.Contains('Password')}) })]
    [Hashtable[]]
    $DatabaseServerPassword,

    [Parameter(Mandatory = $false)]
    [Switch]
    $SendHostMessagesToOutput = $false
)


function New-WebDeployPackage
{
    #Web アプリケーションのビルドとパッケージ化を行う関数を作成します

    #Web アプリケーションをビルドするには、MsBuild.exe を使用します。詳細については、次の「MSBuild Command-Line Reference (MSBuild コマンド ライン リファレンス)」を参照してください: http://go.microsoft.com/fwlink/?LinkId=391339
}

function Test-WebApplication
{
    #Web アプリケーションで単体テストを実行するようにこの関数を編集します

    #Web アプリケーションで単体テストを実行する関数を作成するには、VSTest.Console.exe を使用します。詳細については、「VSTest.Console Command-Line Reference (VSTest.Console コマンド ライン リファレンス)」(http://go.microsoft.com/fwlink/?LinkId=391340) を参照してください
}

function New-AzureWebApplicationVMEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Object]
        $Configuration,

        [Parameter (Mandatory = $false)]
        [AllowNull()]
        [Hashtable]
        $VMPassword,

        [Parameter (Mandatory = $false)]
        [AllowNull()]
        [Hashtable[]]
        $DatabaseServerPassword
    )
   
    $VMInfo = New-AzureVMEnvironment `
        -CloudServiceConfiguration $Config.cloudService `
        -VMPassword $VMPassword

    # SQL データベースを作成します。接続文字列は配置に使用されます。
    $connectionString = New-Object -TypeName Hashtable
    
    if ($Config.Contains('databases'))
    {
        @($Config.databases) |
            Where-Object {$_.connectionStringName -ne ''} |
            Add-AzureSQLDatabases -DatabaseServerPassword $DatabaseServerPassword |
            ForEach-Object { $connectionString.Add($_.Name, $_.ConnectionString) }           
    }
    
    return @{ConnectionString = $connectionString; VMInfo = $VMInfo}   
}

function Publish-AzureWebApplicationToVM
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Object]
        $Config,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Hashtable]
        $ConnectionString,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]
        $WebDeployPackage,
        
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Hashtable]
        $VMInfo           
    )
    $waitingTime = $VMWebDeployWaitTime

    $result = $null
    $attempts = 0
    $allAttempts = 60
    do 
    {
        $result = Publish-WebPackageToVM `
            -VMDnsName $VMInfo.VMUrl `
            -IisWebApplicationName $Config.webDeployParameters.IisWebApplicationName `
            -WebDeployPackage $WebDeployPackage `
            -UserName $VMInfo.UserName `
            -UserPassword $VMInfo.Password `
            -AllowUntrusted:$AllowUntrusted `
            -ConnectionString $ConnectionString
         
        if ($result)
        {
            Write-VerboseWithTime ($scriptName + ' VM に発行できました。')
        }
        elseif ($VMInfo.IsNewCreatedVM -and !$Config.cloudService.virtualMachine.enableWebDeployExtension)
        {
            Write-VerboseWithTime ($scriptName + ' "enableWebDeployExtension" を $true に設定する必要があります。')
        }
        elseif (!$VMInfo.IsNewCreatedVM)
        {
            Write-VerboseWithTime ($scriptName + ' 既存の VM では Web Deploy をサポートしていません。')
        }
        else
        {
            Write-VerboseWithTime ('{0}: Publishing to VM failed. Attempt {1} of {2}.' -f $scriptName, ($attempts + 1), $allAttempts)
            Write-VerboseWithTime ('{0}: Publishing to VM will start after {1} seconds.' -f $scriptName, $waitingTime)
            
            Start-Sleep -Seconds $waitingTime
        }
                                                                                                                       
         $attempts++
    
         #新しく作成し、Web Deploy をインストールしている仮想マシンにのみ再発行してください。 
    } While( !$result -and $VMInfo.IsNewCreatedVM -and $attempts -lt $allAttempts -and $Config.cloudService.virtualMachine.enableWebDeployExtension)
    
    if (!$result)
    {                    
        Write-Warning ' 仮想マシンへの発行に失敗しました。信頼されていない証明書または無効な証明書が原因と考えられます。-AllowUntrusted を指定して、信頼されていない証明書を受け入れることができます。'
        throw ($scriptName + ' VM に発行できませんでした。')
    }
}

# スクリプト メイン ルーチン
Set-StrictMode -Version 3

Remove-Module AzureVMPublishModule -ErrorAction SilentlyContinue
$scriptDirectory = Split-Path -Parent $PSCmdlet.MyInvocation.MyCommand.Definition
Import-Module ($scriptDirectory + '\AzureVMPublishModule.psm1') -Scope Local -Verbose:$false

New-Variable -Name VMWebDeployWaitTime -Value 30 -Option Constant -Scope Script 
New-Variable -Name AzureWebAppPublishOutput -Value @() -Scope Global -Force
New-Variable -Name SendHostMessagesToOutput -Value $SendHostMessagesToOutput -Scope Global -Force

try
{
    $originalErrorActionPreference = $Global:ErrorActionPreference
    $originalVerbosePreference = $Global:VerbosePreference
    
    if ($PSBoundParameters['Verbose'])
    {
        $Global:VerbosePreference = 'Continue'
    }
    
    $scriptName = $MyInvocation.MyCommand.Name + ':'
    
    Write-VerboseWithTime ($scriptName + ' 開始')
    
    $Global:ErrorActionPreference = 'Stop'
    Write-VerboseWithTime ('{0} $ErrorActionPreference は {1} に設定されます' -f $scriptName, $ErrorActionPreference)
    
    Write-Debug ('{0}: $PSCmdlet.ParameterSetName = {1}' -f $scriptName, $PSCmdlet.ParameterSetName)

    # 現在のサブスクリプションを保存します。このスクリプトでは、後でサブスクリプションを Current ステータスに復元します
    Backup-Subscription -UserSpecifiedSubscription $SubscriptionName
    
    # Azure モジュール バージョン 0.7.4 以降があることを検証します。
    if (-not (Test-AzureModule))
    {
         throw '旧バージョンの Windows Azure PowerShell を使用しています。最新バージョンをインストールするには、http://go.microsoft.com/fwlink/?LinkID=320552 を参照してください。'
    }
    
    if ($SubscriptionName)
    {

        # サブスクリプション名を指定した場合は、アカウントにサブスクリプションが存在することを検証します。
        if (!(Get-AzureSubscription -SubscriptionName $SubscriptionName))
        {
            throw ("{0}: サブスクリプション名 $SubscriptionName が見つかりません" -f $scriptName)

        }

        # 指定されたサブスクリプションを現在のサブスクリプションに設定します。
        Select-AzureSubscription -SubscriptionName $SubscriptionName | Out-Null

        Write-VerboseWithTime ('{0}: サブスクリプションは {1} に設定されます' -f $scriptName, $SubscriptionName)
    }

    $Config = Read-ConfigFile $Configuration -HasWebDeployPackage:([Bool]$WebDeployPackage)

    #Web アプリケーションをビルドしてパッケージ化します
    New-WebDeployPackage

    #Web アプリケーションで単体テストを実行します
    Test-WebApplication

    #JSON 構成ファイルに示されている Azure 環境を作成します

    $newEnvironmentResult = New-AzureWebApplicationVMEnvironment -Configuration $Config -DatabaseServerPassword $DatabaseServerPassword -VMPassword $VMPassword

    #$WebDeployPackage がユーザーによって指定されている場合、Web アプリケーション パッケージを配置します 
    if($WebDeployPackage)
    {
        Publish-AzureWebApplicationToVM `
            -Config $Config `
            -ConnectionString $newEnvironmentResult.ConnectionString `
            -WebDeployPackage $WebDeployPackage `
            -VMInfo $newEnvironmentResult.VMInfo
    }
}
finally
{
    $Global:ErrorActionPreference = $originalErrorActionPreference
    $Global:VerbosePreference = $originalVerbosePreference

    # 元の現在のサブスクリプションを Current ステータスに復元します
    Restore-Subscription

    Write-Output $Global:AzureWebAppPublishOutput    
    $Global:AzureWebAppPublishOutput = @()
}
