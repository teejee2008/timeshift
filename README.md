# TimeShift

TimeShift for Linux is an application that provides functionality similar to the _System Restore_ feature in Windows and the _Time Machine_ tool in Mac OS. TimeShift protects your system by taking incremental snapshots of the file system at regular intervals. These snapshots can be restored at a later date to undo all changes to the system.   

Snapshots are taken using [rsync](http://rsync.samba.org/) and [hard-links](http://en.wikipedia.org/wiki/Hard_link). Common files are shared between snapshots which saves disk space. Each snapshot is a full system backup that can be browsed with a file manager.   

TimeShift is similar to applications like [rsnapshot](http://www.rsnapshot.org/), [BackInTime](https://github.com/bit-team/backintime) and [TimeVault](https://wiki.ubuntu.com/TimeVault) but with different goals. It is designed to protect only system files and settings. User files such as documents, pictures and music are excluded. This ensures that your files remains unchanged when you restore your system to an earlier date. If you need a tool to backup your documents and files please take a look at the excellent [BackInTime](https://github.com/bit-team/backintime) application which is more configurable and provides options for saving user files.  

## Screenshots
[![](http://3.bp.blogspot.com/-tViIIYtGIVk/VqJWGBwwv9I/AAAAAAAADKY/p6qdUPyD8Ug/s1600/Timeshift%2BRSYNC%2Bv1.7.6_055.png)](http://3.bp.blogspot.com/-tViIIYtGIVk/VqJWGBwwv9I/AAAAAAAADKY/p6qdUPyD8Ug/s1600/Timeshift%2BRSYNC%2Bv1.7.6_055.png)  

[![](http://1.bp.blogspot.com/-H59eRf950rU/VqJWFBjSTYI/AAAAAAAADKA/re-otOjxqbc/s1600/Settings_056.png)](http://1.bp.blogspot.com/-H59eRf950rU/VqJWFBjSTYI/AAAAAAAADKA/re-otOjxqbc/s1600/Settings_056.png)  

[![](http://3.bp.blogspot.com/-ixRtHJ-e_7I/VqJWFs36CYI/AAAAAAAADKM/QaN3VDF2jT8/s1600/Settings_057.png)](http://3.bp.blogspot.com/-ixRtHJ-e_7I/VqJWFs36CYI/AAAAAAAADKM/QaN3VDF2jT8/s1600/Settings_057.png)  

[![](http://2.bp.blogspot.com/-AXDmlVFhYhg/VqJWFyYmBJI/AAAAAAAADKQ/GKY4iqWNWts/s1600/Settings_058.png)](http://2.bp.blogspot.com/-AXDmlVFhYhg/VqJWFyYmBJI/AAAAAAAADKQ/GKY4iqWNWts/s1600/Settings_058.png)   

[![](http://4.bp.blogspot.com/-2XB9AIiAh2U/VqJWFIF2nGI/AAAAAAAADKI/v-O2xERMueY/s1600/Restore_059.png)](http://4.bp.blogspot.com/-2XB9AIiAh2U/VqJWFIF2nGI/AAAAAAAADKI/v-O2xERMueY/s1600/Restore_059.png)  

[![](http://2.bp.blogspot.com/-IaiAmmrrhbs/VqJWFKLBupI/AAAAAAAADKE/TfslgQ74IPk/s1600/Restore_060.png)](http://2.bp.blogspot.com/-IaiAmmrrhbs/VqJWFKLBupI/AAAAAAAADKE/TfslgQ74IPk/s1600/Restore_060.png)  

## Features:
### Minimal Setup

*   TimeShift requires very little setup. Just install it, run it for the first time and take the first snapshot. Cron job can be enabled for taking automatic snapshots of the system at regular intervals. The backup levels can be selected from the _Settings_ window.
*   Snapshots are saved by default on the system (root) partition in path **/timeshift**. Other linux partitions can also be selected.

### Boot Snapshots

*   Boot snapshots provide an additional level of backup.
*   Hourly, daily, weekly and monthly levels can be enabled if required.

### Better Snapshots and Rotation

*   TimeShift runs at regular intervals but takes snapshots only when needed.
*   Applications like rsnapshot rotate a snapshot to the next level by creating a hard-linked copy. Creating a hard-linked copy may seem like a good idea but it is still a waste of disk space, since only files can be hard-linked and not directories. The duplicated directory structure can take up as much as 100 MB of space. TimeShift avoids this wastage by using tags for maintaining backup levels. Each snapshot will have only one copy on disk and is tagged as "daily", "monthly", etc. The snapshot location will have a set of folders for each backup level ("Monthly", "Daily", etc) with symbolic links pointing to the actual snapshots tagged with the level.

### System Restore
Snapshots can be restored either from the running system or from a live CD. Restoring backups from the running system requires a reboot to complete the restore process.  
### Cross-Distribution Restore
You can also TimeShift across distributions. Let's say you are currently using Xubuntu and decide to try out Linux Mint. You install Linux Mint on your system and try it out for a week before deciding to go back to Xubuntu. Using TimeShift you can simply restore the last week's snapshot to get your Xubuntu system back. TimeShift will take care of things like reinstalling the bootloader and other details. Since installing a new linux distribution also formats your root partition you need to save your snapshots on a separate linux partition for this to work.
### Exclude Files
TimeShift is designed to protect system files and settings. User data such as documents, pictures and music are excluded by default. This has two advantages:  

*   You don't need to worry about your documents getting overwritten when you restore a previous snapshot.
*   Your music and video collection will not waste space on the backup device.

## Installation

### Ubuntu-based Distributions

Ubuntu, Linux Mint, Elementary OS, etc.

Packages are available in the Launchpad PPA for supported Ubuntu releases.
Run the following commands in a terminal window:  

```sh
sudo apt-add-repository -y ppa:teejee2008/ppa
sudo apt-get update
sudo apt-get install timeshift
```

DEB and RUN packages are available on [Releases](https://github.com/teejee2008/timeshift/releases) page for older Ubuntu releases which have reached end-of-life.

### Other Linux Distributions

Download the .RUN installer from [Releases](https://github.com/teejee2008/timeshift/releases) page and execute it in a terminal window: 

```sh
sudo sh ./timeshift*amd64.run # 64-bit
sudo sh ./timeshift*i386.run  # 32-bit
```

Installer can be used on the following distribution types:

- **RedHat** based - Fedora, RedHat, Cent OS, etc (supports **dnf** and **yum**)
- **Debian** based - Debian, Ubuntu, Linux Mint, Elementary OS, etc (supports **apt**)
- **Arch** based - Arch Linux, Manjaro, etc (supports **pacman**)

## UnInstall

Run the following command in a terminal window:  

    sudo apt-get remove timeshift

or  

    sudo timeshift-uninstall

Remember to delete all snapshots before un-installing. Otherwise the snapshots continue to occupy space on your system.  To delete all snapshots, run the application, select all snapshots from the list (CTRL+A) and click the _Delete_ button on the toolbar. This will delete all snapshots and remove the _/timeshift_ folder in the root directory.    

[![](http://3.bp.blogspot.com/-2Ry_OvakBIw/UmNrdxoiRKI/AAAAAAAABH4/yaEuwCT3trA/s320/delete.png)](http://3.bp.blogspot.com/-2Ry_OvakBIw/UmNrdxoiRKI/AAAAAAAABH4/yaEuwCT3trA/s1600/delete.png)  
If you used the installer to install TimeShift, you can remove the installed files with following command:  

    sudo timeshift-uninstall

## Known Issues and Limitations

### BTRFS volumes
BTRFS volumes must have an Ubuntu-type layout with @ and @home subvolumes. Other layouts are not supported.  
### Disk Space
If the backup device is running out of space, try the following steps:  

*   Reduce the number of backup levels - Enable the _boot_ backup level and disable the others.
*   Reduce the number of snapshots that are kept - In the _Auto-Remove_ tab set the limit for _boot_ snapshots to 10 or less.
*   You can also disable the scheduled snapshots completely.

[![](http://4.bp.blogspot.com/-y0dracHFgGI/UmNpZn8g7hI/AAAAAAAABHw/Itao7TivCpU/s320/Settings.png)](http://4.bp.blogspot.com/-y0dracHFgGI/UmNpZn8g7hI/AAAAAAAABHw/Itao7TivCpU/s1600/Settings.png)    

### GRUB2 Bootloader
Only those systems are supported which use GRUB2 bootloader. Trying to create and restore snapshots on a system using older versions of GRUB will result in a non-bootable system.  

## Disclaimer

This program is free for personal and commercial use and comes with absolutely no warranty. You use this program entirely at your own risk. The author will not be liable for any damages arising from the use of this program. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.   

## Donate

This application is completely free and will continue to remain that way. Your contributions will help in keeping this project alive and improving it further. Feel free to send me an email if you find any issues in this application or if you need any changes. Suggestions and feedback are always welcome.

If you want to buy me a coffee or send some donations my way, you can use Google wallet or Paypal to send a donation to **teejeetech at gmail dot com**.  

[Donate with Paypal](https://www.paypal.com/cgi-bin/webscr?business=teejeetech@gmail.com&cmd=_xclick&currency_code=USD&amount=10&item_name=Timeshift%20Donation)

[Donate with Google Wallet](https://support.google.com/mail/answer/3141103?hl=en)
