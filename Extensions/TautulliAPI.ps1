<#
PlexyPY commands


.links
Tautulli
https://github.com/JonnyWong16/plexpy/blob/master/API.md
https://github.com/Tautulli/Tautulli-Wiki/wiki/Tautulli-API-Reference

.Commands:
     get_apikey
     get_settings
     get_recently_added
     get_notification_log
     get_plays_by_stream_resolution
     get_plays_by_source_resolution
     get_plays_by_top_10_platforms
     get_plays_by_top_10_users
     get_plays_by_stream_type
     get_plays_per_month
     get_library_names
     get_geoip_lookup
     get_libraries_table
     get_plays_by_hourofday
     get_notifier_parameters
     get_activity
     get_pms_token
     get_whois_lookup
     get_synced_items
     get_server_list
     get_plex_log
     get_stream_type_by_top_10_platforms
     get_server_identity
     get_logs
     get_stream_type_by_top_10_users
     get_old_rating_keys
     get_new_rating_keys
     get_library_user_stats
     get_plays_by_dayofweek
     get_library_media_info
     get_date_formats
     get_libraries
     get_user_names
     get_home_stats
     get_server_id
     get_users
     get_user_watch_time_stats
     get_pms_update
     get_server_friendly_name
     get_user_logins
     get_history
     get_server_pref
     get_plays_by_date
     get_library_watch_time_stats
     get_notifiers
     get_servers_info
     get_library
     get_metadata
     get_user
     get_users_table
     get_user_ips
     get_user_player_stats



     set_mobile_device_config
     set_notifier_config








     delete_user
     undelete_user

     delete_all_library_history
     docs_md

     delete_temp_sessions

     register_device
     restart
     terminate_session
     download_config

     edit_library
     backup_db

     delete_media_info_cache
     install_geoip_db

     update_metadata_details

     update_check
     delete_lookup_info


     search

     delete_mobile_device
     download_database

     backup_config

     notify

     notify_recently_added
     import_database
     pms_image_proxy
     delete_all_user_history

     delete_notification_log

     refresh_libraries_list

     arnold
     delete_imgur_poster

     uninstall_geoip_db

     delete_login_log

     delete_image_cache
     delete_cache

     download_plex_log
     add_notifier_config

     docs
     delete_library
     update
     download_log

     sql
     undelete_library

     delete_notifier

     edit_user

     refresh_users_list

.example
http://ip:port + HTTP_ROOT + /api/v2?apikey=$apikey&cmd=$command

.sample
http://localhost:8181/api/v2?apikey=16545769bf6c4a10b8cbdd5498854ba6&cmd=get_activity
#>

Function Get-TautulliAPIKey{
    [CmdletBinding()]
    param(
        [string] $URL = "http://localhost:8181",
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]$credentials
    )

    $Username = $credentials.GetNetworkCredential().UserName 
    $password = $credentials.GetNetworkCredential().Password

    $TautulliArgs = @{Headers = @{}
                    URI = ($URL + '/api/v2?cmd=get_apikey' + '&username=' + $UserName + '&password=' + $password)
                    Method = "Get"
                }

    try {
        $request = Invoke-RestMethod @TautulliArgs -UseBasicParsing -Verbose:$VerbosePreference -ErrorAction Stop
        $request.response.data
    }
    catch {
        Write-Error -ErrorRecord $_
    }

}

