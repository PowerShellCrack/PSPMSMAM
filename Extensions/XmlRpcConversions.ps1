##*=============================================
##* FUNCTION LISTINGS
##*=============================================
function ConvertTo-XmlRpcType
{
    <#
        .SYNOPSIS
            Convert Data into XML declared datatype string

        .DESCRIPTION
            Convert Data into XML declared datatype string

        .OUTPUTS
            string

        .PARAMETER InputObject
            Object to be converted to XML string

        .PARAMETER CustomTypes
            Array of custom Object Types to be considered when converting

        .EXAMPLE
            ConvertTo-XmlRpcType "Hello World"
            --------
            Returns
            <value><string>Hello World</string></value>

        .EXAMPLE
            ConvertTo-XmlRpcType 42
            --------
            Returns
            <value><int32>42</int32></value>
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [AllowNull()]
        [Parameter(
            Position=1,
            Mandatory=$true
        )]
        $InputObject,

        [Parameter()]
        [Array]$CustomTypes
    )

    Begin
    {
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"
        $Objects = @('Object')
        $objects += $CustomTypes
    }

    Process
    {
        if ($null -ne $inputObject)
        {
            [string]$Type=$inputObject.GetType().Name
            # [string]$BaseType=$inputObject.GetType().BaseType
        }
        else
        {
            return "<value></value>"
        }

        # Return simple Types
        if (('Double','Int32','Boolean','False') -contains $Type)
        {
            return "<value><$($Type)>$($inputObject)</$($Type)></value>"
        }

        # Encode string to HTML
        if ($Type -eq 'String')
        {
            return "<value><$Type>$([System.Web.HttpUtility]::HtmlEncode($inputObject))</$Type></value>"
        }

        # Int32 must be casted as Int
        if ($Type -eq 'Int16')
        {
            return "<value><int>$inputObject</int></value>"
        }

        if ($type -eq "SwitchParameter")
        {
            return "<value><boolean>$inputObject.IsPresent</boolean></value>"
        }

        # Return In64 as Double
        if (('Int64') -contains $Type)
        {
            return "<value><Double>$inputObject</Double></value>"
        }

        # DateTime
        if('DateTime' -eq $Type)
        {
            return "<value><dateTime.iso8601>$($inputObject.ToString(
            'yyyyMMddTHH:mm:ss'))</dateTime.iso8601></value>"
        }

        # Loop though Array
        if(($inputObject -is [Array]) -or ($Type -eq "List``1"))
        {
            try
            {
                return "<value><array><data>$(
                    [string]::Join(
                        '',
                        ($inputObject | ForEach-Object {
                            if ($null -ne $_) {
                                ConvertTo-XmlRpcType $_ -CustomTypes $CustomTypes
                            } else {}
                        } )
                    )
                )</data></array></value>"
            }
            catch
            {
                throw
            }
        }

        # Loop though HashTable Keys
        if('Hashtable' -eq $Type)
        {
            return "<value><struct>$(
                [string]::Join(
                    '',
                    ($inputObject.Keys| Foreach-Object {
                        "<member><name>$($_)</name>$(
                            if ($null -ne $inputObject[$_]) {
                                ConvertTo-XmlRpcType $inputObject[$_] -CustomTypes $CustomTypes
                            } else {
                                ConvertTo-XmlRpcType $null
                            })</member>"
                    } )
                )
            )</struct></value>"
        }

        # Loop though Object Properties
        if(($Objects -contains $Type) -and ($inputObject))
        {
            return "<value><struct>$(
                [string]::Join(
                    '',
                    (
                        ($inputObject | Get-Member -MemberType Properties).Name | Foreach-Object {
                            if ($null -ne $inputObject.$_) {
                                "<member><name>$($_)</name>$(
                                    ConvertTo-XmlRpcType $inputObject.$_ -CustomTypes $CustomTypes
                                )</member>"
                            }
                        }
                    )
                )
            )</struct></value>"
        }

        # XML
        if ('XmlElement','XmlDocument' -contains $Type)
        {
            return $inputObject.InnerXml.ToString()
        }

        # XML
        if ($inputObject -match "<([^<>]+)>([^<>]+)</\\1>")
        {
            return $inputObject
        }
    }

    End
        { Write-Verbose "$($MyInvocation.MyCommand.Name):: Function Ended" }
}

function ConvertTo-XmlRpcMethodCall
{
    <#
        .SYNOPSIS
            Create a XML RPC Method Call string

        .DESCRIPTION
            Create a XML RPC Method Call string

        .INPUTS
            string
            array

        .OUTPUTS
            string

        .PARAMETER Name
            Name of the Method to be called

        .PARAMETER Params
            Parameters to be passed to the Method

        .PARAMETER CustomTypes
            Array of custom Object Types to be considered when converting

        .EXAMPLE
            ConvertTo-XmlRpcMethodCall -Name updateName -Params @('oldName', 'newName')
            ----------
            Returns (line split and indentation just for conveniance)
            <?xml version=""1.0""?>
            <methodCall>
              <methodName>updateName</methodName>
              <params>
                <param><value><string>oldName</string></value></param>
                <param><value><string>newName</string></value></param>
              </params>
            </methodCall>
    #>
    [CmdletBinding()]
    [OutputType(
        [string]
    )]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Name,

        [Parameter()]
        [Array]$Params,

        [Parameter()]
        [Array]$CustomTypes
    )

    Begin {}

    Process
    {
        [String]((&{
            "<?xml version=""1.0""?><methodCall><methodName>$($Name)</methodName><params>"
            if($Params)
            {
                $Params | ForEach-Object {
                    "<param>$(&{ConvertTo-XmlRpcType $_ -CustomTypes $CustomTypes})</param>"
                }
            }
            else
            {
                "$(ConvertTo-XmlRpcType $NULL)"
            }
            "</params></methodCall>"
        }) -join(''))
    }

    End {}
}

function Send-XmlRpcRequest
{
    <#
        .SYNOPSIS
            Send a XML RPC Request

        .DESCRIPTION
            Send a XML RPC Request

        .INPUTS
            string
            array

        .OUTPUTS
            XML.XmlDocument

        .EXAMPLE
            Send-XmlRpcRequest -Url "example.com" -MethodName "updateName" -Params @('oldName', 'newName')
            ---------
            Description
            Calls a method "updateName("oldName", "newName")" on the server example.com
    #>
    [CmdletBinding()]
    [OutputType([Xml.XmlDocument])]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Url,

        [Parameter(Mandatory = $true)]
        [String]$MethodName,

        [Parameter()]
        [Array]$Params,

        [Parameter()]
        [Array]$CustomTypes,

        $methodCall
    )

    Begin {}

    Process
    {
        if (!$methodCall) {
            $methodCall = ConvertTo-XmlRpcMethodCall $MethodName $Params -CustomTypes $CustomTypes
            Write-Debug "Request BODY: $methodCall"
        }

        try
        {
            $client = New-Object Net.WebClient
            $client.Encoding = [System.Text.Encoding]::UTF8
            $response = $client.UploadString($Url, $methodCall)

            $doc = New-Object Xml.XmlDocument
            $doc.LoadXml($response)
            [Xml.XmlDocument]$doc
        }
        catch [System.Net.WebException],[System.IO.IOException]{
            $message = "WebClient Error"
            $itemNotFoundException = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList $message
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $itemNotFoundException,$itemNotFoundException.GetType().Name,'ConnectionError',$client
            Throw $errorRecord
        }
        catch {
            Throw $_
        }
    }

    End {}
}

function ConvertFrom-Xml
{
    [CmdletBinding()]
    param(
        # Array node
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$InputObject
    )

    Begin
    {
        $endFormats = @('Int32','Double','Boolean','String','False','dateTime.iso8601')

        function ConvertFrom-XmlNode
        {
            [CmdletBinding()]
            [OutputType(
                [System.Int32],
                [System.Double],
                [System.Boolean],
                [System.String],
                [System.Boolean],
                [System.Datetime]
            )]
            param(
                [Parameter(Mandatory = $true)]
                $InputNode
            )

            Begin
            {
                $endFormats = @('Int32','Double','Boolean','String','False','dateTime.iso8601')
            }

            Process
            {
                switch (($InputNode | Get-Member -MemberType Properties).Name)
                {
                    'struct' {
                        $properties = @{}
                        foreach ($member in ($InputNode.struct.member))
                        {
                            if (!($member.value.gettype().name -in ("XmlElement","Object[]")))
                            {
                                $properties[$member.name] = $member.value
                            }
                            else
                            {
                                $properties[$member.name] = ConvertFrom-XmlNode $member.value
                            }
                        }

                        $properties
                        break
                    }
                    'array' {
                        if ($InputNode.array.data)
                        {
                            foreach ($member in ($InputNode.array.data))
                            {
                                if (!($member.value.gettype().name -in ("XmlElement","Object[]")))
                                {
                                    $member.value
                                }
                                else
                                {
                                    $member.value | ForEach-Object {
                                        ConvertFrom-XmlNode $_
                                    }
                                }
                            }
                        }
                        break
                    }
                    'boolean' {
                        [bool]$InputNode.boolean
                        break
                    }
                    'dateTime.iso8601' {
                        $string = $InputNode.'dateTime.iso8601'
                        [datetime]::ParseExact($string,"yyyyMMddTHH:mm:ss",$null)
                        break
                    }
                    Default {
                        $InputNode
                        break
                    }
                }
            }
            End
            {}
        }
    }
    Process{
        foreach ($param in ($InputObject.methodResponse.params.param)){
            foreach ($value in $param.value){
                ConvertFrom-XmlNode $value
            }
        }
    }
    End {}
}


