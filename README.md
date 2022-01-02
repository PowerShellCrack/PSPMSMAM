# PSPMSMAM

**P**owerShell **S**cript **P**lex **M**edia **S**erver **M**anager **a**nd **M**onitor


## What does it do?

This is a still a Work in Progress. Currently I wrote a PowerShell script that can be scheduled in Windows Task Scheduler
to monitor a Plex media server and services. The main focus is to properly manage movies within Radarr, but it can be used for much more.
What it currently does is:


- Monitor services
- Monitor services URL's
- Monitor processes
- Processes new content
- moves new movie to appropriate folder based on genre, and other attributes


## Why use this?

When there are alot of custom folders for movie collections and folder structure, Radarr cannot manage the videos properly.
This is not the fault of Radarr but something more for those that like an organized structure.

Also as movie collections get larger and larger, navigating a single folder with thousands of other folders degrades the Windows Explorer's experience as well as makes it difficult to manage.

For example I broke my library up into grouped genre folders:

- Holidays & Hallmark
- Superhero & Comics
- Children (Boys & Family)
- Children (Girls & Barbie)
- Children (Disney & Pixar)
- Sci-Fi & Fantasy
- Mysteries & Horrors
- Classics & History
- Action & Adventure
- Thrillers & Crime Fiction
- Drama & Romance
- Comedies & Standup
- Sports & Westerns

As you can see there are alot of root folders where I have my movies. __On top of that__ I have additional subfolders for collections such as:

- rozen Collection
- Monsters, Inc. Collection
- Mulan Collection
- Gozilla Collection
- Halloween Collection
- Spider-Man Collection
- The Avengers Collection
- Superman Collection
- X-Men Collection

These are just to name a few. Radarr cannot manage these folders; and even though all the Genre folders are loaded into Radarr it is a pain to select the folder the movie goes into without knowing it genre category.

## How?

To manage these movies. I wrote a xml driven script to properly map the movie to it appropriate folder using both IMDB and TMDB data.

There are many other cxml files in the config folder, but the two that are mainly used are _MediaServer.xml_ and _Radarr.xml_

In the _Radarr.xml_ file, there is a section for genre mappings (\<GenreMappings>\). It doesn't just look at genre but looks at specific _property_ of a movie
object and its value (_tag_) to determine the _binding folder_. This list run in order so that means that even though a movie has a genre of sci-fi,
its studio may be from Marvel and that comes first.

Plex and even Radarr may need credentials. If they are you would need to cred their corresponding credential file for each.

``` powershell
Get-Credential | Export-CliXML RadarrAuth.xml
```
This file can only be decrypted by the user and system it was encrypted with.

<span color="Yellow">Keep in mind if your schedule a script to run using the SYSTEM accoutn, you must also generate the file using the SYSTEM account (use psexec.exe for that)</span>


## Script information

I have collected alot of script over the net and have written a collection of API's for many services and functionalities.

Filename | Location | Use case | Comments
--|--|--|--
MonitorMediaServer.ps1 | root | Main script |
Environments.ps1 | Extensions | cmdlets to manage script environment | Not used
HttpAPI.ps1 | Extensions | cmdlets for web crawling | Not used
ImdbMovieAPI.ps1 | Extensions | cmdlets for pulling video details from IMDB | used both webcrawling and OMDB API
INIAPI.ps1 | Extensions | cmdlets to manage and parse Ini files | advanced method
IniContent.ps1 | Extensions | cmdlets to manage and parse Ini files | Taken from [Oliver Lipkau ](https://github.com/lipkau/PsIni)
Logging.ps1 | Extensions | cmdlet to generate log file with console output | Logs in CMtrace format
PlexAPI.ps1 | Extensions | Manage Plex library and users |
RadarrAPI.ps1 | Extensions | cmdlets to manage videos in Radarr |
SupportFunctions.ps1 | Extensions | cmdlets to manage objects and other string data|
TautulliAPI.ps1 | Extensions | cmdlets to monitor videos history in Tautulli | Work-in-Progress
TmdbAPI.ps1 | Extensions | cmdlets for TMDB | Uses TMDB API
videoparser.ps1 | Extensions | transcode FFMPeg and creates NFO | used to shrink large movies and create missing NFO files.
WinscpAPI.ps1 | Extensions | Cmdets to WinSCP Cmdlets | Not used
XmlRpc.ps1 | Extensions | cmdlets to convert xml rpc api calls to psobjects | Testing with rtorrent
CleanFolder.ps1 | Helpers | Cmdets to remove old and empty folders |
MovieSearch.ps1 | Helpers | Cmdets used to find movies with OMDB and IMDB | Used with main script


## What Else?

I have also been exporting IMDB and TMDB data into PSObjects. the OMDB APi has a 1000 query limit per day. If I were to run this every day to manage my movie collection
I wouldn't finish; this way I can call the objects first to query their details. There is a downfall to this; it is offline so the data can be outdated or obsolete

I have also included form test scripts. These scritps were my original script before OMBI came along and how I use dot manage Radarr.
