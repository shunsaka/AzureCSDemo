#  AzureVMPublishModule.psm1 は Windows PowerShell スクリプト モジュールです。このモジュールは、Web アプリケーションのライフ サイクル管理を自動化する Windows PowerShell 関数をエクスポートします。この関数をそのまま使用するか、アプリケーションや発行環境用にカスタマイズすることができます。

Set-StrictMode -Version 3

# 元のサブスクリプションを保存する変数。
$Script:originalCurrentSubscription = $null

# 元のストレージ アカウントを保存する変数。
$Script:originalCurrentStorageAccount = $null

# ユーザーが指定したサブスクリプションのストレージ アカウントを保存する変数。
$Script:originalStorageAccountOfUserSpecifiedSubscription = $null

# サブスクリプション名を保存する変数。
$Script:userSpecifiedSubscription = $null

# Web 配置のポート番号
New-Variable -Name WebDeployPort -Value 8172 -Option Constant

<#
.SYNOPSIS
メッセージの先頭に日付と時刻を付加します。

.DESCRIPTION
メッセージの先頭に日付と時刻を付加します。この関数は、Error および Verbose ストリームに書き込まれるメッセージを対象に設計されています。

.PARAMETER  Message
日付のないメッセージを指定します。

.INPUTS
System.String

.OUTPUTS
System.String

.EXAMPLE
PS C:\> Format-DevTestMessageWithTime -Message "ディレクトリへのファイル $filename の追加"
2/5/2014 1:03:08 PM - ディレクトリへのファイル $filename の追加

.LINK
Write-VerboseWithTime

.LINK
Write-ErrorWithTime
#>
function Format-DevTestMessageWithTime
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory = $true, ValueFromPipeline = $true)]
        [String]
        $Message
    )

    return ((Get-Date -Format G)  + ' - ' + $Message)
}


<#

.SYNOPSIS
現在時刻が先頭に付加されたエラー メッセージを書き込みます。

.DESCRIPTION
現在時刻が先頭に付加されたエラー メッセージを書き込みます。この関数は、Format-DevTestMessageWithTime 関数を呼び出して、先頭に時刻を付加してからメッセージを Error ストリームに書き込みます。

.PARAMETER  Message
エラー メッセージ呼び出しのメッセージを指定します。関数にメッセージ文字列をパイプできます。

.INPUTS
System.String

.OUTPUTS
なし。関数は Error ストリームに書き込みます。

.EXAMPLE
PS C:> Write-ErrorWithTime -Message "Failed. Cannot find the file."

Write-Error: 2/6/2014 8:37:29 AM - Failed. Cannot find the file.
 + CategoryInfo     : NotSpecified: (:) [Write-Error], WriteErrorException
 + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException

.LINK
Write-Error

#>
function Write-ErrorWithTime
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory = $true, ValueFromPipeline = $true)]
        [String]
        $Message
    )

    $Message | Format-DevTestMessageWithTime | Write-Error
}


<#
.SYNOPSIS
現在時刻が先頭に付加された詳細メッセージを書き込みます。

.DESCRIPTION
現在時刻が先頭に付加された詳細メッセージを書き込みます。Write-Verbose を呼び出すので、Verbose パラメーターを指定してスクリプトを実行する場合または VerbosePreference 設定を Continue に設定している場合にのみ、メッセージが表示されます。

.PARAMETER  Message
詳細メッセージ呼び出しのメッセージを指定します。関数にメッセージ文字列をパイプできます。

.INPUTS
System.String

.OUTPUTS
なし。関数は Verbose ストリームに書き込みます。

.EXAMPLE
PS C:> Write-VerboseWithTime -Message "The operation succeeded."
PS C:>
PS C:\> Write-VerboseWithTime -Message "The operation succeeded." -Verbose
VERBOSE: 1/27/2014 11:02:37 AM - The operation succeeded.

.EXAMPLE
PS C:\ps-test> "The operation succeeded." | Write-VerboseWithTime -Verbose
VERBOSE: 1/27/2014 11:01:38 AM - The operation succeeded.

.LINK
Write-Verbose
#>
function Write-VerboseWithTime
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory = $true, ValueFromPipeline = $true)]
        [String]
        $Message
    )

    $Message | Format-DevTestMessageWithTime | Write-Verbose
}


<#
.SYNOPSIS
現在時刻が先頭に付加されたホスト メッセージを書き込みます。

.DESCRIPTION
この関数は、現在時刻が先頭に付加されたメッセージをホスト プログラム (Write-Host) に書き込みます。ホスト プログラムへの書き込み結果は一定ではありません。Windows PowerShell をホストするほとんどのプログラムは、このようなメッセージを標準出力に書き込みます。

.PARAMETER  Message
日付のない基本メッセージを指定します。関数にメッセージ文字列をパイプできます。

.INPUTS
System.String

.OUTPUTS
なし。関数はメッセージをホスト プログラムに書き込みます。

.EXAMPLE
PS C:> Write-HostWithTime -Message "操作が成功しました。"
1/27/2014 11:02:37 AM - 操作が成功しました。

.LINK
Write-Host
#>
function Write-HostWithTime
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory = $true, ValueFromPipeline = $true)]
        [String]
        $Message
    )
    
    if ((Get-Variable SendHostMessagesToOutput -Scope Global -ErrorAction SilentlyContinue) -and $Global:SendHostMessagesToOutput)
    {
        if (!(Get-Variable -Scope Global AzureWebAppPublishOutput -ErrorAction SilentlyContinue) -or !$Global:AzureWebAppPublishOutput)
        {
            New-Variable -Name AzureWebAppPublishOutput -Value @() -Scope Global -Force
        }

        $Global:AzureWebAppPublishOutput += $Message | Format-DevTestMessageWithTime
    }
    else 
    {
        $Message | Format-DevTestMessageWithTime | Write-Host
    }
}


<#
.SYNOPSIS
プロパティまたはメソッドがオブジェクトのメンバーである場合は $true を返します。それ以外の場合は $false です。

.DESCRIPTION
プロパティまたはメソッドがオブジェクトのメンバーである場合は $true を返します。クラスの静的メソッドの場合、およびビュー (PSBase、PSObject など) の場合、この関数は $false を返します。

.PARAMETER  Object
テスト内のオブジェクトを指定します。オブジェクトを含んでいる変数またはオブジェクトを返す式を入力します。この関数には、[DateTime] などの型を指定することも、オブジェクトをパイプすることもできません。

.PARAMETER  Member
テスト内のプロパティまたはメソッドの名前を指定します。メソッドを指定する場合は、メソッド名の後のかっこを省略します。

.INPUTS
なし。この関数はパイプラインからの入力を受け取りません。

.OUTPUTS
System.Boolean

.EXAMPLE
PS C:\> Test-Member -Object (Get-Date) -Member DayOfWeek
True

.EXAMPLE
PS C:\> $date = Get-Date
PS C:\> Test-Member -Object $date -Member AddDays
True

.EXAMPLE
PS C:\> [DateTime]::IsLeapYear((Get-Date).Year)
True
PS C:\> Test-Member -Object (Get-Date) -Member IsLeapYear
False

.LINK
Get-Member
#>
function Test-Member
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Object]
        $Object,

        [Parameter(Mandatory = $true)]
        [String]
        $Member
    )

    return $null -ne ($Object | Get-Member -Name $Member)
}


<#
.SYNOPSIS
Azure モジュールのバージョンが 0.7.4 以降の場合は $true を返します。それ以外の場合は $false です。

.DESCRIPTION
Test-AzureModuleVersion は、Azure モジュールのバージョンが 0.7.4 以降の場合は $true を返します。モジュールがインストールされていないか以前のバージョンの場合は、$false を返します。この関数にパラメーターはありません。

.INPUTS
なし

.OUTPUTS
System.Boolean

.EXAMPLE
PS C:\> Get-Module Azure -ListAvailable
PS C:\> #No module
PS C:\> Test-AzureModuleVersion
False

.EXAMPLE
PS C:\> (Get-Module Azure -ListAvailable).Version

Major  Minor  Build  Revision
-----  -----  -----  --------
0      7      4      -1

PS C:\> Test-AzureModuleVersion
True

.LINK
Get-Module

.LINK
PSModuleInfo object (http://msdn.microsoft.com/en-us/library/system.management.automation.psmoduleinfo(v=vs.85).aspx)
#>
function Test-AzureModuleVersion
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Version]
        $Version
    )

    return ($Version.Major -gt 0) -or ($Version.Minor -gt 7) -or ($Version.Minor -eq 7 -and $Version.Build -ge 4)
}


<#
.SYNOPSIS
インストールされている Azure モジュールのバージョンが 0.7.4 以降の場合は $true を返します。

.DESCRIPTION
Test-AzureModule は、インストールされている Azure モジュールのバージョンが 0.7.4 以降の場合は $true を返します。モジュールがインストールされていないか以前のバージョンの場合は、$false を返します。この関数にパラメーターはありません。

.INPUTS
なし

.OUTPUTS
System.Boolean

.EXAMPLE
PS C:\> Get-Module Azure -ListAvailable
PS C:\> #No module
PS C:\> Test-AzureModule
False