<#
.Synopsis
   New XML_RPC method string.
.DESCRIPTION
   New XML_RPC method string with RPC method and parameters.
.EXAMPLE
   New-RPCMethod -MethodName 'new.post' -Params @("1",2,'string')
.INPUTS
   Object.
.OUTPUTS
   Xml format string.
#>
function New-RPCMethod
{
    param(
    [string]$MethodName,
    [Array]$Params
    )
    $xmlMethod = "<?xml version='1.0' encoding='ISO-8859-1' ?>
      <methodCall>
      <methodName>{0}</methodName>
      <params>{1}</params>
     </methodCall>"

     [string]$paramsValue=""
     foreach($param in $Params)
     {
        $paramsValue += '<param><value>{0}</value></param>' -f (ConvertTo-RPCXmlObject -Object $param)
     }
     return ([xml]($xmlMethod -f $MethodName,$paramsValue)).OuterXml
}


<#
.Synopsis
   Invoke XML_RPC method request.
.DESCRIPTION
   Invoke XML_RPC request to RPC server.
.EXAMPLE
   $blogUrl = 'http://www.pstips.net/myrpc.php'
   $method = New-RPCMethod -MethodName 'wp.getPostTypes' -Params @(1,'userName','password')
.OUTPUTS
   The response result from RPC server.
#>
function Invoke-RPCMethod
{
    param(
    [uri]$RpcServerUri,
    [string]$RequestBody,
    [System.Management.Automation.CredentialAttribute()]
    $Credential
    )
    $xmlResponse = Invoke-RestMethod -Uri $RpcServerUri -Method Post -ContentType "text/xml" -Body $RequestBody -Credential $Credential
    if($xmlResponse)
    {
        # Normal response
        $paramNodes =  $xmlResponse.SelectNodes('methodResponse/params/param/value')
        if($paramNodes)
        {
            $paramNodes | foreach {
              $value = $_.ChildNodes |
               Where-Object { $_.NodeType -eq 'Element' } |
               Select-Object -First 1
              ConvertFrom-RPCXmlObject -XmlObject  $value
            }
        }

        # Fault response
        $faultNode =  $xmlResponse.SelectSingleNode('methodResponse/fault')
        if ($faultNode)
        {
            $fault = ConvertFrom-RPCXmlObject -XmlObject $faultNode.value.struct
            return $fault
        }
    }
}


<#
.Synopsis
   Convert object to XML-RPC object string.
.DESCRIPTION
   Convert object to XML-RPC object string.
.EXAMPLE
   ConvertTo-RPCXmlObject 3
   <int>3</int>

   ConvertTo-RPCXmlObject '3'
   <string>3</string>

   ConvertTo-RPCXmlObject 3.5
   <double>3.5</double>
.OUTPUTS
   The XML-RPC object string.
#>
function ConvertTo-RPCXmlObject
{
    param(
    $Object
    )
    if($Object -ne $null)
    {
        # integer type
        if( ($Object -is [int]) -or ($Object -is [int64]))
        {
            return "<int>$Object</int>"
        }
        # double type
        elseif( ($Object -is [float]) -or ($Object -is [double]) -or ($Object -is [decimal]))
        {
            return "<double>$Object</double>"
        }
        # string type
        elseif( $Object -is [string])
        {
            return "<string>$Object</string>"
        }
        # date/time type
        elseif($Object -is [datetime])
        {
            $dateStr = $Object.ToString('yyyyMMddTHH:mm:ss')
            return "<dateTime.iso8601>$dateStr</dateTime.iso8601>"
        }
        # boolean type
        elseif($Object -is [bool])
        {
            $bool = [int]$Object
            return "<boolean>$bool</boolean>"
        }
        # base64 type
        elseif( ($Object -is [array]) -and ($Object.GetType().GetElementType() -eq [byte]))
        {
            $base64Str = [Convert]::ToBase64String($Object)
            return "<base64>$base64Str</base64>"
        }
        # array type
        elseif( $Object -is [array])
        {
            $result = '<array>
            <data>'
            foreach($element in $Object)
            {
                $value = ConvertTo-RPCXmlObject -Object $element
                $result +=  "<value>{0}</value>" -f $value
            }
            $result += '</data>
            </array>'
            return $result
        }
        # struct type
        elseif($Object -is [Hashtable])
        {
            $result = '<struct>'
            foreach ($key in $Object.Keys)
            {
                $member = "<member>
                <name>{0}</name>
                <value>{1}</value>
                </member>"
                $member = $member -f $key, (ConvertTo-RPCXmlObject -Object $Object[$key])
                $result = $result + $member
            }
            $result = $result + '</struct>'
            return $result
        }
        elseif($Object -is [PSCustomObject])
        {
            $result = '<struct>'
            $Object |
            Get-Member -MemberType NoteProperty |
            ForEach-Object{
                $member = "<member>
                <name>{0}</name>
                <value>{1}</value>
                </member>"
                $member = $member -f $_.Name, (ConvertTo-RPCXmlObject -Object $Object.($_.Name))
                $result = $result + $member
            }
            $result = $result + '</struct>'
            return $result
        }
        else{
            throw "[$Object] type is not supported."
        }
    }
}


<#
.Synopsis
   Convert to object from XML-RPC object string.
.DESCRIPTION
   Convert to object from XML-RPC object string.
.EXAMPLE
   $s1= '<i4>1919</i4>'
   ConvertFrom-RPCXmlObject -XmlObject $s1
.OUTPUTS
   The XML-RPC object string.
#>
function ConvertFrom-RPCXmlObject
{
 param($XmlObject)
 if($XmlObject -is [string])
 {
    $XmlObject= ([xml]$XmlObject).DocumentElement
 }
 elseif( $XmlObject -is [xml] ){
    $XmlObject = $XmlObject.DocumentElement
 }
 elseif( $XmlObject -isnot [Xml.XmlElement])
 {
    throw 'Only types [string](xml format), [xml], [System.Xml.XmlElement] are supported'
 }

 $node = $XmlObject
 if($node)
 {
    $typeName = $node.Name
    switch($typeName)
    {
     # Bool
     ('boolean') {
        if($node.InnerText -eq '1'){
            return $true
        }
        return $false
     }

     # Number
     ('i4') {[int64]::Parse($node.InnerText) }
     ('int') {[int64]::Parse($node.InnerText) }
     ('double'){ [double]::Parse($node.InnerText) }

     # String
     ('string'){ $node.InnerText }

     # Base64
     ('base64') {
      [Text.UTF8Encoding]::UTF8.GetBytes($node.InnerText)
     }

     # Date Time
     ('dateTime.iso8601'){
      $format = 'yyyyMMddTHH:mm:ss'
      $formatProvider = [Globalization.CultureInfo]::InvariantCulture
      [datetime]::ParseExact($node.InnerText, $format, $formatProvider)
      }

      # Array
      ('array'){
        $node.SelectNodes('data/value') | foreach{
         ConvertFrom-RPCXmlObject -XmlObject $_.FirstChild
        }
      }

      # Struct
      ('struct'){
       $hashTable = @{}
       $node.SelectNodes('member') | foreach {
        $hashTable.Add($_.name,(ConvertFrom-RPCXmlObject -XmlObject $_.value.FirstChild))
       }
        [PSCustomObject]$hashTable
      }
    }
 }
}


<#
XmlRpcRequest [-Url] <[String]> [-MethodName] <[String]> [-Params] <[Object]>
Return Xml-Rpc methodResponse
XmlRpcMethodCall [-Name] <[String]> [-Params] <[Object]>
Return Xml-Rpc methodCall
XmlRpcType [-Value] <[Object]>
Return Xml-Rpc value
#>
function XmlRpcType(){
    param( [Object]$Value )

    if($Value -ne $NULL){ [string]$Type=$Value.GetType().Name }
    else{ $Type=$FALSE }
    if(('Int32','Double','Boolean','String','Base64','False') -contains $Type){
        if($Type){ [string]"<$($Type)><value>$($Value)</value></$($Type)>" }
        else{ [string]"<value></value>" }
        }
    if('DateTime' -eq $Type){
    [string]"<value><dateTime.iso8601>$($Value.ToString('yyyyMMddTHH:mm:ss'))</dateTime.iso8601></value>"
    }
    if($Value -is [Array]){
    [string]"<value><array><data>$(&{ $Value | %{ "$(&{ XmlRpcType $_ })"}})</data></array></value>"
    }
    if('Hashtable' -eq $Type){
    [string]"<value><struct>$(&{ $Value.Keys | %{ "<member><name>$($_)</name>$(&{ XmlRpcType $Value[$_] })</member>" } })</struct></value>"
    }
}

