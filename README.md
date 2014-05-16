CasperSuiteScripts
==================

A collection of scripts I have worked on to be used with the Casper Suite, and in some cases, which can be used with other Mac management tools.

###Current scripts
####**selectable-SoftwareUpdate.sh**<br>
- Requires the current beta release of cocoaDialog to be installed on the target Mac.
- Displays a checkbox dialog with available Software Updates to be installed.
- Provides feedback on installations as they run with a moving progress bar.

####**installLatestFlashPlayer-v1.sh**<br>
- Has built in Flash Player plug-in version checking against Adobe's website to determine if a newer release can be installed.
- Silently downloads the latest release (if needed) and installs the update, cleaning up the download at the end.
- Will not downgrade a client running a beta release of Flash Player.