.EXAMPLE
PS C:\> (Get-Module Azure -ListAvailable).Version

Major  Minor  Build  Revision
-----  -----  -----  --------
    0      7      4      -1

PS C:\> Test-AzureModule
True

.LINK
Get-Module

.LINK
PSModuleInfo object (http://msdn.microsoft.com/en-us/library/system.management.automation.psmoduleinfo(v=vs.85).aspx)
#>
function Test-AzureModule
{
    [CmdletBinding()]

    $module = Get-Module -Name Azure

    if (!$module)
    {
        $module = Get-Module -Name Azure -ListAvailable

        if (!$module -or !(Test-AzureModuleVersion $module.Version))
        {
            return $false;
        }
        else
        {
            $ErrorActionPreference = 'Continue'
            Import-Module -Name Azure -Global -Verbose:$false
            $ErrorActionPreference = 'Stop'

            return $true
        }
    }
    else
    {
        return (Test-AzureModuleVersion $module.Version)
    }
}


<#
.SYNOPSIS
現在の Windows Azure サブスクリプションをスクリプト スコープ内の $Script:originalSubscription 変数に保存します。

.DESCRIPTION
Backup-Subscription 関数は、現在の Windows Azure サブスクリプション (Get-AzureSubscription -Current) とそのストレージ アカウント、このスクリプトによって変更されるサブスクリプション ($UserSpecifiedSubscription) とそのストレージ アカウントをスクリプト スコープ内に保存します。値を保存することで、現在のステータスが変更された場合に、Restore-Subscription などの関数を使用して、元の現在のサブスクリプションとストレージ アカウントを現在のステータスに復元できます。

.PARAMETER UserSpecifiedSubscription
新しいリソースを作成および発行するサブスクリプションの名前を指定します。関数によって、サブスクリプションとそのストレージ アカウントの名前がスクリプト スコープ内に保存されます。このパラメーターは必須です。

.INPUTS
なし

.OUTPUTS
なし

.EXAMPLE
PS C:\> Backup-Subscription -UserSpecifiedSubscription Contoso
PS C:\>

.EXAMPLE
PS C:\> Backup-Subscription -UserSpecifiedSubscription Contoso -Verbose
VERBOSE: Backup-Subscription: Start
VERBOSE: Backup-Subscription: Original subscription is Windows Azure MSDN - Visual Studio Ultimate
VERBOSE: Backup-Subscription: End
#>
function Backup-Subscription
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $UserSpecifiedSubscription
    )

    Write-VerboseWithTime 'Backup-Subscription: 開始'

    $Script:originalCurrentSubscription = Get-AzureSubscription -Current -ErrorAction SilentlyContinue
    if ($Script:originalCurrentSubscription)
    {
        Write-VerboseWithTime ('Backup-Subscription: 元のサブスクリプション: ' + $Script:originalCurrentSubscription.SubscriptionName)
        $Script:originalCurrentStorageAccount = $Script:originalCurrentSubscription.CurrentStorageAccountName
    }
    
    $Script:userSpecifiedSubscription = $UserSpecifiedSubscription
    if ($Script:userSpecifiedSubscription)
    {        
        $userSubscription = Get-AzureSubscription -SubscriptionName $Script:userSpecifiedSubscription -ErrorAction SilentlyContinue
        if ($userSubscription)
        {
            $Script:originalStorageAccountOfUserSpecifiedSubscription = $userSubscription.CurrentStorageAccountName
        }        
    }

    Write-VerboseWithTime 'Backup-Subscription: 終了'
}


<#
.SYNOPSIS
スクリプト スコープ内の $Script:originalSubscription 変数に保存されている Windows Azure サブスクリプションを "current" ステータスに復元します。

.DESCRIPTION
Restore-Subscription 関数は、$Script:originalSubscription 変数に保存されているサブスクリプションを現在のサブスクリプションに (もう一度) 設定します。元のサブスクリプションにストレージ アカウントがある場合、この関数はストレージ アカウントを現在のサブスクリプションに対する現在のストレージ アカウントに設定します。この関数は、環境内に null ではない $SubscriptionName 変数が存在している場合にのみ、サブスクリプションを復元します。それ以外の場合は、終了します。$SubscriptionName に値が設定されていても $Script:originalSubscription が $null の場合、Restore-Subscription は Select-AzureSubscription コマンドレットを使用して、Windows Azure PowerShell でのサブスクリプションの現在および既定の設定をクリアします。この関数にパラメーターはなく、入力を受け取りません。また、何も返しません (void を返します)。-Verbose を使用すると、メッセージを Verbose ストリームに書き込むことができます。

.INPUTS
なし

.OUTPUTS
なし

.EXAMPLE
PS C:\> Restore-Subscription
PS C:\>

.EXAMPLE
PS C:\> Restore-Subscription -Verbose
VERBOSE: Restore-Subscription: Start
VERBOSE: Restore-Subscription: End
#>
function Restore-Subscription
{
    [CmdletBinding()]
    param()

    Write-VerboseWithTime 'Restore-Subscription: 開始'

    if ($Script:originalCurrentSubscription)
    {
        if ($Script:originalCurrentStorageAccount)
        {
            Set-AzureSubscription `
                -SubscriptionName $Script:originalCurrentSubscription.SubscriptionName `
                -CurrentStorageAccountName $Script:originalCurrentStorageAccount
        }

        Select-AzureSubscription -SubscriptionName $Script:originalCurrentSubscription.SubscriptionName
    }
    else 
    {
        Select-AzureSubscription -NoCurrent
        Select-AzureSubscription -NoDefault
    }
    
    if ($Script:userSpecifiedSubscription -and $Script:originalStorageAccountOfUserSpecifiedSubscription)
    {
        Set-AzureSubscription `
            -SubscriptionName $Script:userSpecifiedSubscription `
            -CurrentStorageAccountName $Script:originalStorageAccountOfUserSpecifiedSubscription
    }

    Write-VerboseWithTime 'Restore-Subscription: 終了'
}

<#
.SYNOPSIS
現在のサブスクリプションで "devtest*" という名前の Windows Azure ストレージ アカウントを見つけます。

.DESCRIPTION
Get-AzureVMStorage 関数は、指定された場所またはアフィニティ グループの最初のストレージ アカウントの名前を "devtest*" という名前パターン (大文字と小文字を区別しない) で返します。"devtest*" ストレージ アカウントが場所またはアフィニティ グループと一致しない場合、関数はこれを無視します。場所またはアフィニティ グループを指定する必要があります。

.PARAMETER  Location
ストレージ アカウントの場所を指定します。有効な値は、"West US" などの Windows Azure の場所です。場所またはアフィニティ グループを入力できますが、両方を入力することはできません。

.PARAMETER  AffinityGroup
ストレージ アカウントのアフィニティ グループを指定します。場所またはアフィニティ グループを入力できますが、両方を入力することはできません。

.INPUTS
なし。この関数には入力をパイプできません。

.OUTPUTS
System.String

.EXAMPLE
PS C:\> Get-AzureVMStorage -Location "East US"
devtest3-fabricam

.EXAMPLE
PS C:\> Get-AzureVMStorage -AffinityGroup Finance
PS C:\>

.EXAMPLE\
PS C:\> Get-AzureVMStorage -AffinityGroup Finance -Verbose
VERBOSE: Get-AzureVMStorage: Start
VERBOSE: Get-AzureVMStorage: End

.LINK
Get-AzureStorageAccount
#>
function Get-AzureVMStorage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'Location')]
        [String]
        $Location,

        [Parameter(Mandatory = $true, ParameterSetName = 'AffinityGroup')]
        [String]
        $AffinityGroup
    )

    Write-VerboseWithTime 'Get-AzureVMStorage: 開始'

    $storages = @(Get-AzureStorageAccount -ErrorAction SilentlyContinue)
    $storageName = $null

    foreach ($storage in $storages)
    {
        # 名前が "devtest" で始まる最初のストレージ アカウントを取得します
        if ($storage.Label -like 'devtest*')
        {
            if ($storage.AffinityGroup -eq $AffinityGroup -or $storage.Location -eq $Location)
            {
                $storageName = $storage.Label

                    Write-HostWithTime ('Get-AzureVMStorage: devtest ストレージ アカウントが見つかりました: ' + $storageName)
                    $storage | Out-String | Write-VerboseWithTime
                break
            }
        }
    }

    Write-VerboseWithTime 'Get-AzureVMStorage: 終了'
    return $storageName
}


<#
.SYNOPSIS
名前が "devtest" で始まる新しい Windows Azure ストレージ アカウントを作成します。

.DESCRIPTION
Add-AzureVMStorage 関数は、現在のサブスクリプションに新しい Windows Azure ストレージ アカウントを作成します。アカウントの名前は "devtest" で始まり、その直後には一意の英数字文字列が使用されます。関数は新しいストレージ アカウントの名前を返します。新しいストレージ アカウントの場所またはアフィニティ グループを指定する必要があります。

.PARAMETER  Location
ストレージ アカウントの場所を指定します。有効な値は、"West US" などの Windows Azure の場所です。場所またはアフィニティ グループを入力できますが、両方を入力することはできません。