function XmlRpcMethodCall(){
    param(
    [String]$Name=$(throw "Method name is requried parameter!"),
    [Object]$Params
    )
    [String]((&{
    "<?xml version='1.0'?><methodCall><methodName>$($Name)</methodName><params>"
    if($Params){$Params | %{ "<param>$(&{XmlRpcType $_})</param>" } }
    else{"<param>$(&{XmlRpcType $NULL})</param>"}
    "</params></methodCall>"
    }) -join(""))
}

function XmlRpcRequest(){
    param(
    [String]$Url,
    [String]$MethodName,
    [Object]$Params
    )

    if($Url -and $MethodName){
    try{
    ($doc=New-Object Xml.XmlDocument).LoadXml(
    (New-Object Net.WebClient).UploadString(
    $Url,
    (XmlRpcMethodCall $MethodName $Params)
    )
    )
    [Xml.XmlDocument]$doc
    }
    catch [System.Net.WebException],[System.IO.IOException] {'WebClient Error'}
    catch {'Unhandle Error'}
    finally {}
    }
}


##*=============================================
##* VARIABLE DECLARATION
##*=============================================
$SeedboxUrl = "https://ns520746.dediseedbox.com"
$SeedboxUsername = "trickyseeder"
$SeedboxPassword = "L33cherBOX"

$Sonarr_ApiKey = "a807a56c16e14a8d8972e28242077156"
$url = "http://localhost:8989" #change to your Sonarr URL.
$dir = "E:\Data\Downloads\Seedbox"

$opensubtitleUsername = 'trickydick'
$opensubtitlePassword = 'Duncan12'
##*===============================================
##* LOAD ASSEMBLY
##*===============================================
$source = @'
namespace OpenSubtitlesAPI
{
    using CookComputing.XmlRpc;

    [XmlRpcUrl("http://api.opensubtitles.org/xml-rpc")]
    public interface IOpenSubtitles : IXmlRpcProxy
    {
        [XmlRpcMethod("LogIn")]
        XmlRpcStruct LogIn(string username, string password, string language, string useragent);

        [XmlRpcMethod("LogOut")]
        XmlRpcStruct LogOut(string token);

        [XmlRpcMethod("SearchSubtitles")]
        XmlRpcStruct SearchSubtitles(string token, XmlRpcStruct[] queries);

        [XmlRpcMethod("SearchSubtitles")]
        XmlRpcStruct SearchSubtitles(string token, XmlRpcStruct[] queries, int limit);
    }

    public class ProxyFactory
    {
        public static IOpenSubtitles CreateProxy()
        {
            return XmlRpcProxyGen.Create<IOpenSubtitles>();
        }
    }
}
'@

# Load XML-RPC.NET and custom interfaces
if ([Type]::GetType("OpenSubtitlesAPI.ProxyFactory") -eq $null)
{
    [Reflection.Assembly]::LoadFile("E:\Data\Processors\bin\CookComputing.XmlRpcV2.dll") | Out-Null
    $dynamicAssembly = Add-Type -TypeDefinition $source -ReferencedAssemblies ("E:\Data\Processors\bin\CookComputing.XmlRpcV2.dll")
}

# Set up proxy
$proxy = [OpenSubtitlesAPI.ProxyFactory]::CreateProxy()
$proxy.UserAgent = "user agent"
$proxy.EnableCompression = $true

# Log in
$LogInResponse = $proxy.LogIn($opensubtitleUsername, $opensubtitlePassword, "language", "user agent")

# Build query
$query = New-Object CookComputing.XmlRpc.XmlRpcStruct
$query.Add("moviehash", "movie hash")
$query.Add("moviebytesize", "movie size")
$query.Add("sublanguageid", "language")
$queries = @($query)

# Search
$SearchResponse = $proxy.SearchSubtitles($LogInResponse.token, $queries)

# Log out
$LogOutResponse = $proxy.LogOut($LogInResponse.token)

##*===============================================
##* MAIN ROUTINE
##*===============================================
Add-Type -AssemblyName System.Web

##* SONARR
##*===============================================
#https://forums.sonarr.tv/t/guide-automatically-process-rar-releases-in-sonarr-radarr-while-using-usenet-and-torrents-on-a-windows-environment/13743
$sonarrStatus = Invoke-WebRequest "$url/api/system/status?apikey=$Sonarr_ApiKey"
If($sonarrStatus.StatusDescription -eq 'OK'){Write-host "Sonarr is running"}

