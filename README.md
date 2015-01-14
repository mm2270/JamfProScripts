CasperSuiteScripts
==================

A collection of scripts I have worked on to be used with the Casper Suite, and in some cases, which can be used with other Mac management tools.

###Current scripts
[Update_Core_Apps.sh](#update_core_appssh)  
[create_SelfService_Plug-in.sh](#create_selfservice_plug-insh)  
[install_select_SS_plug-ins.sh](#install_select_ss_plug-inssh) *(Companion script for create_SelfService_Plug-in.sh)*  
[install_Latest_GoogleChrome-SelfService.sh](#install_latest_googlechrome-selfservicesh)  
[selectable-SoftwareUpdate.sh](#selectable-softwareupdatesh)
####**Update_Core_Apps.sh**<br>
The Update_Core_Apps script can be used to update many common free applications and Plug-ins. Despite the word "Update" in its name, it can also be used to install most of these applications and Plug-ins new on a target Mac.

Details on the script are as follows:
- Requires the current beta release of cocoaDialog to be installed on the target Mac if using Self Service mode (see below)
- Can update any of the following applications and plug-ins:
  * **Adobe Reader**
  * **Adobe Flash Player**
  * **Firefox**
  * **Firefox ESR**
  * **Flip Player** (free version)
  * **Oracle Java**
  * **Microsoft Office 2011** (updates only)
  * **Silverlight**
  * **VLC**
- Can be used in a "silent" mode to update apps/Plug-ins silently on a target Mac, or "Self Service" mode to prompt an end user to install an update and show them both download and install progress, new version information, and success or failure notifications.
- Has built in version checking against installed applications (if its installed), by comparing it to the latest release from the vendor. The version checking can handle odd version naming conventions, so that it ensures it is only "upgrading" a client, not downgrading it.
- Office 2011 updates utilize a noquit.xml file to suppress the built in quit apps function of these updates. This allows these updates to install either silently, or via Self Service, without forcing the client to shut down the open applications. In both silent and Self Service modes, a dialog will alert the client of any applications that were open that should be quit and relaunched after installation.
- The script accepts two Parameters passed to it from a Casper Suite policy:
  * Parameter 4 ($4) is mandatory, and accepts a number of different strings for the app or Plug-in to check for updates. (For a full listing of acceptable strings, see how to display the help page for the script below).
  * Parameter 5 ($5) is optional, and can accept any string to enable Self Service mode.
  * Strings are case insensitive.
- The script replaces both the **installLatestFlashPlayer-v1.sh** and **install_Latest_AdobeReader.sh** scripts.

#####Basic usage  
1. To test the script from Terminal on a Casper Suite managed Mac:  
`sudo jamf runScript -script Update_Core_Apps.sh -path /path/to/script/ -p1 "app or plugin name"` _(mandatory)_ `-p2 "any string to enable Self Service"` _(optional)_  

2. When adding the script to a Casper Suite policy, add a string to Parameter 4 and optionally Paramater 5.

#####To show a help page for the script, in Terminal:  
`/path/to/script/Update_Core_Apps.sh`  
<br>
<br>
####**create_SelfService_Plug-in.sh**<br>
This script can be used to create Casper Suite Self Service Plug-ins on the fly, without needing to create them first within the JSS, then pulling them down with the management framework. Useful for quick testing when creating new Plug-ins, before actually setting them up within the JSS. Also useful for environments that wish to 'scope' URL Plug-ins and not auto deploy all new Plug-ins to all managed Macs.

Details on the script:  

1. The script must be run as root (sudo)
2. The script is interactive. It will 'guide' you on what you need to enter each step of the way.
3. The script clearly indicates what items are **Required** versus those that are **Optional**.
4. The script can accept images to use for the icon and convert them into the correct binary format
5. The script will create SS URL plug-ins with unique IDs that start in the 1000+ range. This is done so (hopefully) none of the ones you create with the script will conflict with any you created in your JSS.  
  *Note: the JSS will start with ID 1 and increment up, even if you delete any plug-ins later (IDs don't get reused).*
6. The script will create the necessary folder hierarchy on a Casper managed Mac, and save it to the appropriate location, making it immediately available in Self Service.app.
 * If used on a non managed Mac, it will save the resulting plug-in plist to your Desktop
7. The script notes the resulting Plug-in's ID (same as file name) and save path, so it should be easy to locate and wrap into a package later for deployment.  

#####Basic usage
`sudo /path/to/create_SelfService_Plug-in.sh`  
Enter your administrator password, and follow the on screen instructions
<br>
<br>
####**install_select_SS_plug-ins.sh**<br>
This script is a companion script to [create_SelfService_Plug-in.sh](#create_selfservice_plug-insh), and is intended to be used from a Casper Suite Self Service policy to allow end users to select the URL plug-ins they wish to install.  

To effectively use this script, the following workflow is recommended:  

1. Create any Self Service URL Plug-ins you wish to offer for installation. You can use any method you want for this, but it is recommended to use the [create_SelfService_Plug-in.sh](#create_selfservice_plug-insh) script to make them.  
2. Create a new directory in `/private/tmp/` called **plug-ins_for_install**  
3. Copy the URL Plug-ins you created in Step 1 from `/Library/Application\ Support/JAMF/Self\ Service/Plug-ins/` to the folder you created in `/private/tmp/`   
4. Using Composer.app, or the packaging tool of your choice, create a deployable package (.pkg or .dmg) of the **plug-ins_for_install** directory and the plists inside it.  
5. Upload the package to your Casper repository as you would any new package.  
6. Create a new script in your Casper Suite JSS using the **install_select_SS_plug-ins.sh** as the code source.  
7. Create a Self Service policy with the package created in Step 4 and the script created in Step 6. Set the script to run as "After".  
<br>
When the policy is run, the package is downloaded and installed. The installation creates the directory with the URL Plug-ins in `/private/tmp/`  
The script runs next and reads the information from each plug-in plist and generates the appropriate dialog for the user running the policy.  
The choices made by the user are captured and only the selected URL plug-ins are copied to `/Library/Application\ Support/JAMF/Self\ Service/Plug-ins/`. They become available immediately in Self Service.  
<br>


####**install_Latest_GoogleChrome-SelfService.sh**<br>
This script is intended to be used within Self Service. The script will operate in one of three ways, dynamically determined based on conditions.  
- If the Google Chrome browser is already installed on the Mac in the standard `/Applications/` path, it will attempt to locate the Google Software Update mechanism and run it as the user to check for, and install, any updates to Chrome. A final dialog will display if the browser was updated, or if it was already up to date.  
- If it cannot locate the Google Software Update tools on the Mac, it will offer to download the latest release and install it.  
- If Google Chrome is not installed or not located in `/Applications/`, it will offer to download the latest release and install it.  

Progress is shown when appropriate. In all cases, the final success dialogs will display the installed or updated version of Google Chrome to the user running the policy.  

Requirements:
- Current beta release of cocoaDialog to be installed on the target Mac  

<br>  
####**selectable-SoftwareUpdate.sh**<br>
- Requires the current beta release of cocoaDialog to be installed on the target Mac.
- Displays a checkbox dialog with available Software Updates to be installed.
- Provides feedback on installations as they run with a moving progress bar.

####**installLatestFlashPlayer-v1.sh**<br>
(This script has been replaced by Update_Core_Apps.sh)

####**install_Latest_AdobeReader.sh**   (_New_)<br>
(This script has been replaced by Update_Core_Apps.sh)