.PARAMETER  AffinityGroup
ストレージ アカウントのアフィニティ グループを指定します。場所またはアフィニティ グループを入力できますが、両方を入力することはできません。

.INPUTS
なし。この関数には入力をパイプできません。

.OUTPUTS
System.String. 文字列は新しいストレージ アカウントの名前です

.EXAMPLE
PS C:\> Add-AzureVMStorage -Location "East Asia"
devtestd6b45e23a6dd4bdab

.EXAMPLE
PS C:\> Add-AzureVMStorage -AffinityGroup Finance
devtestd6b45e23a6dd4bdab

.EXAMPLE
PS C:\> Add-AzureVMStorage -AffinityGroup Finance -Verbose
VERBOSE: Add-AzureVMStorage: Start
VERBOSE: Add-AzureVMStorage: Created new storage acccount devtestd6b45e23a6dd4bdab"
VERBOSE: Add-AzureVMStorage: End
devtestd6b45e23a6dd4bdab

.LINK
New-AzureStorageAccount
#>
function Add-AzureVMStorage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'Location')]
        [String]
        $Location,

        [Parameter(Mandatory = $true, ParameterSetName = 'AffinityGroup')]
        [String]
        $AffinityGroup
    )

    Write-VerboseWithTime 'Add-AzureVMStorage: 開始'

    # GUID の一部を "devtest" に付加して一意の名前を作成します
    $name = 'devtest'
    $suffix = [guid]::NewGuid().ToString('N').Substring(0,24 - $name.Length)
    $name = $name + $suffix

    # 場所/アフィニティ グループを使用して新しい Windows Azure ストレージ アカウントを作成します
    if ($PSCmdlet.ParameterSetName -eq 'Location')
    {
        New-AzureStorageAccount -StorageAccountName $name -Location $Location | Out-Null
    }
    else
    {
        New-AzureStorageAccount -StorageAccountName $name -AffinityGroup $AffinityGroup | Out-Null
    }

    Write-HostWithTime ("Add-AzureVMStorage: 新しいストレージ アカウント $name を作成しました")
    Write-VerboseWithTime 'Add-AzureVMStorage: 終了'
    return $name
}


<#
.SYNOPSIS
構成ファイルを検証し、構成ファイル値のハッシュ テーブルを返します。

.DESCRIPTION
Read-ConfigFile 関数は、JSON 構成ファイルを検証し、選択された値のハッシュ テーブルを返します。
-- 最初に、JSON ファイルを PSCustomObject に変換します。
クラウド サービスのハッシュ テーブルに存在するキーは次のとおりです:
-- webdeployparameters : 省略可能。$null または空にできます。
-- Databases: SQL データベース

.PARAMETER  ConfigurationFile
Web プロジェクト用 JSON 構成ファイルのパスと名前を指定します。Web プロジェクトの作成時に Visual Studio によって JSON ファイルが自動生成され、ソリューションの PublishScripts フォルダーに格納されます。

.PARAMETER HasWebDeployPackage
Web アプリケーション用の Web 配置パッケージの ZIP ファイルがあることを示します。$true の値を指定するには、-HasWebDeployPackage または HasWebDeployPackage:$true を使用します。false の値を指定するには、HasWebDeployPackage:$false を使用します。このパラメーターは必須です。

.INPUTS
なし。この関数には入力をパイプできません。

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
PS C:\> Read-ConfigFile -ConfigurationFile <path> -HasWebDeployPackage


Name                           Value                                                                                                                                                                     
----                           -----                                                                                                                                                                     
databases                      {@{connectionStringName=; databaseName=; serverName=; user=; password=}}                                                                                                  
cloudService                   @{name="contoso"; affinityGroup="contosoEast"; location=; virtualNetwork=; subnet=; availabilitySet=; virtualMachine=}                                                      
webDeployParameters            @{iisWebApplicationName="Default Web Site"} 
#>
function Read-ConfigFile
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]
        $ConfigurationFile,

        [Parameter(Mandatory = $true)]
        [Switch]
        $HasWebDeployPackage	    
    )

    Write-VerboseWithTime 'Read-ConfigFile: 開始'

    # JSON ファイルの内容を取得し (-raw は改行を無視します)、PSCustomObject に変換します
    $config = Get-Content $ConfigurationFile -Raw | ConvertFrom-Json

    if (!$config)
    {
        throw ('Read-ConfigFile: ConvertFrom-Json が失敗しました: ' + $error[0])
    }

    # environmentSettings オブジェクトに 'cloudService' プロパティがあるかどうかを確認してください (プロパティ値は関係ありません)
    $hasCloudServiceProperty = Test-Member -Object $config.environmentSettings -Member 'cloudService'

    if (!$hasCloudServiceProperty)
    {
        throw 'Read-ConfigFile: 構成ファイルには cloudService プロパティは含まれません。'
    }

    # PSCustomObject の値からハッシュ テーブルを構築します
    $returnObject = New-Object -TypeName Hashtable

    $returnObject.Add('cloudService', $config.environmentSettings.cloudService)
    if ($HasWebDeployPackage)
    {
        $returnObject.Add('webDeployParameters', $config.environmentSettings.webdeployParameters)
    }

    if (Test-Member -Object $config.environmentSettings -Member 'databases')
    {
        $returnObject.Add('databases', $config.environmentSettings.databases)
    }

    Write-VerboseWithTime 'Read-ConfigFile: 終了'

    return $returnObject
}

<#
.SYNOPSIS
新しい入力エンドポイントを仮想マシンに追加し、新しいエンドポイントを持つ仮想マシンを返します。

.DESCRIPTION
Add-AzureVMEndpoints 関数は、新しい入力エンドポイントを仮想マシンに追加し、新しいエンドポイントを持つ仮想マシンを返します。この関数は Add-AzureEndpoint コマンドレット (Azure モジュール) を呼び出します。

.PARAMETER  VM
仮想マシン オブジェクトを指定します。New-AzureVM コマンドレットや Get-AzureVM コマンドレットが返す型など、VM オブジェクトを入力します。Get-AzureVM から Add-AzureVMEndpoints にオブジェクトをパイプできます。

.PARAMETER  Endpoints
VM に追加するエンドポイントの配列を指定します。通常、これらのエンドポイントは、Web プロジェクト用に Visual Studio によって生成される JSON 構成ファイルから取得します。このモジュールの Read-ConfigFile 関数を使用して、ファイルをハッシュ テーブルに変換します。エンド ポイントは、ハッシュ テーブルの cloudservice キーに含まれるプロパティです ($<hashtable>.cloudservice.virtualmachine.endpoints)。例
PS C:\> $config.cloudservice.virtualmachine.endpoints
name      protocol publicport privateport
----      -------- ---------- -----------
http      tcp      80         80
https     tcp      443        443
WebDeploy tcp      8172       8172

.INPUTS
Microsoft.WindowsAzure.Commands.ServiceManagement.Model.IPersistentVM

.OUTPUTS
Microsoft.WindowsAzure.Commands.ServiceManagement.Model.IPersistentVM

.EXAMPLE
Get-AzureVM

.EXAMPLE

.LINK
Get-AzureVM

