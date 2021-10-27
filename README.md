# PSPMSMAM
Powershell scripts to monitor and manage a Plex Media System


# Configs

Most script use the xml in config folder
| File | Used by| Note |
|--|--|--|
|MediaServer.xml|MonitorMediaServer.ps1| Links to other configs, sets services and paths
|Configs-Gmail.xml|
|Configs-Plex.xml|
|Configs-Radarr.xml|
|Configs-Tautulli.xml|


## Scripts Included

| Script | Uses | Note |
|--|--|--|
|**MonitorMediaServer.ps1**| Hourly | Check services. Check movie request folder; moves movies to appropriate genre folder.|
|**MergeDuplicatesMovies.ps1**|Monthly| Finds duplicate Movie folders, then prompt for the primary one. It will move the content and delete the other folder. **it does not check Radarr for actual movie path**|
|**GetPlexContent.ps1**|Sample| Simply grabs Plex content|
|**SendPlexContent.ps1**|Sample| Simply grabs Plex content and sends email to Plex users|
|**TranscodeLargeFiles.ps1**|Yearly|Converts video files to smaller size using ffmpeg transcoder.|
|**UpdateRadarrMovies.ps1**|Monthly|Check Radarr for missing or outdated movies and their paths and attempt to up date them using IMDB and OMBD. _Used for movie collection folders._|
