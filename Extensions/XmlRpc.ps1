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



function New-RPCMethod
{
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


function Invoke-RPCMethod
{
    
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
    param(
    [uri]$Uri,
    [string]$Body,
    [System.Management.Automation.CredentialAttribute()]
    $Credential
    )
    $xmlResponse = Invoke-RestMethod -Uri $Uri -Method Post -ContentType "text/xml" -Body $Body -Credential $Credential
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



function ConvertTo-RPCXmlObject
{
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



function ConvertFrom-RPCXmlObject
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



function XmlRpcType(){
    <#
    XmlRpcRequest [-Url] <[String]> [-MethodName] <[String]> [-Params] <[Object]>
    Return Xml-Rpc methodResponse
    XmlRpcMethodCall [-Name] <[String]> [-Params] <[Object]>
    Return Xml-Rpc methodCall
    XmlRpcType [-Value] <[Object]>
    Return Xml-Rpc value
    #>
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