.LINK
Add-AzureEndpoint
#>
function Add-AzureVMEndpoints
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVM]
        $VM,

        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]
        $Endpoints
    )

    Write-VerboseWithTime 'Add-AzureVMEndpoints: 開始'

    # JSON ファイルから各エンドポイントを VM に追加します
    $Endpoints | ForEach-Object `
    {
        $_ | Out-String | Write-VerboseWithTime
        Add-AzureEndpoint -VM $VM -Name $_.name -Protocol $_.protocol -LocalPort $_.privateport -PublicPort $_.publicport | Out-Null
    }

    Write-VerboseWithTime 'Add-AzureVMEndpoints: 終了'
    return $VM
}

<#
.SYNOPSIS
Windows Azure サブスクリプション内の新しい仮想マシンの全要素を作成します。

.DESCRIPTION
この関数は、Windows Azure 仮想マシン (VM) を作成し、配置された VM の URL を返します。関数は前提条件を設定してから、New-AzureVM コマンドレット (Azure モジュール) を呼び出して新しい VM を作成します。 
-- New-AzureVMConfig コマンドレット (Azure モジュール) を呼び出して、仮想マシン構成オブジェクトを取得します。 
-- VM を Azure サブネットに追加するために Subnet パラメーターを含める場合は、Set-AzureSubnet を呼び出して VM のサブネット リストを設定します。 
-- Add-AzureProvisioningConfig (Azure モジュール) を呼び出して、要素を VM 構成に追加します。管理者アカウントとパスワードを使用して、スタンドアロンの Windows プロビジョニング構成 (-Windows) を作成します。 
-- このモジュールの Add-AzureVMEndpoints 関数を呼び出して、Endpoints パラメーターで指定されたエンドポイントを追加します。この関数は VM オブジェクトを受け取り、追加されたエンドポイントがある VM オブジェクトを返します。 
-- Add-AzureVM コマンドレットを呼び出して、新しい Windows Azure 仮想マシンを作成し、新しい VM を返します。通常、関数パラメーターの値は、Windows Azure に統合された Web プロジェクト用に Visual Studio によって生成される JSON 構成ファイルから取得しています。このモジュールの Read-ConfigFile 関数は、JSON ファイルをハッシュ テーブルに変換します。ハッシュ テーブルの cloudservice キーを (PSCustomObject として) 変数に保存し、カスタム オブジェクトのプロパティをパラメーター値として使用します。

.PARAMETER  UserName
管理者のユーザー名を指定します。この値は、Add-AzureProvisioningConfig の AdminUserName パラメーターの値として送信されます。このパラメーターは必須です。

.PARAMETER  UserPassword
管理者ユーザー アカウントのパスワードを指定します。この値は、Add-AzureProvisioningConfig の Password パラメーターの値として送信されます。このパラメーターは必須です。

.PARAMETER  VMName
新しい VM の名前を指定します。VM 名は、クラウド サービス内で一意である必要があります。このパラメーターは必須です。

.PARAMETER  VMSize
VM のサイズを指定します。有効な値は、"ExtraSmall"、"Small"、"Medium"、"Large"、"ExtraLarge"、"A5"、"A6"、および "A7" です。この値は、New-AzureVMConfig の InstanceSize パラメーターの値として送信されます。このパラメーターは必須です。 

.PARAMETER  ServiceName
既存の Windows Azure サービス、または新しい Windows Azure サービスの名前を指定します。この値は、New-AzureVM コマンドレットの ServiceName パラメーターに送信されます。このコマンドレットは、新しい仮想マシンを既存の Windows Azure サービスに追加するか、Location または AffinityGroup が指定されている場合は現在のサブスクリプションに新しい仮想マシンとサービスを作成します。このパラメーターは必須です。 

.PARAMETER  ImageName
オペレーティング システム ディスクに使用する仮想マシン イメージの名前を指定します。このパラメーターは、New-AzureVMConfig コマンドレットの ImageName パラメーターの値として送信されます。このパラメーターは必須です。 

.PARAMETER  Endpoints
VM に追加するエンドポイントの配列を指定します。この値は、このモジュールがエクスポートする Add-AzureVMEndpoints 関数に送信されます。このパラメーターは省略可能です。通常、これらのエンドポイントは、Web プロジェクト用に Visual Studio によって生成される JSON 構成ファイルから取得します。このモジュールの Read-ConfigFile 関数を使用して、ファイルをハッシュ テーブルに変換します。エンド ポイントは、ハッシュ テーブルの cloudService キーに含まれるプロパティです ($<hashtable>.cloudservice.virtualmachine.endpoints)。 

.PARAMETER  AvailabilitySetName
新しい VM の可用性セットの名前を指定します。複数の仮想マシンを単一の可用性セットに配置すると、Windows Azure は、いずれかの仮想マシンで障害が発生した場合のサービス継続性を向上するために、各仮想マシンを異なるホスト上に配置しようとします。このパラメーターは省略可能です。 

.PARAMETER  VNetName
新しい仮想マシンを配置する仮想ネットワーク名の名前を指定します。この値は、Add-AzureVM コマンドレットの VNetName パラメーターに送信されます。このパラメーターは省略可能です。 

.PARAMETER  Location
新しい VM の場所を指定します。有効な値は、"West US" などの Windows Azure の場所です。既定値はサブスクリプションの場所です。このパラメーターは省略可能です。 

.PARAMETER  AffinityGroup
新しい VM のアフィニティ グループを指定します。アフィニティ グループは、関連するリソースのグループです。アフィニティ グループを指定すると、Windows Azure は、効率を向上するためにリソースをグループにまとめようとします。 

.PARAMETER EnableWebDeployExtension
配置する VM を準備します。このパラメーターは省略可能です。パラメーターを指定しない場合、VM は作成されますが配置されません。このパラメーターの値は、クラウド サービス用に Visual Studio によって生成される JSON 構成ファイルに含まれます。

.PARAMETER  Subnet
新しい VM 構成のサブネットを指定します。この値は、Set-AzureSubnet コマンドレット (Azure モジュール) に送信されます。このコマンドレットは VM とサブネット名配列を受け取り、構成にサブネットが設定された VM を返します。

.INPUTS
なし。この関数はパイプラインからの入力を受け取りません。

.OUTPUTS
System.Url

.EXAMPLE
 このコマンドは Add-AzureVM 関数を呼び出します。パラメーター値の多くは、$CloudServiceConfiguration オブジェクトから取得しています。この PSCustomObject は、Read-ConfigFile 関数が返すハッシュ テーブルの cloudservice キーと値です。取得元は、Web プロジェクト用に Visual Studio によって生成される JSON 構成ファイル内のデータです。

PS C:\> $config = Read-Configfile <name>.json
PS C:\> $CloudServiceConfiguration = config.cloudservice

PS C:\> Add-AzureVM `
-UserName $userName `
-UserPassword  $userPassword `
-ImageName $CloudServiceConfiguration.virtualmachine.vhdImage `
-VMName $CloudServiceConfiguration.virtualmachine.name `
-VMSize $CloudServiceConfiguration.virtualmachine.size`
-Endpoints $CloudServiceConfiguration.virtualmachine.endpoints `
-ServiceName $serviceName `
-Location $CloudServiceConfiguration.location `
-AvailabilitySetName $CloudServiceConfiguration.availabilitySet `
-VNetName $CloudServiceConfiguration.virtualNetwork `
-Subnet $CloudServiceConfiguration.subnet `
-AffinityGroup $CloudServiceConfiguration.affinityGroup `
-EnableWebDeployExtension

http://contoso.cloudapp.net

.EXAMPLE
PS C:\> $endpoints = [PSCustomObject]@{name="http";protocol="tcp";publicport=80;privateport=80}, `
                        [PSCustomObject]@{name="https";protocol="tcp";publicport=443;privateport=443},`
                        [PSCustomObject]@{name="WebDeploy";protocol="tcp";publicport=8172;privateport=8172}
PS C:\> Add-AzureVM `
-UserName admin01 `
-UserPassword "password" `
-ImageName bd507d3a70934695bc2128e3e5a255ba__RightImage-Windows-2012-x64-v13.4.12.2 `
-VMName DevTestVM123 `
-VMSize Small `
-Endpoints $endpoints `
-ServiceName DevTestVM1234 `
-Location "West US"

.LINK
New-AzureVMConfig

.LINK
Set-AzureSubnet

.LINK
Add-AzureProvisioningConfig

.LINK
Get-AzureDeployment
#>
function Add-AzureVM
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $UserName,

        [Parameter(Mandatory = $true)]
        [String]
        $UserPassword,

        [Parameter(Mandatory = $true)]
        [String]
        $VMName,

        [Parameter(Mandatory = $true)]
        [String]
        $VMSize,

        [Parameter(Mandatory = $true)]
        [String]
        $ServiceName,

        [Parameter(Mandatory = $true)]
        [String]
        $ImageName,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Object[]]
        $Endpoints,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [String]
        $AvailabilitySetName,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [String]
        $VNetName,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [String]
        $Location,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [String]
        $AffinityGroup,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [String]
        $Subnet,

        [Parameter(Mandatory = $false)]
        [Switch]
        $EnableWebDeployExtension
    )

    Write-VerboseWithTime 'Add-AzureVM: 開始'

    # 新しい Windows Azure VM 構成オブジェクトを作成します。
    if ($AvailabilitySetName)
    {
        $vm = New-AzureVMConfig -Name $VMName -InstanceSize $VMSize -ImageName $ImageName -AvailabilitySetName $AvailabilitySetName
    }
    else
    {
        $vm = New-AzureVMConfig -Name $VMName -InstanceSize $VMSize -ImageName $ImageName
    }

    if (!$vm)
    {
        throw 'Add-AzureVM: Azure VM 構成を作成できませんでした。'
    }

    if ($Subnet)
    {
        # 仮想マシン構成のサブネット リストを設定します。
        $subnetResult = Set-AzureSubnet -VM $vm -SubnetNames $Subnet

        if (!$subnetResult)
        {
            throw ('Add-AzureVM: サブネットを設定できませんでした ' + $Subnet)
        }
    }

    # 構成データを VM 構成に追加します
    $VMWithConfig = Add-AzureProvisioningConfig -VM $vm -Windows -Password $UserPassword -AdminUserName $UserName

    if (!$VMWithConfig)
    {
        throw ('Add-AzureVM: プロビジョニング構成を作成できませんでした。')
    }

    # 入力エンドポイントを VM に追加します
    if ($Endpoints -and $Endpoints.Count -gt 0)
    {
        $VMWithConfig = Add-AzureVMEndpoints -Endpoints $Endpoints -VM $VMWithConfig
    }

    if (!$VMWithConfig)
    {
        throw ('Add-AzureVM: エンドポイントを作成できませんでした。')
    }

    if ($EnableWebDeployExtension)
    {
        Write-VerboseWithTime 'Add-AzureVM: Web 配置拡張機能を追加します'

        Write-VerboseWithTime 'WebDeploy のライセンスについては、http://go.microsoft.com/fwlink/?LinkID=389744 を参照してください '

        $VMWithConfig = Set-AzureVMExtension `
            -VM $VMWithConfig `
            -ExtensionName WebDeployForVSDevTest `
            -Publisher 'Microsoft.VisualStudio.WindowsAzure.DevTest' `
            -Version '1.*' 

        if (!$VMWithConfig)
        {
            throw ('Add-AzureVM: Web 配置拡張機能を追加できませんでした。')
        }
    }

    # スプラッティング用にパラメーターのハッシュ テーブルを作成します
    $param = New-Object -TypeName Hashtable
    if ($VNetName)
    {
        $param.Add('VNetName', $VNetName)
    }

    if ($Location)
    {
        $param.Add('Location', $Location)
    }

    if ($AffinityGroup)
    {
        $param.Add('AffinityGroup', $AffinityGroup)
    }

    $param.Add('ServiceName', $ServiceName)
    $param.Add('VMs', $VMWithConfig)
    $param.Add('WaitForBoot', $true)

    $param | Out-String | Write-VerboseWithTime

    New-AzureVM @param | Out-Null

    Write-HostWithTime ('Add-AzureVM: 仮想マシンを作成しました: ' + $VMName)

    $url = [System.Uri](Get-AzureDeployment -ServiceName $ServiceName).Url

    if (!$url)
    {
        throw 'Add-AzureVM: VM URL が見つかりません。'
    }

    Write-HostWithTime ('Add-AzureVM: URL を公開します: https://' + $url.Host + ':' + $WebDeployPort + '/msdeploy.axd')

    Write-VerboseWithTime 'Add-AzureVM: 終了'

    return $url.AbsoluteUri
}


