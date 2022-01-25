# Change log for MonitorMediaServer.ps1

## 1.1.3 - January 24, 2022

- Fixed script detecting file sample in name as actual movie; added configurable name sin file to check for
- Added email notification; only send email if critical service is down or new movie has been added.
- Added CHANGELOG; track all changes to scripts.
- Update offline TMDB files to year (date) format
## 1.1.2 - January 2, 2022

- Added FormatTitleCase switch to movie parser; ensures title is capitalized correctly
## 1.1.1 - January 2, 2022

- Added ignore file
- Fixed radarr deletions;
- added imdb and tmdb online search; find accurate movie data
- renamed all movie offline imdb/tbdb data to movie (year) format

## 1.1.0 - Nov 9, 2021

- Remove all un-needed files from repo; some extension scripts not used and ddns usb controllers on different repo
- Fixed new movie detection; year was not parsed correctly through Radarr
- Fixed Video extension rule; had to split comma delimited to array and use -in operator
- Added video support files; script movie support files before removing all other content.
- Added file name parser for movies; detects movie details by name for more accruate search

## 1.0.5 - Oct 27, 2021

- updated README to reflect changes
- Changed all file names to Test; make no script except the MonitorMediaServer.ps1 primary
## 1.0.0 - Oct 26, 2021

- initial design