$allitems=@(Get-ChildItem -Recurse $dir | ?{ $_.PSIsContainer }).fullname #get list of all folders in your completed downlaods directory.
for($i=0;$i -lt $allitems.count;$i++){ #iterate through folders
    $escaped = $allitems.get($i).replace('\','\\')  #add necessary escape characters
    $json1 = "{ ""name"": ""downloadedepisodesscan"",""path"": """ #beginning of body
    $json2 = """}" #end of body
    $jsoncomplete = $json1 + $escaped + $json2 #piece body together.
    Invoke-RestMethod -Uri "$url/api/command" -Method Post -Body $jsoncomplete -Headers @{"X-Api-Key"=$Sonarr_ApiKey} #do it
}


$notify_headers = "{'content-type': 'application/json', 'accept': 'application/json', 'X-Api-Key': $Sonarr_ApiKey}"
$notify_data = "{'name': 'DownloadedEpisodesScan', 'importMode': 'Move', 'downloadClientId': $torrent,'path': $dir}"
Invoke-RestMethod -Uri $url -Method Post -Body "{'name': 'DownloadedEpisodesScan', 'importMode': 'Move', 'downloadClientId': $torrent,'path': $dir}" -Headers "{'content-type': 'application/json', 'accept': 'application/json'}"





##* DEDISEEDBOX
##*===============================================
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add('Accept','Application/Json')
$headers.Add('X-My-Header','...')

$secpasswd = ConvertTo-SecureString $SeedboxPassword -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($SeedboxUsername, $secpasswd)

$seedboxStatus = Invoke-WebRequest "$SeedboxUrl/rutorrent/plugins/httprpc/action.php" -Credential $credentials -Headers $headers
If($seedboxStatus.StatusDescription -eq 'OK'){Write-host "Seedbox is connected"}

#system.multicall
$requestString = "<?xml version='1.0'?><methodCall><methodName>system.listMethods</methodName></methodCall>"
$bytes = [System.Text.Encoding]::Unicode.GetBytes($requestString)
$request = [System.Text.Encoding]::ASCII.GetString($bytes)
#$response = Invoke-RestMethod -Uri "$SeedboxUrl/rutorrent/plugins/httprpc/action.php" -Method Post -Body $request -Credential $credentials
#$responselist = $response.methodResponse.params.param.value.array.data.value
$responselist = Invoke-RPCMethod -RpcServerUri "$SeedboxUrl/rutorrent/plugins/httprpc/action.php" -RequestBody $request -Credential $credentials


$watchdirectory = "/sdb/0011/watch"
$tvdirectory = "/sdb/0011/trickyseeder-TV-Shows"
$moviedirectory = "/sdb/0011/trickyseeder-TV-Movies"

$i = 0
$rt = @()
Foreach ($item in $responselist){
    $method = $item
    $body = New-RPCMethod -MethodName download_list #-Params @(,'')
    $itemresponse = Invoke-RPCMethod -RpcServerUri "$SeedboxUrl/rutorrent/plugins/httprpc/action.php" -RequestBody $body -Credential $credentials
    If( ($itemresponse.faultCode -ne -503) -and ($itemresponse.faultCode -ne -502) ){
        $rt += New-Object -TypeName 'PSObject' -Property @{
							    Method = $method
							    Response = $itemresponse
						    }
    }
    $i += 1
    Write-Progress -Activity "Gathering Methods" -status "Method: $item" -percentComplete ($i / $responselist.count*100)
}


$rt.Item

switch($ActionCMD){
'system.listMethods' { $params = @(,"")}
'system.methodExist' { $params = @(,"")}
'system.methodHelp' { $params = @(,"")}
'system.methodSignature' { $params = @(,"")}
'system.multicall' { $params = @(,"")}
'system.shutdown' { $params = @(,"")}
'system.capabilities' { $params = @(,"")}
'system.getCapabilities' { $params = @(,"")}
'add_peer' { $params = @(,"")}
'and' { $params = @(,"")}
'bind' { $params = @(,"")}
'branch' { $params = @(,"")}
'cat' { $params = @(,"")}
'catch' { $params = @(,"")}
'check_hash' { $params = @(,"")}
'choke_group.down.heuristics' { $params = @(,"")}
'choke_group.down.heuristics.set' { $params = @(,"")}
'choke_group.down.max' { $params = @(,"")}
'choke_group.down.max.set' { $params = @(,"")}
'choke_group.down.max.unlimited' { $params = @(,"")}
'choke_group.down.queued' { $params = @(,"")}
'choke_group.down.rate' { $params = @(,"")}
'choke_group.down.total' { $params = @(,"")}
'choke_group.down.unchoked' { $params = @(,"")}
'choke_group.general.size' { $params = @(,"")}
'choke_group.index_of' { $params = @(,"")}
'choke_group.insert' { $params = @(,"")}
'choke_group.list' { $params = @(,"")}
'choke_group.size' { $params = @(,"")}
'choke_group.tracker.mode' { $params = @(,"")}
'choke_group.tracker.mode.set' { $params = @(,"")}
'choke_group.up.heuristics' { $params = @(,"")}
'choke_group.up.heuristics.set' { $params = @(,"")}
'choke_group.up.max' { $params = @(,"")}
'choke_group.up.max.set' { $params = @(,"")}
'choke_group.up.max.unlimited' { $params = @(,"")}
'choke_group.up.queued' { $params = @(,"")}
'choke_group.up.rate' { $params = @(,"")}
'choke_group.up.total' { $params = @(,"")}
'choke_group.up.unchoked' { $params = @(,"")}
'close_low_diskspace' { $params = @(,"")}
'close_untied' { $params = @(,"")}
'connection_leech' { $params = @(,"")}
'connection_seed' { $params = @(,"")}
'convert.date' { $params = @(,"")}
'convert.elapsed_time' { $params = @(,"")}
'convert.gm_date' { $params = @(,"")}
'convert.gm_time' { $params = @(,"")}
'convert.kb' { $params = @(,"")}
'convert.mb' { $params = @(,"")}
'convert.throttle' { $params = @(,"")}
'convert.time' { $params = @(,"")}
'convert.xb' { $params = @(,"")}
'd.accepting_seeders' { $params = @(,"")}
'd.accepting_seeders.disable' { $params = @(,"")}
'd.accepting_seeders.enable' { $params = @(,"")}
'd.base_filename' { $params = @(,"")}
'd.base_path' { $params = @(,"")}
'd.bitfield' { $params = @(,"")}
'd.bytes_done' { $params = @(,"")}
'd.check_hash' { $params = @(,"")}
'd.chunk_size' { $params = @(,"")}
'd.chunks_hashed' { $params = @(,"")}
'd.chunks_seen' { $params = @(,"")}
'd.close' { $params = @(,"")}
'd.close.directly' { $params = @(,"")}
'd.complete' { $params = @(,"")}
'd.completed_bytes' { $params = @(,"")}
'd.completed_chunks' { $params = @(,"")}
'd.connection_current' { $params = @(,"")}
'd.connection_current.set' { $params = @(,"")}
'd.connection_leech' { $params = @(,"")}
'd.connection_seed' { $params = @(,"")}
'd.create_link' { $params = @(,"")}
'd.creation_date' { $params = @(,"")}
'd.custom' { $params = @(,"")}
'd.custom.set' { $params = @(,"")}
'd.custom1' { $params = @(,"")}
'd.custom1.set' { $params = @(,"")}
'd.custom2' { $params = @(,"")}
'd.custom2.set' { $params = @(,"")}
'd.custom3' { $params = @(,"")}
'd.custom3.set' { $params = @(,"")}
'd.custom4' { $params = @(,"")}
'd.custom4.set' { $params = @(,"")}
'd.custom5' { $params = @(,"")}
'd.custom5.set' { $params = @(,"")}
'd.custom_throw' { $params = @(,"")}
'd.delete_link' { $params = @(,"")}
'd.delete_tied' { $params = @(,"")}
'd.directory' { $params = @(,"")}
'd.directory.set' { $params = @(,"")}
'd.directory_base' { $params = @(,"")}
'd.directory_base.set' { $params = @(,"")}
'd.disconnect.seeders' { $params = @(,"")}
'd.down.choke_heuristics' { $params = @(,"")}
'd.down.choke_heuristics.leech' { $params = @(,"")}
'd.down.choke_heuristics.seed' { $params = @(,"")}
'd.down.choke_heuristics.set' { $params = @(,"")}
'd.down.rate' { $params = @(,"")}
'd.down.total' { $params = @(,"")}
'd.downloads_max' { $params = @(,"")}
'd.downloads_max.set' { $params = @(,"")}
'd.downloads_min' { $params = @(,"")}
'd.downloads_min.set' { $params = @(,"")}
'd.erase' { $params = @(,"")}
'd.free_diskspace' { $params = @(,"")}
'd.group' { $params = @(,"")}
'd.group.name' { $params = @(,"")}
'd.group.set' { $params = @(,"")}
'd.hash' { $params = @(,"")}
'd.hashing' { $params = @(,"")}
'd.hashing_failed' { $params = @(,"")}
'd.hashing_failed.set' { $params = @(,"")}
'd.ignore_commands' { $params = @(,"")}
'd.ignore_commands.set' { $params = @(,"")}
'd.incomplete' { $params = @(,"")}
'd.is_active' { $params = @(,"")}
'd.is_hash_checked' { $params = @(,"")}
'd.is_hash_checking' { $params = @(,"")}
'd.is_multi_file' { $params = @(,"")}
'd.is_not_partially_done' { $params = @(,"")}
'd.is_open' { $params = @(,"")}
'd.is_partially_done' { $params = @(,"")}
'd.is_pex_active' { $params = @(,"")}
'd.is_private' { $params = @(,"")}
'd.left_bytes' { $params = @(,"")}
'd.load_date' { $params = @(,"")}
'd.loaded_file' { $params = @(,"")}
'd.local_id' { $params = @(,"")}
'd.local_id_html' { $params = @(,"")}
'd.max_file_size' { $params = @(,"")}
'd.max_file_size.set' { $params = @(,"")}
'd.max_size_pex' { $params = @(,"")}
'd.message' { $params = @(,"")}
'd.message.set' { $params = @(,"")}
'd.mode' { $params = @(,"")}
'd.multicall2' { $params = @(,"")}
'd.name' { $params = @(,"")}
'd.open' { $params = @(,"")}
'd.pause' { $params = @(,"")}
'd.peer_exchange' { $params = @(,"")}
'd.peer_exchange.set' { $params = @(,"")}
'd.peers_accounted' { $params = @(,"")}
'd.peers_complete' { $params = @(,"")}
'd.peers_connected' { $params = @(,"")}
'd.peers_max' { $params = @(,"")}
'd.peers_max.set' { $params = @(,"")}
'd.peers_min' { $params = @(,"")}
'd.peers_min.set' { $params = @(,"")}
'd.peers_not_connected' { $params = @(,"")}
'd.priority' { $params = @(,"")}
'd.priority.set' { $params = @(,"")}
'd.priority_str' { $params = @(,"")}
'd.ratio' { $params = @(,"")}
'd.resume' { $params = @(,"")}
'd.save_full_session' { $params = @(,"")}
'd.save_resume' { $params = @(,"")}
'd.size_bytes' { $params = @(,"")}
'd.size_chunks' { $params = @(,"")}
'd.size_files' { $params = @(,"")}
'd.size_pex' { $params = @(,"")}
'd.skip.rate' { $params = @(,"")}
'd.skip.total' { $params = @(,"")}
'd.start' { $params = @(,"")}
'd.state' { $params = @(,"")}
'd.state_changed' { $params = @(,"")}
'd.state_counter' { $params = @(,"")}
'd.stop' { $params = @(,"")}
'd.throttle_name' { $params = @(,"")}
'd.throttle_name.set' { $params = @(,"")}
'd.tied_to_file' { $params = @(,"")}
'd.tied_to_file.set' { $params = @(,"")}
'd.timestamp.finished' { $params = @(,"")}
'd.timestamp.started' { $params = @(,"")}
'd.tracker.insert' { $params = @(,"")}
'd.tracker.send_scrape' { $params = @(,"")}
'd.tracker_announce' { $params = @(,"")}
'd.tracker_focus' { $params = @(,"")}
'd.tracker_numwant' { $params = @(,"")}
'd.tracker_numwant.set' { $params = @(,"")}
'd.tracker_size' { $params = @(,"")}
'd.try_close' { $params = @(,"")}
'd.try_start' { $params = @(,"")}
'd.try_stop' { $params = @(,"")}
'd.up.choke_heuristics' { $params = @(,"")}
'd.up.choke_heuristics.leech' { $params = @(,"")}
'd.up.choke_heuristics.seed' { $params = @(,"")}
'd.up.choke_heuristics.set' { $params = @(,"")}
'd.up.rate' { $params = @(,"")}
'd.up.total' { $params = @(,"")}
'd.update_priorities' { $params = @(,"")}
'd.uploads_max' { $params = @(,"")}
'd.uploads_max.set' { $params = @(,"")}
'd.uploads_min' { $params = @(,"")}
'd.uploads_min.set' { $params = @(,"")}
'd.views' { $params = @(,"")}
'd.views.has' { $params = @(,"")}
'd.views.push_back' { $params = @(,"")}
'd.views.push_back_unique' { $params = @(,"")}
'd.views.remove' { $params = @(,"")}
'd.wanted_chunks' { $params = @(,"")}
'dht' { $params = @(,"")}
'dht.add_node' { $params = @(,"")}
'dht.mode.set' { $params = @(,"")}
'dht.port' { $params = @(,"")}
'dht.port.set' { $params = @(,"")}
'dht.statistics' { $params = @(,"")}
'dht.throttle.name' { $params = @(,"")}
'dht.throttle.name.set' { $params = @(,"")}
'dht_port' { $params = @(,"")}
'directory' { $params = @(,"")}
'directory.default' { $params = @(,"")}
'directory.default.set' { $params = @(,"")}
'directory.watch.added' { $params = @(,"")}
'download_list' { $params = @(,"")}
'download_rate' { $params = @(,"")}
'elapsed.greater' { $params = @(,"")}
'elapsed.less' { $params = @(,"")}
'encoding.add' { $params = @(,"")}
'encoding_list' { $params = @(,"")}
'encryption' { $params = @(,"")}
'equal' { $params = @(,"")}
'event.download.closed' { $params = @(,"")}
'event.download.erased' { $params = @(,"")}
'event.download.finished' { $params = @(,"")}
'event.download.hash_done' { $params = @(,"")}
'event.download.hash_failed' { $params = @(,"")}
'event.download.hash_final_failed' { $params = @(,"")}
'event.download.hash_queued' { $params = @(,"")}
'event.download.hash_removed' { $params = @(,"")}
'event.download.inserted' { $params = @(,"")}
'event.download.inserted_new' { $params = @("$watchdirectory/vnf62.torrent.fail","execute=mv,-u,d.loaded_file=,$tvdirectory")}
'event.download.inserted_session' { $params = @(,"")}
'event.download.opened' { $params = @(,"")}
'event.download.paused' { $params = @(,"")}
'event.download.resumed' { $params = @(,"")}
'execute' { $params = @(,"")}
'execute.capture' { $params = @(,"")}
'execute.capture_nothrow' { $params = @(,"")}
'execute.nothrow' { $params = @(,"")}
'execute.nothrow.bg' { $params = @(,"")}
'execute.raw' { $params = @(,"")}
'execute.raw.bg' { $params = @(,"")}
'execute.raw_nothrow' { $params = @(,"")}
'execute.raw_nothrow.bg' { $params = @(,"")}
'execute.throw' { $params = @(,"")}
'execute.throw.bg' { $params = @(,"")}
'execute2' { $params = @(,"")}
'f.completed_chunks' { $params = @(,"")}
'f.frozen_path' { $params = @(,"")}
'f.is_create_queued' { $params = @(,"")}
'f.is_created' { $params = @(,"")}
'f.is_open' { $params = @(,"")}
'f.is_resize_queued' { $params = @(,"")}
'f.last_touched' { $params = @(,"")}
'f.match_depth_next' { $params = @(,"")}
'f.match_depth_prev' { $params = @(,"")}
'f.multicall' { $params = @(,"")}
'f.offset' { $params = @(,"")}
'f.path' { $params = @(,"")}
'f.path_components' { $params = @(,"")}
'f.path_depth' { $params = @(,"")}
'f.prioritize_first' { $params = @(,"")}
'f.prioritize_first.disable' { $params = @(,"")}
'f.prioritize_first.enable' { $params = @(,"")}
'f.prioritize_last' { $params = @(,"")}
'f.prioritize_last.disable' { $params = @(,"")}
'f.prioritize_last.enable' { $params = @(,"")}
'f.priority' { $params = @(,"")}
'f.priority.set' { $params = @(,"")}
'f.range_first' { $params = @(,"")}
'f.range_second' { $params = @(,"")}
'f.set_create_queued' { $params = @(,"")}
'f.set_resize_queued' { $params = @(,"")}
'f.size_bytes' { $params = @(,"")}
'f.size_chunks' { $params = @(,"")}
'f.unset_create_queued' { $params = @(,"")}
'f.unset_resize_queued' { $params = @(,"")}
'false' { $params = @(,"")}
'fi.filename_last' { $params = @(,"")}
'fi.is_file' { $params = @(,"")}
'file.append' { $params = @(,"")}
'file.prioritize_toc' { $params = @(,"")}
'file.prioritize_toc.first' { $params = @(,"")}
'file.prioritize_toc.first.push_back' { $params = @(,"")}
'file.prioritize_toc.first.set' { $params = @(,"")}
'file.prioritize_toc.last' { $params = @(,"")}
'file.prioritize_toc.last.push_back' { $params = @(,"")}
'file.prioritize_toc.last.set' { $params = @(,"")}
'file.prioritize_toc.set' { $params = @(,"")}
'greater' { $params = @(,"")}
'group.insert' { $params = @(,"")}
'group.insert_persistent_view' { $params = @(,"")}
'group.seeding.ratio.command' { $params = @(,"")}
'group.seeding.ratio.disable' { $params = @(,"")}
'group.seeding.ratio.enable' { $params = @(,"")}
'group.seeding.ratio.max' { $params = @(,"")}
'group.seeding.ratio.max.set' { $params = @(,"")}
'group.seeding.ratio.min' { $params = @(,"")}
'group.seeding.ratio.min.set' { $params = @(,"")}
'group.seeding.ratio.upload' { $params = @(,"")}
'group.seeding.ratio.upload.set' { $params = @(,"")}
'group.seeding.view' { $params = @(,"")}
'group.seeding.view.set' { $params = @(,"")}
'group2.seeding.ratio.max' { $params = @(,"")}
'group2.seeding.ratio.max.set' { $params = @(,"")}
'group2.seeding.ratio.min' { $params = @(,"")}
'group2.seeding.ratio.min.set' { $params = @(,"")}
'group2.seeding.ratio.upload' { $params = @(,"")}
'group2.seeding.ratio.upload.set' { $params = @(,"")}
'group2.seeding.view' { $params = @(,"")}
'group2.seeding.view.set' { $params = @(,"")}
'if' { $params = @(,"")}
'import' { $params = @(,"")}
'ip' { $params = @(,"")}
'ip_tables.add_address' { $params = @(,"")}
'ip_tables.get' { $params = @(,"")}
'ip_tables.insert_table' { $params = @(,"")}
'ip_tables.size_data' { $params = @(,"")}
'ipv4_filter.add_address' { $params = @(,"")}
'ipv4_filter.dump' { $params = @(,"")}
'ipv4_filter.get' { $params = @(,"")}
'ipv4_filter.load' { $params = @(,"")}
'ipv4_filter.size_data' { $params = @(,"")}
'key_layout' { $params = @(,"")}
'keys.layout' { $params = @(,"")}
'keys.layout.set' { $params = @(,"")}
'less' { $params = @(,"")}
'load.normal' { $params = @(,"")}
'load.raw' { $params = @(,"")}
'load.raw_start' { $params = @(,"")}
'load.raw_start_verbose' { $params = @(,"")}
'load.raw_verbose' { $params = @(,"")}
'load.start' { $params = @(,"")}
'load.start_verbose' { $params = @(,"")}
'load.verbose' { $params = @(,"")}
'log.add_output' { $params = @(,"")}
'log.execute' { $params = @(,"")}
'log.open_file' { $params = @(,"")}
'log.open_file_pid' { $params = @(,"")}
'log.open_gz_file' { $params = @(,"")}
'log.open_gz_file_pid' { $params = @(,"")}
'log.vmmap.dump' { $params = @(,"")}
'log.xmlrpc' { $params = @(,"")}
'max_downloads' { $params = @(,"")}
'max_downloads_div' { $params = @(,"")}
'max_downloads_global' { $params = @(,"")}
'max_memory_usage' { $params = @(,"")}
'max_peers' { $params = @(,"")}
'max_peers_seed' { $params = @(,"")}
'max_uploads' { $params = @(,"")}
'max_uploads_div' { $params = @(,"")}
'max_uploads_global' { $params = @(,"")}
'method.const' { $params = @(,"")}
'method.const.enable' { $params = @(,"")}
'method.erase' { $params = @(,"")}
'method.get' { $params = @(,"")}
'method.has_key' { $params = @(,"")}
'method.insert' { $params = @(,"")}
'method.insert.c_simple' { $params = @(,"")}
'method.insert.s_c_simple' { $params = @(,"")}
'method.insert.simple' { $params = @(,"")}
'method.insert.value' { $params = @(,"")}
'method.list_keys' { $params = @(,"")}
'method.redirect' { $params = @(,"")}
'method.rlookup' { $params = @(,"")}
'method.rlookup.clear' { $params = @(,"")}
'method.set' { $params = @(,"")}
'method.set_key' { $params = @(,"")}
'method.use_deprecated' { $params = @(,"")}
'method.use_deprecated.set' { $params = @(,"")}
'method.use_intermediate' { $params = @(,"")}
'method.use_intermediate.set' { $params = @(,"")}
'min_downloads' { $params = @(,"")}
'min_peers' { $params = @(,"")}
'min_peers_seed' { $params = @(,"")}
'min_uploads' { $params = @(,"")}
'network.bind_address' { $params = @(,"")}
'network.bind_address.set' { $params = @(,"")}
'network.http.cacert' { $params = @(,"")}
'network.http.cacert.set' { $params = @(,"")}
'network.http.capath' { $params = @(,"")}
'network.http.capath.set' { $params = @(,"")}
'network.http.dns_cache_timeout' { $params = @(,"")}
'network.http.dns_cache_timeout.set' { $params = @(,"")}
'network.http.max_open' { $params = @(,"")}
'network.http.max_open.set' { $params = @(,"")}
'network.http.proxy_address' { $params = @(,"")}
'network.http.proxy_address.set' { $params = @(,"")}
'network.http.ssl_verify_host' { $params = @(,"")}
'network.http.ssl_verify_host.set' { $params = @(,"")}
'network.http.ssl_verify_peer' { $params = @(,"")}
'network.http.ssl_verify_peer.set' { $params = @(,"")}
'network.listen.backlog' { $params = @(,"")}
'network.listen.backlog.set' { $params = @(,"")}
'network.listen.port' { $params = @(,"")}
'network.local_address' { $params = @(,"")}
'network.local_address.set' { $params = @(,"")}
'network.max_open_files' { $params = @(,"")}
'network.max_open_files.set' { $params = @(,"")}
'network.max_open_sockets' { $params = @(,"")}
'network.max_open_sockets.set' { $params = @(,"")}
'network.open_sockets' { $params = @(,"")}
'network.port_open' { $params = @(,"")}
'network.port_open.set' { $params = @(,"")}
'network.port_random' { $params = @(,"")}
'network.port_random.set' { $params = @(,"")}
'network.port_range' { $params = @(,"")}
'network.port_range.set' { $params = @(,"")}
'network.proxy_address' { $params = @(,"")}
'network.proxy_address.set' { $params = @(,"")}
'network.receive_buffer.size' { $params = @(,"")}
'network.receive_buffer.size.set' { $params = @(,"")}
'network.scgi.dont_route' { $params = @(,"")}
'network.scgi.dont_route.set' { $params = @(,"")}
'network.scgi.open_local' { $params = @(,"")}
'network.scgi.open_port' { $params = @(,"")}
'network.send_buffer.size' { $params = @(,"")}
'network.send_buffer.size.set' { $params = @(,"")}
'network.tos.set' { $params = @(,"")}
'network.xmlrpc.dialect.set' { $params = @(,"")}
'network.xmlrpc.size_limit' { $params = @(,"")}
'network.xmlrpc.size_limit.set' { $params = @(,"")}
'not' { $params = @(,"")}
'on_ratio' { $params = @(,"")}
'or' { $params = @(,"")}
'p.address' { $params = @(,"")}
'p.banned' { $params = @(,"")}
'p.banned.set' { $params = @(,"")}
'p.call_target' { $params = @(,"")}
'p.client_version' { $params = @(,"")}
'p.completed_percent' { $params = @(,"")}
'p.disconnect' { $params = @(,"")}
'p.disconnect_delayed' { $params = @(,"")}
'p.down_rate' { $params = @(,"")}
'p.down_total' { $params = @(,"")}
'p.id' { $params = @(,"")}
'p.id_html' { $params = @(,"")}
'p.is_encrypted' { $params = @(,"")}
'p.is_incoming' { $params = @(,"")}
'p.is_obfuscated' { $params = @(,"")}
'p.is_preferred' { $params = @(,"")}
'p.is_snubbed' { $params = @(,"")}
'p.is_unwanted' { $params = @(,"")}
'p.multicall' { $params = @(,"")}
'p.options_str' { $params = @(,"")}
'p.peer_rate' { $params = @(,"")}
'p.peer_total' { $params = @(,"")}
'p.port' { $params = @(,"")}
'p.snubbed' { $params = @(,"")}
'p.snubbed.set' { $params = @(,"")}
'p.up_rate' { $params = @(,"")}
'p.up_total' { $params = @(,"")}
'pieces.hash.on_completion' { $params = @(,"")}
'pieces.hash.on_completion.set' { $params = @(,"")}
'pieces.hash.queue_size' { $params = @(,"")}
'pieces.memory.block_count' { $params = @(,"")}
'pieces.memory.current' { $params = @(,"")}
'pieces.memory.max' { $params = @(,"")}
'pieces.memory.max.set' { $params = @(,"")}
'pieces.memory.sync_queue' { $params = @(,"")}
'pieces.preload.min_rate' { $params = @(,"")}
'pieces.preload.min_rate.set' { $params = @(,"")}
'pieces.preload.min_size' { $params = @(,"")}
'pieces.preload.min_size.set' { $params = @(,"")}
'pieces.preload.type' { $params = @(,"")}
'pieces.preload.type.set' { $params = @(,"")}
'pieces.stats.total_size' { $params = @(,"")}
'pieces.stats_not_preloaded' { $params = @(,"")}
'pieces.stats_preloaded' { $params = @(,"")}
'pieces.sync.always_safe' { $params = @(,"")}
'pieces.sync.always_safe.set' { $params = @(,"")}
'pieces.sync.queue_size' { $params = @(,"")}
'pieces.sync.safe_free_diskspace' { $params = @(,"")}
'pieces.sync.timeout' { $params = @(,"")}
'pieces.sync.timeout.set' { $params = @(,"")}
'pieces.sync.timeout_safe' { $params = @(,"")}
'pieces.sync.timeout_safe.set' { $params = @(,"")}
'port_random' { $params = @(,"")}
'port_range' { $params = @(,"")}
'print' { $params = @(,"")}
'protocol.choke_heuristics.down.leech' { $params = @(,"")}
'protocol.choke_heuristics.down.leech.set' { $params = @(,"")}
'protocol.choke_heuristics.down.seed' { $params = @(,"")}
'protocol.choke_heuristics.down.seed.set' { $params = @(,"")}
'protocol.choke_heuristics.up.leech' { $params = @(,"")}
'protocol.choke_heuristics.up.leech.set' { $params = @(,"")}
'protocol.choke_heuristics.up.seed' { $params = @(,"")}
'protocol.choke_heuristics.up.seed.set' { $params = @(,"")}
'protocol.connection.leech' { $params = @(,"")}
'protocol.connection.leech.set' { $params = @(,"")}
'protocol.connection.seed' { $params = @(,"")}
'protocol.connection.seed.set' { $params = @(,"")}
'protocol.encryption.set' { $params = @(,"")}
'protocol.pex' { $params = @(,"")}
'protocol.pex.set' { $params = @(,"")}
'proxy_address' { $params = @(,"")}
'ratio.disable' { $params = @(,"")}
'ratio.enable' { $params = @(,"")}
'ratio.max' { $params = @(,"")}
'ratio.max.set' { $params = @(,"")}
'ratio.min' { $params = @(,"")}
'ratio.min.set' { $params = @(,"")}
'ratio.upload' { $params = @(,"")}
'ratio.upload.set' { $params = @(,"")}
'remove_untied' { $params = @(,"")}
'scgi_local' { $params = @(,"")}
'scgi_port' { $params = @(,"")}
'schedule' { $params = @(,"")}
'schedule2' { $params = @(,"")}
'schedule_remove' { $params = @(,"")}
'schedule_remove2' { $params = @(,"")}
'scheduler.max_active' { $params = @(,"")}
'scheduler.max_active.set' { $params = @(,"")}
'scheduler.simple.added' { $params = @(,"")}
'scheduler.simple.removed' { $params = @(,"")}
'scheduler.simple.update' { $params = @(,"")}
'session' { $params = @(,"")}
'session.name' { $params = @(,"")}
'session.name.set' { $params = @(,"")}
'session.on_completion' { $params = @(,"")}
'session.on_completion.set' { $params = @(,"")}
'session.path' { $params = @(,"")}
'session.path.set' { $params = @(,"")}
'session.save' { $params = @(,"")}
'session.use_lock' { $params = @(,"")}
'session.use_lock.set' { $params = @(,"")}
'start_tied' { $params = @(,"")}
'stop_untied' { $params = @(,"")}
'strings.choke_heuristics' { $params = @(,"")}
'strings.choke_heuristics.download' { $params = @(,"")}
'strings.choke_heuristics.upload' { $params = @(,"")}
'strings.connection_type' { $params = @(,"")}
'strings.encryption' { $params = @(,"")}
'strings.ip_filter' { $params = @(,"")}
'strings.ip_tos' { $params = @(,"")}
'strings.log_group' { $params = @(,"")}
'strings.tracker_event' { $params = @(,"")}
'strings.tracker_mode' { $params = @(,"")}
'system.api_version' { $params = @(,"")}
'system.client_version' { $params = @(,"")}
'system.cwd' { $params = @(,"")}
'system.cwd.set' { $params = @(,"")}
'system.file.allocate' { $params = @(,"")}
'system.file.allocate.set' { $params = @(,"")}
'system.file.max_size' { $params = @(,"")}
'system.file.max_size.set' { $params = @(,"")}
'system.file.split_size' { $params = @(,"")}
'system.file.split_size.set' { $params = @(,"")}
'system.file.split_suffix' { $params = @(,"")}
'system.file.split_suffix.set' { $params = @(,"")}
'system.file_status_cache.prune' { $params = @(,"")}
'system.file_status_cache.size' { $params = @(,"")}
'system.files.closed_counter' { $params = @(,"")}
'system.files.failed_counter' { $params = @(,"")}
'system.files.opened_counter' { $params = @(,"")}
'system.hostname' { $params = @(,"")}
'system.library_version' { $params = @(,"")}
'system.pid' { $params = @(,"")}
'system.time' { $params = @(,"")}
'system.time_seconds' { $params = @(,"")}
'system.time_usec' { $params = @(,"")}
'system.umask.set' { $params = @(,"")}
't.activity_time_last' { $params = @(,"")}
't.activity_time_next' { $params = @(,"")}
't.can_scrape' { $params = @(,"")}
't.disable' { $params = @(,"")}
't.enable' { $params = @(,"")}
't.failed_counter' { $params = @(,"")}
't.failed_time_last' { $params = @(,"")}
't.failed_time_next' { $params = @(,"")}
't.group' { $params = @(,"")}
't.id' { $params = @(,"")}
't.is_busy' { $params = @(,"")}
't.is_enabled' { $params = @(,"")}
't.is_enabled.set' { $params = @(,"")}
't.is_extra_tracker' { $params = @(,"")}
't.is_open' { $params = @(,"")}
't.is_usable' { $params = @(,"")}
't.latest_event' { $params = @(,"")}
't.latest_new_peers' { $params = @(,"")}
't.latest_sum_peers' { $params = @(,"")}
't.min_interval' { $params = @(,"")}
't.multicall' { $params = @(,"")}
't.normal_interval' { $params = @(,"")}
't.scrape_complete' { $params = @(,"")}
't.scrape_counter' { $params = @(,"")}
't.scrape_downloaded' { $params = @(,"")}
't.scrape_incomplete' { $params = @(,"")}
't.scrape_time_last' { $params = @(,"")}
't.success_counter' { $params = @(,"")}
't.success_time_last' { $params = @(,"")}
't.success_time_next' { $params = @(,"")}
't.type' { $params = @(,"")}
't.url' { $params = @(,"")}
'throttle.down' { $params = @(,"")}
'throttle.down.max' { $params = @(,"")}
'throttle.down.rate' { $params = @(,"")}
'throttle.global_down.max_rate' { $params = @(,"")}
'throttle.global_down.max_rate.set' { $params = @(,"")}
'throttle.global_down.max_rate.set_kb' { $params = @(,"")}
'throttle.global_down.rate' { $params = @(,"")}
'throttle.global_down.total' { $params = @(,"")}
'throttle.global_up.max_rate' { $params = @(,"")}
'throttle.global_up.max_rate.set' { $params = @(,"")}
'throttle.global_up.max_rate.set_kb' { $params = @(,"")}
'throttle.global_up.rate' { $params = @(,"")}
'throttle.global_up.total' { $params = @(,"")}
'throttle.ip' { $params = @(,"")}
'throttle.max_downloads' { $params = @(,"")}
'throttle.max_downloads.div' { $params = @(,"")}
'throttle.max_downloads.div._val' { $params = @(,"")}
'throttle.max_downloads.div._val.set' { $params = @(,"")}
'throttle.max_downloads.div.set' { $params = @(,"")}
'throttle.max_downloads.global' { $params = @(,"")}
'throttle.max_downloads.global._val' { $params = @(,"")}
'throttle.max_downloads.global._val.set' { $params = @(,"")}
'throttle.max_downloads.global.set' { $params = @(,"")}
'throttle.max_downloads.set' { $params = @(,"")}
'throttle.max_peers.normal' { $params = @(,"")}
'throttle.max_peers.normal.set' { $params = @(,"")}
'throttle.max_peers.seed' { $params = @(,"")}
'throttle.max_peers.seed.set' { $params = @(,"")}
'throttle.max_uploads' { $params = @(,"")}
'throttle.max_uploads.div' { $params = @(,"")}
'throttle.max_uploads.div._val' { $params = @(,"")}
'throttle.max_uploads.div._val.set' { $params = @(,"")}
'throttle.max_uploads.div.set' { $params = @(,"")}
'throttle.max_uploads.global' { $params = @(,"")}
'throttle.max_uploads.global._val' { $params = @(,"")}
'throttle.max_uploads.global._val.set' { $params = @(,"")}
'throttle.max_uploads.global.set' { $params = @(,"")}
'throttle.max_uploads.set' { $params = @(,"")}
'throttle.min_downloads' { $params = @(,"")}
'throttle.min_downloads.set' { $params = @(,"")}
'throttle.min_peers.normal' { $params = @(,"")}
'throttle.min_peers.normal.set' { $params = @(,"")}
'throttle.min_peers.seed' { $params = @(,"")}
'throttle.min_peers.seed.set' { $params = @(,"")}
'throttle.min_uploads' { $params = @(,"")}
'throttle.min_uploads.set' { $params = @(,"")}
'throttle.unchoked_downloads' { $params = @(,"")}
'throttle.unchoked_uploads' { $params = @(,"")}
'throttle.up' { $params = @(,"")}
'throttle.up.max' { $params = @(,"")}
'throttle.up.rate' { $params = @(,"")}
'to_date' { $params = @(,"")}
'to_elapsed_time' { $params = @(,"")}
'to_gm_date' { $params = @(,"")}
'to_gm_time' { $params = @(,"")}
'to_kb' { $params = @(,"")}
'to_mb' { $params = @(,"")}
'to_throttle' { $params = @(,"")}
'to_time' { $params = @(,"")}
'to_xb' { $params = @(,"")}
'trackers.disable' { $params = @(,"")}
'trackers.enable' { $params = @(,"")}
'trackers.numwant' { $params = @(,"")}
'trackers.numwant.set' { $params = @(,"")}
'trackers.use_udp' { $params = @(,"")}
'trackers.use_udp.set' { $params = @(,"")}
'try_import' { $params = @(,"")}
'ui.current_view.set' { $params = @(,"")}
'ui.unfocus_download' { $params = @(,"")}
'upload_rate' { $params = @(,"")}
'view.add' { $params = @(,"")}
'view.event_added' { $params = @(,"")}
'view.event_removed' { $params = @(,"")}
'view.filter' { $params = @(,"")}
'view.filter_all' { $params = @(,"")}
'view.filter_download' { $params = @(,"")}
'view.filter_on' { $params = @(,"")}
'view.list' { $params = @(,"")}
'view.persistent' { $params = @(,"")}
'view.set' { $params = @(,"")}
'view.set_not_visible' { $params = @(,"")}
'view.set_visible' { $params = @(,"")}
'view.size' { $params = @(,"")}
'view.size_not_visible' { $params = @(,"")}
'view.sort' { $params = @(,"")}
'view.sort_current' { $params = @(,"")}
'view.sort_new' { $params = @(,"")}
'group.rat_0.ratio.enable' { $params = @(,"")}
'group.rat_0.ratio.disable' { $params = @(,"")}
'group.rat_0.ratio.command' { $params = @(,"")}
'group2.rat_0.view' { $params = @(,"")}
'group2.rat_0.view.set' { $params = @(,"")}
'group2.rat_0.ratio.min' { $params = @(,"")}
'group2.rat_0.ratio.min.set' { $params = @(,"")}
'group2.rat_0.ratio.max' { $params = @(,"")}
'group2.rat_0.ratio.max.set' { $params = @(,"")}
'group2.rat_0.ratio.upload' { $params = @(,"")}
'group2.rat_0.ratio.upload.set' { $params = @(,"")}
'group.rat_0.view' { $params = @(,"")}
'group.rat_0.view.set' { $params = @(,"")}
'group.rat_0.ratio.min' { $params = @(,"")}
'group.rat_0.ratio.min.set' { $params = @(,"")}
'group.rat_0.ratio.max' { $params = @(,"")}
'group.rat_0.ratio.max.set' { $params = @(,"")}
'group.rat_0.ratio.upload' { $params = @(,"")}
'group.rat_0.ratio.upload.set' { $params = @(,"")}
'group.rat_1.ratio.enable' { $params = @(,"")}
'group.rat_1.ratio.disable' { $params = @(,"")}
'group.rat_1.ratio.command' { $params = @(,"")}
'group2.rat_1.view' { $params = @(,"")}
'group2.rat_1.view.set' { $params = @(,"")}
'group2.rat_1.ratio.min' { $params = @(,"")}
'group2.rat_1.ratio.min.set' { $params = @(,"")}
'group2.rat_1.ratio.max' { $params = @(,"")}
'group2.rat_1.ratio.max.set' { $params = @(,"")}
'group2.rat_1.ratio.upload' { $params = @(,"")}
'group2.rat_1.ratio.upload.set' { $params = @(,"")}
'group.rat_1.view' { $params = @(,"")}
'group.rat_1.view.set' { $params = @(,"")}
'group.rat_1.ratio.min' { $params = @(,"")}
'group.rat_1.ratio.min.set' { $params = @(,"")}
'group.rat_1.ratio.max' { $params = @(,"")}
'group.rat_1.ratio.max.set' { $params = @(,"")}
'group.rat_1.ratio.upload' { $params = @(,"")}
'group.rat_1.ratio.upload.set' { $params = @(,"")}
'group.rat_2.ratio.enable' { $params = @(,"")}
'group.rat_2.ratio.disable' { $params = @(,"")}
'group.rat_2.ratio.command' { $params = @(,"")}
'group2.rat_2.view' { $params = @(,"")}
'group2.rat_2.view.set' { $params = @(,"")}
'group2.rat_2.ratio.min' { $params = @(,"")}
'group2.rat_2.ratio.min.set' { $params = @(,"")}
'group2.rat_2.ratio.max' { $params = @(,"")}
'group2.rat_2.ratio.max.set' { $params = @(,"")}
'group2.rat_2.ratio.upload' { $params = @(,"")}
'group2.rat_2.ratio.upload.set' { $params = @(,"")}
'group.rat_2.view' { $params = @(,"")}
'group.rat_2.view.set' { $params = @(,"")}
'group.rat_2.ratio.min' { $params = @(,"")}
'group.rat_2.ratio.min.set' { $params = @(,"")}
'group.rat_2.ratio.max' { $params = @(,"")}
'group.rat_2.ratio.max.set' { $params = @(,"")}
'group.rat_2.ratio.upload' { $params = @(,"")}
'group.rat_2.ratio.upload.set' { $params = @(,"")}
'group.rat_3.ratio.enable' { $params = @(,"")}
'group.rat_3.ratio.disable' { $params = @(,"")}
'group.rat_3.ratio.command' { $params = @(,"")}
'group2.rat_3.view' { $params = @(,"")}
'group2.rat_3.view.set' { $params = @(,"")}
'group2.rat_3.ratio.min' { $params = @(,"")}
'group2.rat_3.ratio.min.set' { $params = @(,"")}
'group2.rat_3.ratio.max' { $params = @(,"")}
'group2.rat_3.ratio.max.set' { $params = @(,"")}
'group2.rat_3.ratio.upload' { $params = @(,"")}
'group2.rat_3.ratio.upload.set' { $params = @(,"")}
'group.rat_3.view' { $params = @(,"")}
'group.rat_3.view.set' { $params = @(,"")}
'group.rat_3.ratio.min' { $params = @(,"")}
'group.rat_3.ratio.min.set' { $params = @(,"")}
'group.rat_3.ratio.max' { $params = @(,"")}
'group.rat_3.ratio.max.set' { $params = @(,"")}
'group.rat_3.ratio.upload' { $params = @(,"")}
'group.rat_3.ratio.upload.set' { $params = @(,"")}
'group.rat_4.ratio.enable' { $params = @(,"")}
'group.rat_4.ratio.disable' { $params = @(,"")}
'group.rat_4.ratio.command' { $params = @(,"")}
'group2.rat_4.view' { $params = @(,"")}
'group2.rat_4.view.set' { $params = @(,"")}
'group2.rat_4.ratio.min' { $params = @(,"")}
'group2.rat_4.ratio.min.set' { $params = @(,"")}
'group2.rat_4.ratio.max' { $params = @(,"")}
'group2.rat_4.ratio.max.set' { $params = @(,"")}
'group2.rat_4.ratio.upload' { $params = @(,"")}
'group2.rat_4.ratio.upload.set' { $params = @(,"")}
'group.rat_4.view' { $params = @(,"")}
'group.rat_4.view.set' { $params = @(,"")}
'group.rat_4.ratio.min' { $params = @(,"")}
'group.rat_4.ratio.min.set' { $params = @(,"")}
'group.rat_4.ratio.max' { $params = @(,"")}
'group.rat_4.ratio.max.set' { $params = @(,"")}
'group.rat_4.ratio.upload' { $params = @(,"")}
'group.rat_4.ratio.upload.set' { $params = @(,"")}
'group.rat_5.ratio.enable' { $params = @(,"")}
'group.rat_5.ratio.disable' { $params = @(,"")}
'group.rat_5.ratio.command' { $params = @(,"")}
'group2.rat_5.view' { $params = @(,"")}
'group2.rat_5.view.set' { $params = @(,"")}
'group2.rat_5.ratio.min' { $params = @(,"")}
'group2.rat_5.ratio.min.set' { $params = @(,"")}
'group2.rat_5.ratio.max' { $params = @(,"")}
'group2.rat_5.ratio.max.set' { $params = @(,"")}
'group2.rat_5.ratio.upload' { $params = @(,"")}
'group2.rat_5.ratio.upload.set' { $params = @(,"")}
'group.rat_5.view' { $params = @(,"")}
'group.rat_5.view.set' { $params = @(,"")}
'group.rat_5.ratio.min' { $params = @(,"")}
'group.rat_5.ratio.min.set' { $params = @(,"")}
'group.rat_5.ratio.max' { $params = @(,"")}
'group.rat_5.ratio.max.set' { $params = @(,"")}
'group.rat_5.ratio.upload' { $params = @(,"")}
'group.rat_5.ratio.upload.set' { $params = @(,"")}
'group.rat_6.ratio.enable' { $params = @(,"")}
'group.rat_6.ratio.disable' { $params = @(,"")}
'group.rat_6.ratio.command' { $params = @(,"")}
'group2.rat_6.view' { $params = @(,"")}
'group2.rat_6.view.set' { $params = @(,"")}
'group2.rat_6.ratio.min' { $params = @(,"")}
'group2.rat_6.ratio.min.set' { $params = @(,"")}
'group2.rat_6.ratio.max' { $params = @(,"")}
'group2.rat_6.ratio.max.set' { $params = @(,"")}
'group2.rat_6.ratio.upload' { $params = @(,"")}
'group2.rat_6.ratio.upload.set' { $params = @(,"")}
'group.rat_6.view' { $params = @(,"")}
'group.rat_6.view.set' { $params = @(,"")}
'group.rat_6.ratio.min' { $params = @(,"")}
'group.rat_6.ratio.min.set' { $params = @(,"")}
'group.rat_6.ratio.max' { $params = @(,"")}
'group.rat_6.ratio.max.set' { $params = @(,"")}
'group.rat_6.ratio.upload' { $params = @(,"")}
'group.rat_6.ratio.upload.set' { $params = @(,"")}
'group.rat_7.ratio.enable' { $params = @(,"")}
'group.rat_7.ratio.disable' { $params = @(,"")}
'group.rat_7.ratio.command' { $params = @(,"")}
'group2.rat_7.view' { $params = @(,"")}
'group2.rat_7.view.set' { $params = @(,"")}
'group2.rat_7.ratio.min' { $params = @(,"")}
'group2.rat_7.ratio.min.set' { $params = @(,"")}
'group2.rat_7.ratio.max' { $params = @(,"")}
'group2.rat_7.ratio.max.set' { $params = @(,"")}
'group2.rat_7.ratio.upload' { $params = @(,"")}
'group2.rat_7.ratio.upload.set' { $params = @(,"")}
'group.rat_7.view' { $params = @(,"")}
'group.rat_7.view.set' { $params = @(,"")}
'group.rat_7.ratio.min' { $params = @(,"")}
'group.rat_7.ratio.min.set' { $params = @(,"")}
'group.rat_7.ratio.max' { $params = @(,"")}
'group.rat_7.ratio.max.set' { $params = @(,"")}
'group.rat_7.ratio.upload' { $params = @(,"")}
'group.rat_7.ratio.upload.set' { $params = @(,"")}
}
# New RPCMethod
#$method = 'wp.getPostTypes'
$method = 'port_range'
$params = @(0,'main')
$body = New-RPCMethod -MethodName $method -Params $params
Invoke-RPCMethod -RpcServerUri "$SeedboxUrl/rutorrent/plugins/httprpc/action.php" -RequestBody $body -Credential $credentials