<#
.SYNOPSIS
指定された Windows Azure 仮想マシンを取得します。

.DESCRIPTION
Find-AzureVM 関数は、Windows Azure 仮想マシン (VM) をサービス名と VM 名に基づいて取得します。この関数は Test-AzureName コマンドレット (Azure モジュール) を呼び出して、サービス名が Windows Azure に存在することを検証します。存在する場合は、Get-AzureVM コマンドレットを呼び出して VM を取得します。この関数は、vm キーと foundService キーを含むハッシュ テーブルを返します。
-- FoundService: Test-AzureName でサービス名が見つかった場合は $True。それ以外の場合は $False
-- VM: FoundService が true で Get-AzureVM が VM オブジェクトを返す場合、VM オブジェクトが含まれます。

.PARAMETER  ServiceName
既存の Windows Azure サービスの名前。このパラメーターは必須です。

.PARAMETER  VMName
サービスの仮想マシンの名前。このパラメーターは必須です。

.INPUTS
なし。この関数には入力をパイプできません。

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
PS C:\> Find-AzureVM -Service Contoso -Name ContosoVM2

Name                           Value
----                           -----
foundService                   True

DeploymentName        : Contoso
Name                  : ContosoVM2
Label                 :
VM                    : Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVM
InstanceStatus        : ReadyRole
IpAddress             : 100.71.114.118
InstanceStateDetails  :
PowerState            : Started
InstanceErrorCode     :
InstanceFaultDomain   : 0
InstanceName          : ContosoVM2
InstanceUpgradeDomain : 0
InstanceSize          : Small
AvailabilitySetName   :
DNSName               : http://contoso.cloudapp.net/
ServiceName           : Contoso
OperationDescription  : Get-AzureVM
OperationId           : 3c38e933-9464-6876-aaaa-734990a882d6
OperationStatus       : Succeeded

.LINK
Get-AzureVM
#>
function Find-AzureVM
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $ServiceName,

        [Parameter(Mandatory = $true)]
        [String]
        $VMName
    )

    Write-VerboseWithTime 'Find-AzureVM: 開始'
    $foundService = $false
    $vm = $null

    if (Test-AzureName -Service -Name $ServiceName)
    {
        $foundService = $true
        $vm = Get-AzureVM -ServiceName $ServiceName -Name $VMName
        if ($vm)
        {
            Write-HostWithTime ('Find-AzureVM: 既存の仮想マシンが見つかりました: ' + $vm.Name )
            $vm | Out-String | Write-VerboseWithTime
        }
    }

    Write-VerboseWithTime 'Find-AzureVM: 終了'
    return @{ VM = $vm; FoundService = $foundService }
}


<#
.SYNOPSIS
JSON 構成ファイル内の値と一致する、サブスクリプション内の仮想マシンを検出または作成します。

.DESCRIPTION
New-AzureVMEnvironment 関数は、Web プロジェクト用に Visual Studio によって生成される JSON 構成ファイル内の値と一致する、サブスクリプション内の仮想マシンを検出または作成します。関数は、Read-ConfigFile が返すハッシュ テーブルの cloudservice キーである、PSCustomObject を受け取ります。このデータは、Visual Studio によって生成される JSON 構成ファイルから取得します。関数は、CloudServiceConfiguration カスタム オブジェクト内の値とサービス名と仮想マシン名が一致する、サブスクリプション内の仮想マシン (VM) を検索します。一致する VM が見つからない場合は、このモジュールの Add-AzureVM 関数を呼び出し、CloudServiceConfiguration オブジェクトの値を使用して VM を作成します。仮想マシン環境には、名前が "devtest" で始まるストレージ アカウントが含まれています。この名前パターンのストレージ アカウントがサブスクリプションに見つからない場合、関数はストレージ アカウントを作成します。関数は、VMUrl キー、userName キー、および Password キーと文字列値を含むハッシュ テーブルを返します。

.PARAMETER  CloudServiceConfiguration
Read-ConfigFile 関数が返すハッシュ テーブルの cloudservice プロパティを含む、PSCustomObject を受け取ります。すべての値は、Web プロジェクト用に Visual Studio によって生成される JSON 構成ファイルから取得します。このファイルは、ソリューションの PublishScripts フォルダーにあります。このパラメーターは必須です。
$config = Read-ConfigFile -ConfigurationFile <file>.json $cloudServiceConfiguration = $config.cloudService

.PARAMETER  VMPassword
名前キーとパスワード キーを含むハッシュ テーブルを取得します。例: @{Name = "admin"; Password = "password"} このパラメーターはオプションです。このパラメーターを省略する場合、既定値は JSON 構成ファイルの仮想マシン ユーザー名とパスワードです。

.INPUTS
PSCustomObject  System.Collections.Hashtable

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
$config = Read-ConfigFile -ConfigurationFile $<file>.json
$cloudSvcConfig = $config.cloudService
$namehash = @{name = "admin"; password = "password"}

New-AzureVMEnvironment `
    -CloudServiceConfiguration $cloudSvcConfig `
    -VMPassword $namehash

Name                           Value
----                           -----
UserName                       admin
VMUrl                          contoso.cloudnet.net
Password                       password

.LINK
Add-AzureVM