Function Get-TautulliUsers{
    [CmdletBinding()]
    param(
        [string] $URL = "http://localhost:8181",
        [string] $apiKey,
        [string] $Filter
    )
    Begin{
        ## Get the name of this function
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        #use global API or check if specified APi is not null
        If($Global:TautulliAPIKey){
            $apiKey = $Global:TautulliAPIKey
        }
        Elseif($null -eq $apiKey){
            Throw "-Api parameter is mandatory"
        }

        $TautulliArgs = @{Headers = @{}
                    URI = ($URL + '/api/v2?apikey=' + $apiKey + "&cmd=get_users")
                    Method = "Get"
                }
    }
    Process{
        try {
            $request = Invoke-RestMethod @TautulliArgs -UseBasicParsing -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
    End{
        If($Filter){
            $request.response.data | Where username -eq $filter
        }
        Else{
            $request.response.data
        }
    }
}

Function Get-TautulliUser{
    [CmdletBinding()]
    param(
        [string] $URL = "http://localhost:8181",
        [string] $apiKey,
        [string] $Username,
        [string] $UserId
    )
    Begin{
        ## Get the name of this function
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        #use global API or check if specified APi is not null
        If($Global:TautulliAPIKey){
            $apiKey = $Global:TautulliAPIKey
        }
        Elseif($null -eq $apiKey){
            Throw "-Api parameter is mandatory"
        }        
    }
    Process{
        If($Username){
            $UserId = Get-TautulliUsers -Filter $Username | Select -ExpandProperty user_id
        }

        $TautulliArgs = @{Headers = @{}
                    URI = ($URL + '/api/v2?apikey=' + $apiKey + "&cmd=get_user" + "&user_id=" + $UserId)
                    Method = "Get"
                }

        try {
            $request = Invoke-RestMethod @TautulliArgs -UseBasicParsing -Verbose:$VerbosePreference -ErrorAction Stop
            $request.response.data
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
    End{
       
    }
}


Function Get-TautulliActivity{
    [CmdletBinding()]
    param(
        [string] $URL = "http://localhost:8181",
        [string] $apiKey,
        [switch] $Passthru
    )
    Begin{
        ## Get the name of this function
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        #use global API or check if specified APi is not null
        If($Global:TautulliAPIKey){
            $apiKey = $Global:TautulliAPIKey
        }
        Elseif($null -eq $apiKey){
            Throw "-Api parameter is mandatory"
        }

        $TautulliArgs = @{Headers = @{}
                    URI = ($URL + '/api/v2?apikey=' + $apiKey + "&cmd=get_activity")
                    Method = "Get"
                }
    }
    Process{
        try {
            $request = Invoke-RestMethod @TautulliArgs -UseBasicParsing -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
    End{
        If($Passthru){
            $request.response.data.sessions | Select @{Name='User';Expression={$_.user}},@{Name='Title';Expression={$_.full_title}}
        }
        Else{
            If ($request.response.data.stream_count -ge 1){
                Return $True
            }
            Else{
                Return $False
            }
        }
    }
}


Function Get-TautulliSettings{
    [CmdletBinding()]
    param(
        [string] $URL = "http://localhost:8181",
        [ValidateSet('General','Advanced','Cloudinary','Monitoring','Newsletter','PMS')]
        [string] $Section,
        [string] $apiKey
    )

    Begin{
        #use global API or check if specified APi is not null
        If($Global:TautulliAPIKey){
            $apiKey = $Global:TautulliAPIKey
        }
        Elseif($null -eq $apiKey){
            Throw "-Api parameter is mandatory"
        }

        $TautulliArgs = @{Headers = @{}
                    URI = ($URL + '/api/v2?apikey=' + $apiKey + "&cmd=get_settings")
                    Method = "Get"
                }
    }
    Process{
        try {
            $request = Invoke-RestMethod @TautulliArgs -UseBasicParsing -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
    End{
        If($null -ne $request){
            If($Section){
                $request.response.data.$Section
            }Else{
                $request.response.data
            }
        }
    }
}

Function Get-TautulliHomeStats{
    [CmdletBinding()]
    param(
        [string] $URL = "http://localhost:8181",
        [ValidateSet('Most Watched Movie',
            'Most Popular Movies',
            'Most Watched TV Shows',
            'Most Popular TV Shows',
            'Most Played Artists',
            'Most Popular Artists',
            'Recently Watched',
            'Most Active Libraries',
            'Most Active Users',
            'Most Active Platforms',
            'Most Concurrent Streams')]
        [string] $Section,
        [string] $apiKey
    )

    Begin{
        #use global API or check if specified APi is not null
        If($Global:TautulliAPIKey){
            $apiKey = $Global:TautulliAPIKey
        }
        Elseif($null -eq $apiKey){
            Throw "-Api parameter is mandatory"
        }

        
        switch($Section){
            'Most Watched Movie' {$statid = 'top_movies'}
            'Most Popular Movies' {$statid = 'popular_movies'}
            'Most Watched TV Shows' {$statid = 'top_tv'}
            'Most Popular TV Shows' {$statid = 'popular_tv'}
            'Most Played Artists' {$statid = 'top_music'}
            'Most Popular Artists' {$statid = 'popular_music '}
            'Recently Watched' {$statid = 'last_watched'}
            'Most Active Libraries' {$statid = 'top_libraries'}
            'Most Active Users' {$statid = 'top_users'}
            'Most Active Platforms' {$statid = 'top_platforms'}
            'Most Concurrent Streams' {$statid = 'most_concurrent'}
        }                                                           
        
        $TautulliArgs = @{Headers = @{}
                    URI = ($URL + '/api/v2?apikey=' + $apiKey + "&cmd=get_home_stats")
                    Method = "Get"
                }                                                                                                            
    }
    Process{
        try {
            $request = Invoke-RestMethod @TautulliArgs -UseBasicParsing -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
    End{

        If($null -ne $request){
            If($Section){
                $request.response.data | Where stat_id -eq $statid | Select -ExpandProperty rows
            }Else{
                $request.response.data
            }
        }
    }
}

Function Get-TautulliLibraries{
    [CmdletBinding()]
    param(
        [string] $URL = "http://localhost:8181",
        [string] $apiKey,
        [string] $Filter
    )
    Begin{
        ## Get the name of this function
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        #use global API or check if specified APi is not null
        If($Global:TautulliAPIKey){
            $apiKey = $Global:TautulliAPIKey
        }
        Elseif($null -eq $apiKey){
            Throw "-Api parameter is mandatory"
        }

        $TautulliArgs = @{Headers = @{}
                    URI = ($URL + '/api/v2?apikey=' + $apiKey + "&cmd=get_library_names")
                    Method = "Get"
                }
    }
    Process{
        try {
            $request = Invoke-RestMethod @TautulliArgs -UseBasicParsing -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
    End{
        If($Filter){
            $request.response.data | Where section_name -like "*$filter*"
        }
        Else{
            $request.response.data
        }
    }
}

Function Get-TautulliLIbraryWatchTimeStats{
    [CmdletBinding()]
    param(
        [string] $URL = "http://localhost:8181",
        [int32] $SectionId,
        [ValidateRange(1,365)]
        [int32] $FromDays,
        [string] $apiKey
    )

    Begin{
        #use global API or check if specified APi is not null
        If($Global:TautulliAPIKey){
            $apiKey = $Global:TautulliAPIKey
        }
        Elseif($null -eq $apiKey){
            Throw "-Api parameter is mandatory"
        }
       
        $param = '&section_id=' + $SectionId

        If($FromDays){
            $param += '&query_days=' + $FromDays
        }

        $TautulliArgs = @{Headers = @{}
                    URI = ($URL + '/api/v2?apikey=' + $apiKey + "&cmd=get_library_watch_time_stats" + $param)
                    Method = "Get"
                }
    }
    Process{
        try {
            $request = Invoke-RestMethod @TautulliArgs -UseBasicParsing -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
           # Write-Error -ErrorRecord $_
        }
    }
    End{
        If($null -ne $request){
            $request.response.data
        }
    }
}

Function Get-TautulliUserStats{
    [CmdletBinding()]
    param(
        [string] $URL = "http://localhost:8181",
        [string] $UserName,
        [int32] $UserId,
        [ValidateSet(
            'User Player',
            'User Library',
            'User Watch Time')]
        [string] $Category,
        [int32] $SectionId,
        [ValidateRange(1,365)]
        [int32] $FromDays,
        [string] $apiKey = $global:TautulliAPIKey
    )

    Begin{
        #use global API or check if specified APi is not null
        If($Global:TautulliAPIKey){
            $apiKey = $Global:TautulliAPIKey
        }
        Elseif($null -eq $apiKey){
            Throw "-Api parameter is mandatory"
        }

        If($UserName){
            $UserId = Get-TautulliUsers -Filter $UserName | Select -ExpandProperty user_id
        }

        
        Switch($Category){
            'User Player' {$apicommand = 'get_user_player_stats'; $param = '&user_id=' + $UserId}
            'User Library' {$apicommand = 'get_library_user_stats';$param = '&section_id=' + $SectionId}
            'User Watch Time' {$apicommand = 'get_user_watch_time_stats'; $param = '&user_id=' + $UserId}
            default {$apicommand = 'get_user'; $param = '&user_id=' + $UserId}
        }
        
        If($FromDays){
            $param += '&query_days=' + $FromDays
        }

        $TautulliArgs = @{Headers = @{}
                    URI = ($URL + '/api/v2?apikey=' + $apiKey + "&cmd=" + $apicommand + $param)
                    Method = "Get"
                }
    }
    Process{
        try {
            $request = Invoke-RestMethod @TautulliArgs -UseBasicParsing -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
           # Write-Error -ErrorRecord $_
        }
    }
    End{
        If($null -ne $request){
            $request.response.data
        }
    }
}



Function Get-TautulliTopLibraryStats{
    [CmdletBinding()]
    param(
        [string] $URL = "http://localhost:8181",
        [ValidateSet(
            'User Plays',
            'User Streams',
            'Platform Streams')]
        [string] $Category,
        [string] $apiKey = $global:TautulliAPIKey
    )

    Begin{
        #use global API or check if specified APi is not null
        If($Global:TautulliAPIKey){
            $apiKey = $Global:TautulliAPIKey
        }
        Elseif($null -eq $apiKey){
            Throw "-Api parameter is mandatory"
        }

        switch($Category){
            'User Plays' {$apicommand = 'get_plays_by_top_10_users'}
            'Platform Streams' {$apicommand = 'get_stream_type_by_top_10_platforms'}
            'User Streams' {$apicommand = 'get_stream_type_by_top_10_users'}
        }

        $TautulliArgs = @{Headers = @{}
                    URI = ($URL + '/api/v2?apikey=' + $apiKey + "&cmd=" + $apicommand)
                    Method = "Get"
                }
    }
    Process{
        try {
            $request = Invoke-RestMethod @TautulliArgs -UseBasicParsing -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
           # Write-Error -ErrorRecord $_
        }
    }
    End{

        If($null -ne $request){
            $request.response.data.categories
        }
    }
}



Function Get-TautulliInfo{
    [CmdletBinding()]
    param(
        [string][ValidateSet(
        
        "get_recently_added",
        "get_notification_log",
        
        "get_plays_by_stream_type",
        "get_plays_per_month",
        
        "get_geoip_lookup",
        "get_libraries_table",
        "get_plays_by_hourofday",
        "get_notifier_parameters",
        
        "get_pms_token",
        "get_whois_lookup",
        "get_synced_items",
        "get_server_list",
        "get_plex_log",
        
        "get_server_identity",
        "get_logs",
       
        "get_old_rating_keys",
        "get_new_rating_keys",
        
        "get_plays_by_dayofweek",
        "get_library_media_info",
        "get_date_formats",
        "get_libraries",

        "get_server_id",
        "get_pms_update",
        "get_server_friendly_name",
        "get_history",
        "get_server_pref",
        "get_plays_by_date",
        
        "get_notifiers",
        "get_servers_info",
        "get_library",
        "get_metadata",

        "get_users_table",

        "get_user_names",
        "get_user_logins",
        "get_user_ips")]
        $command,
    [string] $URL = "http://localhost:8181",
    [string] $apiKey,
    [switch]$Passthru
    )
    Begin{
        #use global API or check if specified APi is not null
        If($Global:TautulliAPIKey){
            $apiKey = $Global:TautulliAPIKey
        }
        Elseif($null -eq $apiKey){
            Throw "-Api parameter is mandatory"
        }

        $resource = "$URL/api/v2?apikey=$apiKey"
    }
    
    Process{
        try {
            $request = Invoke-RestMethod -Method Get -Uri ("$resource" + "&cmd=" + "$command") -UseBasicParsing -Verbose:$VerbosePreference
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
    End{
        $request.response.data
    }
}

<#

$command = 'get_apikey'
$command = 'get_settings'
$command = 'get_recently_added'
$command = 'get_notification_log'
$command = 'get_plays_by_stream_resolution'
$command = 'get_plays_by_source_resolution'
$command = 'get_plays_by_top_10_platforms'
$command = 'get_plays_by_top_10_users'
$command = 'get_plays_by_stream_type'
$command = 'get_plays_per_month'
$command = 'get_library_names'
$command = 'get_geoip_lookup'
$command = 'get_libraries_table'
$command = 'get_plays_by_hourofday'
$command = 'get_notifier_parameters'
$command = 'get_activity'
$command = 'get_pms_token'
$command = 'get_whois_lookup'
$command = 'get_synced_items'
$command = 'get_server_list'
$command = 'get_plex_log'
$command = 'get_stream_type_by_top_10_platforms'
$command = 'get_server_identity'
$command = 'get_logs'
$command = 'get_stream_type_by_top_10_users'
$command = 'get_old_rating_keys'
$command = 'get_new_rating_keys'
$command = 'get_library_user_stats'
$command = 'get_plays_by_dayofweek'
$command = 'get_library_media_info'
$command = 'get_date_formats'
$command = 'get_libraries'
$command = 'get_home_stats'
$command = 'get_server_id'
$command = 'get_pms_update'
$command = 'get_server_friendly_name'
$command = 'get_history'
$command = 'get_server_pref'
$command = 'get_plays_by_date'
$command = 'get_library_watch_time_stats'
$command = 'get_notifiers'
$command = 'get_servers_info'
$command = 'get_library'
$command = 'get_metadata'
$command = 'get_users'
$command = 'get_users_table'
$command = 'get_user'
$command = 'get_user_names'
$command = 'get_user_logins'
$command = 'get_user_ips'
$command = 'get_user_watch_time_stats'
$command = 'get_user_player_stats'

#>