.LINK
New-AzureStorageAccount
#>
function New-AzureVMEnvironment
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [Object]
        $CloudServiceConfiguration,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Hashtable]
        $VMPassword
    )

    Write-VerboseWithTime ('New-AzureVMEnvironment: 開始')

    if ($CloudServiceConfiguration.location -and $CloudServiceConfiguration.affinityGroup)
    {
        throw 'New-AzureVMEnvironment: 構成ファイルの形式が正しくありません。location と affinityGroup の両方が含まれています'
    }

    if (!$CloudServiceConfiguration.location -and !$CloudServiceConfiguration.affinityGroup)
    {
        throw 'New-AzureVMEnvironment: 構成ファイルの形式が正しくありません。location または affinityGroup が含まれていません'
    }

    # CloudServiceConfiguration オブジェクトに (サービス名を表す) 'name' プロパティがあり、'name' プロパティに値が設定されている場合は、その値を使用します。それ以外の場合は、CloudServiceConfiguration オブジェクトに必ず設定されている仮想マシン名を使用します。
    if ((Test-Member $CloudServiceConfiguration 'name') -and $CloudServiceConfiguration.name)
    {
        $serviceName = $CloudServiceConfiguration.name
    }
    else
    {
        $serviceName = $CloudServiceConfiguration.virtualMachine.name
    }

    if (!$VMPassword)
    {
        $userName = $CloudServiceConfiguration.virtualMachine.user
        $userPassword = $CloudServiceConfiguration.virtualMachine.password
    }
    else
    {
        $userName = $VMPassword.Name
        $userPassword = $VMPassword.Password
    }

    # JSON ファイルから VM を取得します
    $findAzureVMResult = Find-AzureVM -ServiceName $serviceName -VMName $CloudServiceConfiguration.virtualMachine.name

    # 指定のクラウド サービスに指定の名前の VM が見つからない場合は、作成します。
    if (!$findAzureVMResult.VM)
    {
        $storageAccountName = $null
        $imageInfo = Get-AzureVMImage -ImageName $CloudServiceConfiguration.virtualmachine.vhdimage 
        if ($imageInfo -and $imageInfo.Category -eq 'User')
        {
            $storageAccountName = ($imageInfo.MediaLink.Host -split '\.')[0]
        }

        if (!$storageAccountName)
        {
            if ($CloudServiceConfiguration.location)
            {
                $storageAccountName = Get-AzureVMStorage -Location $CloudServiceConfiguration.location
            }
            else
            {
                $storageAccountName = Get-AzureVMStorage -AffinityGroup $CloudServiceConfiguration.affinityGroup
            }
        }

         # devtest* ストレージ アカウントがない場合は、作成してください。
        if (!$storageAccountName)
        {
            if ($CloudServiceConfiguration.location)
            {
                $storageAccountName = Add-AzureVMStorage -Location $CloudServiceConfiguration.location
            }
            else
            {
                $storageAccountName = Add-AzureVMStorage -AffinityGroup $CloudServiceConfiguration.affinityGroup
            }
        }

        $currentSubscription = Get-AzureSubscription -Current

        if (!$currentSubscription)
        {
            throw 'New-AzureVMEnvironment: 現在の Azure サブスクリプションを取得できませんでした。'
        }

        # devtest* ストレージ アカウントを現在のアカウントに設定します
        Set-AzureSubscription `
            -SubscriptionName $currentSubscription.SubscriptionName `
            -CurrentStorageAccountName $storageAccountName

        Write-VerboseWithTime ('New-AzureVMEnvironment: ストレージ アカウントを次に設定しました: ' + $storageAccountName)

        $location = ''            
        if (!$findAzureVMResult.FoundService)
        {
            $location = $CloudServiceConfiguration.location
        }

        $endpoints = $null
        if (Test-Member -Object $CloudServiceConfiguration.virtualmachine -Member 'Endpoints')
        {
            $endpoints = $CloudServiceConfiguration.virtualmachine.endpoints
        }

        # JSON ファイルの値とパラメーター値を使用して VM を作成します
        $VMUrl = Add-AzureVM `
            -UserName $userName `
            -UserPassword $userPassword `
            -ImageName $CloudServiceConfiguration.virtualMachine.vhdImage `
            -VMName $CloudServiceConfiguration.virtualMachine.name `
            -VMSize $CloudServiceConfiguration.virtualMachine.size`
            -Endpoints $endpoints `
            -ServiceName $serviceName `
            -Location $location `
            -AvailabilitySetName $CloudServiceConfiguration.availabilitySet `
            -VNetName $CloudServiceConfiguration.virtualNetwork `
            -Subnet $CloudServiceConfiguration.subnet `
            -AffinityGroup $CloudServiceConfiguration.affinityGroup `
            -EnableWebDeployExtension:$CloudServiceConfiguration.virtualMachine.enableWebDeployExtension

        Write-VerboseWithTime ('New-AzureVMEnvironment: 終了')

        return @{ 
            VMUrl = $VMUrl; 
            UserName = $userName; 
            Password = $userPassword; 
            IsNewCreatedVM = $true; }
    }
    else
    {
        Write-VerboseWithTime ('New-AzureVMEnvironment: 既存の仮想マシンが見つかりました: ' + $findAzureVMResult.VM.Name)
    }

    Write-VerboseWithTime ('New-AzureVMEnvironment: 終了')

    return @{ 
        VMUrl = $findAzureVMResult.VM.DNSName; 
        UserName = $userName; 
        Password = $userPassword; 
        IsNewCreatedVM = $false; }
}


<#
.SYNOPSIS
MsDeploy.exe ツールを実行するためのコマンドを返します

.DESCRIPTION
Get-MSDeployCmd 関数は、Web 配置ツール MSDeploy.exe を実行するための有効なコマンドを構築して返します。レジストリ キーのローカル コンピューター上にある、ツールへの正しいパスを見つけます。この関数にパラメーターはありません。

.INPUTS
なし

.OUTPUTS
System.String

.EXAMPLE
PS C:\> Get-MSDeployCmd
C:\Program Files\IIS\Microsoft Web Deploy V3\MsDeploy.exe

.LINK
Get-MSDeployCmd

.LINK
Web Deploy Tool
http://technet.microsoft.com/en-us/library/dd568996(v=ws.10).aspx
#>
function Get-MSDeployCmd
{
    Write-VerboseWithTime 'Get-MSDeployCmd: 開始'
    $regKey = 'HKLM:\SOFTWARE\Microsoft\IIS Extensions\MSDeploy'

    if (!(Test-Path $regKey))
    {
        throw ('Get-MSDeployCmd: 見つかりません: ' + $regKey)
    }

    $versions = @(Get-ChildItem $regKey -ErrorAction SilentlyContinue)
    $lastestVersion =  $versions | Sort-Object -Property Name -Descending | Select-Object -First 1

    if ($lastestVersion)
    {
        $installPathKeys = 'InstallPath','InstallPath_x86'

        foreach ($installPathKey in $installPathKeys)
        {		    	
            $installPath = $lastestVersion.GetValue($installPathKey)

            if ($installPath)
            {
                $installPath = Join-Path $installPath -ChildPath 'MsDeploy.exe'

                if (Test-Path $installPath -PathType Leaf)
                {
                    $msdeployPath = $installPath
                    break
                }
            }
        }
    }

    Write-VerboseWithTime 'Get-MSDeployCmd: 終了'
    return $msdeployPath
}


<#
.SYNOPSIS
URL が絶対で、その方式が https の場合は、$True を返します。

.DESCRIPTION
Test-HttpsUrl 関数は、入力 URL を System.Uri オブジェクトに変換します。URL が (相対ではなく) 絶対で、その方式が https の場合は、$True を返します。いずれかの条件が false の場合、または入力文字列を URL に変換できない場合、関数は $false を返します。

.PARAMETER Url
テストする URL を指定します。URL 文字列を入力します

.INPUTS
なし。

.OUTPUTS
System.Boolean

.EXAMPLE
PS C:\>$profile.publishUrl
waws-prod-bay-001.publish.azurewebsites.windows.net:443

PS C:\>Test-HttpsUrl -Url 'waws-prod-bay-001.publish.azurewebsites.windows.net:443'
False

PS C:\>Test-HttpsUrl -Url 'https://waws-prod-bay-001.publish.azurewebsites.windows.net:443'
True
#>
function Test-HttpsUrl
{

    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Url
    )

    # $uri を System.Uri オブジェクトに変換できない場合、Test-HttpsUrl は $false を返します
    $uri = $Url -as [System.Uri]

    return $uri.IsAbsoluteUri -and $uri.Scheme -eq 'https'
}


<#
.SYNOPSIS
Web パッケージを Windows Azure に配置します。

.DESCRIPTION
Publish-WebPackage 関数は、MsDeploy.exe と Web 配置パッケージ ZIP ファイルを使用して、リソースを Windows Azure Web サイトに配置します。この関数は出力を生成しません。MSDeploy.exe の呼び出しが失敗した場合、関数は例外をスローします。詳細な出力を取得するには、Verbose 共通パラメーターを使用します。

.PARAMETER  WebDeployPackage
Visual Studio によって生成される Web 配置パッケージ ZIP ファイルのパスとファイル名を指定します。このパラメーターは必須です。Web 配置パッケージ ZIP ファイルを作成するには、「How to: Create a Web Deployment Package in Visual Studio (方法: Visual Studio で Web 配置パッケージを作成する)」(http://go.microsoft.com/fwlink/?LinkId=391353) を参照してください。

.PARAMETER PublishUrl
リソースの配置先 URL を指定します。URL には HTTPS プロトコルが使用され、ポートが含まれている必要があります。このパラメーターは必須です。

.PARAMETER SiteName
Web サイトの名前を指定します。このパラメーターは必須です。

.PARAMETER Username
Web サイト管理者のユーザー名を指定します。このパラメーターは必須です。

.PARAMETER Password
Web サイト管理者のパスワードを指定します。パスワードはプレーンテキスト形式で入力します。セキュリティで保護された文字列は使用できません。このパラメーターは必須です。

.PARAMETER AllowUntrusted
Web 配置エンドポイントへの信頼されていない SSL 接続を許可します。このパラメーターは MSDeploy.exe の呼び出しで使用します。このパラメーターはオプションです。

.PARAMETER ConnectionString
SQL データベースの接続文字列を指定します。このパラメーターは、Name キーと ConnectionString キーを含むハッシュ テーブルを受け取ります。Name の値は、データベースの名前です。ConnectionString の値は、JSON 構成ファイルの接続文字列名です。

.INPUTS
なし。この関数はパイプラインからの入力を受け取りません。

.OUTPUTS
なし

.EXAMPLE
Publish-WebPackage -WebDeployPackage C:\Documents\Azure\ADWebApp.zip `
    -PublishUrl 'https://contoso.cloudapp.net:8172/msdeploy.axd' `
    -SiteName 'Contoso テスト サイト' `
    -UserName 'admin01' `
    -Password 'password' `
    -AllowUntrusted:$False `
    -ConnectionString @{Name="TestDB";ConnectionString="DefaultConnection"}

.LINK
Publish-WebPackageToVM

.LINK
Web Deploy Command Line Reference (MSDeploy.exe)
http://go.microsoft.com/fwlink/?LinkId=391354
#>
function Publish-WebPackage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]
        $WebDeployPackage,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-HttpsUrl $_ })]
        [String]
        $PublishUrl,

        [Parameter(Mandatory = $true)]
        [String]
        $SiteName,

        [Parameter(Mandatory = $true)]
        [String]
        $UserName,

        [Parameter(Mandatory = $true)]
        [String]
        $Password,

        [Parameter(Mandatory = $false)]
        [Switch]
        $AllowUntrusted = $false,

        [Parameter(Mandatory = $true)]
        [Hashtable]
        $ConnectionString
    )

    Write-VerboseWithTime 'Publish-WebPackage: 開始'

    $msdeployCmd = Get-MSDeployCmd

    if (!$msdeployCmd)
    {
        throw 'Publish-WebPackage: MsDeploy.exe が見つかりません。'
    }

    $WebDeployPackage = (Get-Item $WebDeployPackage).FullName

    $msdeployCmd =  '"' + $msdeployCmd + '"'
    $msdeployCmd += ' -verb:sync'
    $msdeployCmd += ' -Source:Package="{0}"'
    $msdeployCmd += ' -dest:auto,computername="{1}?site={2}",userName={3},password={4},authType=Basic'
    if ($AllowUntrusted)
    {
        $msdeployCmd += ' -allowUntrusted'
    }
    $msdeployCmd += ' -setParam:name="IIS Web Application Name",value="{2}"'

    foreach ($DBConnection in $ConnectionString.GetEnumerator())
    {
        $msdeployCmd += (' -setParam:name="{0}",value="{1}"' -f $DBConnection.Key, $DBConnection.Value)
    }

    $msdeployCmd = $msdeployCmd -f $WebDeployPackage, $PublishUrl, $SiteName, $UserName, $Password
    $msdeployCmdForVerboseMessage = $msdeployCmd -f $WebDeployPackage, $PublishUrl, $SiteName, $UserName, '********'

    Write-VerboseWithTime ('Publish-WebPackage: MsDeploy: ' + $msdeployCmdForVerboseMessage)

    $msdeployExecution = Start-Process cmd.exe -ArgumentList ('/C "' + $msdeployCmd + '" ') -WindowStyle Normal -Wait -PassThru

    if ($msdeployExecution.ExitCode -ne 0)
    {
         Write-VerboseWithTime ('Msdeploy.exe がエラーで終了しました。ExitCode:' + $msdeployExecution.ExitCode)
    }

    Write-VerboseWithTime 'Publish-WebPackage: 終了'
    return ($msdeployExecution.ExitCode -eq 0)
}


<#
.SYNOPSIS
仮想マシンを Windows Azure に配置します。

.DESCRIPTION
Publish-WebPackageToVM 関数は、ヘルパー関数です。パラメーター値を検証してから、Publish-WebPackage 関数を呼び出します。

.PARAMETER  VMDnsName
Windows Azure 仮想マシンの DNS 名を指定します。このパラメーターは必須です。

.PARAMETER IisWebApplicationName
仮想マシンの IIS Web アプリケーション名を指定します。このパラメーターは必須です。これは、Visual Studio Web アプリケーションの名前です。この名前は、Visual Studio によって生成される JSON 構成ファイルの webDeployparameters 属性で確認できます。

.PARAMETER WebDeployPackage
Visual Studio によって生成される Web 配置パッケージ ZIP ファイルのパスとファイル名を指定します。このパラメーターは必須です。Web 配置パッケージ ZIP ファイルを作成するには、「How to: Create a Web Deployment Package in Visual Studio (方法: Visual Studio で Web 配置パッケージを作成する)」(http://go.microsoft.com/fwlink/?LinkId=391353) を参照してください。

.PARAMETER Username
仮想マシン管理者のユーザー名を指定します。このパラメーターは必須です。

.PARAMETER Password
仮想マシン管理者のパスワードを指定します。パスワードはプレーンテキスト形式で入力します。セキュリティで保護された文字列は使用できません。このパラメーターは必須です。

.PARAMETER AllowUntrusted
Web 配置エンドポイントへの信頼されていない SSL 接続を許可します。このパラメーターは MSDeploy.exe の呼び出しで使用します。このパラメーターはオプションです。

.PARAMETER ConnectionString
SQL データベースの接続文字列を指定します。このパラメーターは、Name キーと ConnectionString キーを含むハッシュ テーブルを受け取ります。Name の値は、データベースの名前です。ConnectionString の値は、JSON 構成ファイルの接続文字列名です。

.INPUTS
なし。この関数はパイプラインからの入力を受け取りません。

.OUTPUTS
なし。

.EXAMPLE
Publish-WebPackageToVM -VMDnsName contoso.cloudapp.net `
-IisWebApplicationName myTestWebApp `
-WebDeployPackage C:\Documents\Azure\ADWebApp.zip
-Username 'admin01' `
-Password 'password' `
-AllowUntrusted:$False `
-ConnectionString @{Name="TestDB";ConnectionString="DefaultConnection"}

.LINK
Publish-WebPackage
#>
function Publish-WebPackageToVM
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $VMDnsName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $IisWebApplicationName,

        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [String]
        $WebDeployPackage,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $UserName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $UserPassword,

        [Parameter(Mandatory = $true)]
        [Bool]
        $AllowUntrusted,
        
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $ConnectionString
    )
    Write-VerboseWithTime 'Publish-WebPackageToVM: 開始'

    $VMDnsUrl = $VMDnsName -as [System.Uri]

    if (!$VMDnsUrl)
    {
        throw ('Publish-WebPackageToVM: 無効な URL: ' + $VMDnsUrl)
    }

    $publishUrl = 'https://{0}:{1}/msdeploy.axd' -f $VMDnsUrl.Host, $WebDeployPort

    $result = Publish-WebPackage `
        -WebDeployPackage $WebDeployPackage `
        -PublishUrl $publishUrl `
        -SiteName $IisWebApplicationName `
        -UserName $UserName `
        -Password $UserPassword `
        -AllowUntrusted:$AllowUntrusted `
        -ConnectionString $ConnectionString

    Write-VerboseWithTime 'Publish-WebPackageToVM: 終了'
    return $result
}


<#
.SYNOPSIS
Windows Azure SQL データベースに接続できる文字列を作成します。

.DESCRIPTION
Get-AzureSQLDatabaseConnectionString 関数は、Windows Azure SQL データベースに接続するための接続文字列を構築します。

.PARAMETER  DatabaseServerName
Windows Azure サブスクリプションの既存のデータベース サーバーの名前を指定します。すべての Windows Azure SQL データベースは、SQL データベース サーバーに関連付けられている必要があります。サーバー名を取得するには、Get-AzureSqlDatabaseServer コマンドレット (Azure モジュール) を使用します。このパラメーターは必須です。

.PARAMETER  DatabaseName
SQL データベースの名前を指定します。既存の SQL データベースを指定することも、新しい SQL データベースに使用する名前を指定することもできます。このパラメーターは必須です。

.PARAMETER  Username
SQL データベース管理者の名前を指定します。ユーザー名は $Username@DatabaseServerName になります。このパラメーターは必須です。

.PARAMETER  Password
SQL データベース管理者のパスワードを指定します。パスワードはプレーンテキスト形式で入力します。セキュリティで保護された文字列は使用できません。このパラメーターは必須です。

.INPUTS
なし。

.OUTPUTS
System.String

.EXAMPLE
PS C:\> $ServerName = (Get-AzureSqlDatabaseServer).ServerName[0]
PS C:\> Get-AzureSQLDatabaseConnectionString -DatabaseServerName $ServerName `
        -DatabaseName 'testdb' -UserName 'admin'  -Password 'password'

Server=tcp:testserver.database.windows.net,1433;Database=testdb;User ID=admin@bebad12345;Password=password;Trusted_Connection=False;Encrypt=True;Connection Timeout=20;
#>
function Get-AzureSQLDatabaseConnectionString
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $DatabaseServerName,

        [Parameter(Mandatory = $true)]
        [String]
        $DatabaseName,

        [Parameter(Mandatory = $true)]
        [String]
        $UserName,

        [Parameter(Mandatory = $true)]
        [String]
        $Password
    )

    return ('Server=tcp:{0}.database.windows.net,1433;Database={1};' +
           'User ID={2}@{0};' +
           'Password={3};' +
           'Trusted_Connection=False;' +
           'Encrypt=True;' +
           'Connection Timeout=20;') `
           -f $DatabaseServerName, $DatabaseName, $UserName, $Password
}


<#
.SYNOPSIS
Visual Studio によって生成される JSON 構成ファイルの値から、Windows Azure SQL データベースを作成します。

.DESCRIPTION
Add-AzureSQLDatabases 関数は、JSON ファイルのデータベース セクションから情報を取得します。この Add-AzureSQLDatabases 関数 (複数形) は、JSON ファイル内で SQL データベースごとに Add-AzureSQLDatabase (単数形) 関数を呼び出します。Add-AzureSQLDatabase (単数形) は New-AzureSqlDatabase コマンドレット (Azure モジュール) を呼び出し、このコマンドレットが SQL データベースを作成します。この関数はデータベース オブジェクトを返しません。データベースの作成に使用した値のハッシュ テーブルを返します。

.PARAMETER DatabaseConfig
 JSON ファイルに Web サイト プロパティが含まれている場合に Read-ConfigFile 関数が返す、JSON ファイルから取得した PSCustomObjects の配列を受け取ります。これには environmentSettings.databases プロパティが含まれます。この関数にはリストをパイプできます。
PS C:\> $config = Read-ConfigFile <name>.json
PS C:\> $DatabaseConfig = $config.databases| where {$_.connectionStringName}
PS C:\> $DatabaseConfig
connectionStringName: Default Connection
databasename : TestDB1
edition   :
size     : 1
collation  : SQL_Latin1_General_CP1_CI_AS
servertype  : New SQL Database Server
servername  : r040tvt2gx
user     : dbuser
password   : Test.123
location   : West US

.PARAMETER  DatabaseServerPassword
SQL データベース サーバー管理者のパスワードを指定します。Name キーと Password キーを含むハッシュテーブルを入力してください。Name の値は、SQL データベース サーバーの名前です。Password の値は、管理者パスワードです。例: @Name = "TestDB1"; Password = "password" このパラメーターはオプションです。このパラメーターを省略するか、SQL データベース サーバー名が $DatabaseConfig オブジェクトの serverName プロパティの値に一致しない場合、関数では接続文字列の SQL データベースに対して $DatabaseConfig オブジェクトの Password プロパティを使用します。

.PARAMETER CreateDatabase
データベースを作成するかどうかを検証します。このパラメーターは省略可能です。

.INPUTS
System.Collections.Hashtable[]

.OUTPUTS
System.Collections.Hashtable

.EXAMPLE
PS C:\> $config = Read-ConfigFile <name>.json
PS C:\> $DatabaseConfig = $config.databases| where {$_.connectionStringName}
PS C:\> $DatabaseConfig | Add-AzureSQLDatabases

Name                           Value
----                           -----
ConnectionString               Server=tcp:testdb1.database.windows.net,1433;Database=testdb;User ID=admin@testdb1;Password=password;Trusted_Connection=False;Encrypt=True;Connection Timeout=20;
Name                           Default Connection
Type                           SQLAzure

.LINK
Get-AzureSQLDatabaseConnectionString

.LINK
Create-AzureSQLDatabase
#>
function Add-AzureSQLDatabases
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]
        $DatabaseConfig,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Hashtable[]]
        $DatabaseServerPassword,

        [Parameter(Mandatory = $false)]
        [Switch]
        $CreateDatabase = $false
    )

    begin
    {
        Write-VerboseWithTime 'Add-AzureSQLDatabases: 開始'
    }
    process
    {
        Write-VerboseWithTime ('Add-AzureSQLDatabases: 作成しています: ' + $DatabaseConfig.databaseName)

        if ($CreateDatabase)
        {
            # DatabaseConfig 値で新しい SQL データベースを作成します (まだデータベースが存在しない場合)
            # コマンド出力は表示されません。
            Add-AzureSQLDatabase -DatabaseConfig $DatabaseConfig | Out-Null
        }

        $serverPassword = $null
        if ($DatabaseServerPassword)
        {
            foreach ($credential in $DatabaseServerPassword)
            {
               if ($credential.Name -eq $DatabaseConfig.serverName)
               {
                   $serverPassword = $credential.password             
                   break
               }
            }               
        }

        if (!$serverPassword)
        {
            $serverPassword = $DatabaseConfig.password
        }

        return @{
            Name = $DatabaseConfig.connectionStringName;
            Type = 'SQLAzure';
            ConnectionString = Get-AzureSQLDatabaseConnectionString `
                -DatabaseServerName $DatabaseConfig.serverName `
                -DatabaseName $DatabaseConfig.databaseName `
                -UserName $DatabaseConfig.user `
                -Password $serverPassword }
    }
    end
    {
        Write-VerboseWithTime 'Add-AzureSQLDatabases: 終了'
    }
}


<#
.SYNOPSIS
新しい Windows Azure SQL データベースを作成します。

.DESCRIPTION
Add-AzureSQLDatabase 関数は、Visual Studio によって生成される JSON 構成ファイル内のデータから Windows Azure SQL データベースを作成し、新しいデータベースを返します。指定されたデータベース名の SQL データベースを既にサブスクリプションが指定された SQL データベース サーバー内に持っている場合、関数は既存のデータベースを返します。この関数は New-AzureSqlDatabase コマンドレット (Azure モジュール) を呼び出し、このコマンドレットが実際に SQL データベースを作成します。

.PARAMETER DatabaseConfig
JSON ファイルに Web サイト プロパティが含まれている場合に Read-ConfigFile 関数が返す、JSON 構成ファイルから取得した PSCustomObject を受け取ります。これには environmentSettings.databases プロパティが含まれます。この関数にはオブジェクトをパイプできません。Visual Studio によって、すべての Web プロジェクト用に JSON 構成ファイルが生成され、ソリューションの PublishScripts フォルダーに格納されます。

.INPUTS
なし。この関数はパイプラインからの入力を受け取りません

.OUTPUTS
Microsoft.WindowsAzure.Commands.SqlDatabase.Services.Server.Database

.EXAMPLE
PS C:\> $config = Read-ConfigFile <name>.json
PS C:\> $DatabaseConfig = $config.databases | where connectionStringName
PS C:\> $DatabaseConfig

connectionStringName    : Default Connection
databasename : TestDB1
edition      :
size         : 1
collation    : SQL_Latin1_General_CP1_CI_AS
servertype   : New SQL Database Server
servername   : r040tvt2gx
user         : dbuser
password     : Test.123
location     : West US

PS C:\> Add-AzureSQLDatabase -DatabaseConfig $DatabaseConfig

.LINK
Add-AzureSQLDatabases

.LINK
New-AzureSQLDatabase
#>
function Add-AzureSQLDatabase
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [Object]
        $DatabaseConfig
    )

    Write-VerboseWithTime 'Add-AzureSQLDatabase: 開始'

    # パラメーター値にサーバー名プロパティが含まれていない場合、またはサーバー名プロパティの値が設定されていない場合は、失敗します。
    if (-not (Test-Member $DatabaseConfig 'serverName') -or -not $DatabaseConfig.serverName)
    {
        throw 'Add-AzureSQLDatabase: データベース サーバー名 (必須) が DatabaseConfig 値にありません。'
    }

    # パラメーター値にデータベース名プロパティが含まれていない場合、またはデータベース名プロパティの値が設定されていない場合は、失敗します。
    if (-not (Test-Member $DatabaseConfig 'databaseName') -or -not $DatabaseConfig.databaseName)
    {
        throw 'Add-AzureSQLDatabase: データベース名 (必須) が DatabaseConfig 値にありません。'
    }

    $DbServer = $null

    if (Test-HttpsUrl $DatabaseConfig.serverName)
    {
        $absoluteDbServer = $DatabaseConfig.serverName -as [System.Uri]
        $subscription = Get-AzureSubscription -Current -ErrorAction SilentlyContinue

        if ($subscription -and $subscription.ServiceEndpoint -and $subscription.SubscriptionId)
        {
            $absoluteDbServerRegex = 'https:\/\/{0}\/{1}\/services\/sqlservers\/servers\/(.+)\.database\.windows\.net\/databases' -f `
                                     $subscription.serviceEndpoint.Host, $subscription.SubscriptionId

            if ($absoluteDbServer -match $absoluteDbServerRegex -and $Matches.Count -eq 2)
            {
                 $DbServer = $Matches[1]
            }
        }
    }

    if (!$DbServer)
    {
        $DbServer = $DatabaseConfig.serverName
    }

    $db = Get-AzureSqlDatabase -ServerName $DbServer -DatabaseName $DatabaseConfig.databaseName -ErrorAction SilentlyContinue

    if ($db)
    {
        Write-HostWithTime ('Create-AzureSQLDatabase: 既存のデータベースを使用しています: ' + $db.Name)
        $db | Out-String | Write-VerboseWithTime
    }
    else
    {
        $param = New-Object -TypeName Hashtable
        $param.Add('serverName', $DbServer)
        $param.Add('databaseName', $DatabaseConfig.databaseName)

        if ((Test-Member $DatabaseConfig 'size') -and $DatabaseConfig.size)
        {
            $param.Add('MaxSizeGB', $DatabaseConfig.size)
        }
        else
        {
            $param.Add('MaxSizeGB', 1)
        }

        # $DatabaseConfig オブジェクトに照合順序プロパティがあり、プロパティ値が null または空ではない場合
        if ((Test-Member $DatabaseConfig 'collation') -and $DatabaseConfig.collation)
        {
            $param.Add('Collation', $DatabaseConfig.collation)
        }

        # $DatabaseConfig オブジェクトにエディション プロパティがあり、プロパティ値が null または空ではない場合
        if ((Test-Member $DatabaseConfig 'edition') -and $DatabaseConfig.edition)
        {
            $param.Add('Edition', $DatabaseConfig.edition)
        }

        # 詳細ストリームにハッシュ テーブルを書き込みます
        $param | Out-String | Write-VerboseWithTime
        # スプラッティングを使用して New-AzureSqlDatabase を呼び出します (出力は表示されません)
        $db = New-AzureSqlDatabase @param
    }

    Write-VerboseWithTime 'Add-AzureSQLDatabase: 終了'
    return $db
}
