# Auto-Solder
An automated shell script for installing and configuring technic solder

> WARNING! This script is not yet fully functional and in some cases, not functional in any respect of the word. Use at your own risk! I am not liable for any damages incurred by the use, modification or redistribution of this scipt or it's derivatives.

## Running

    git clone https://github.com/Matthewacon/Auto-Solder.git
    cd Auto-Solder/
    chmod +x install.sh
    ./install.sh
    
This will start the install script and you will be asked a series of questions pertaining to the configuration of the Solder installation as well as the webserver and database configurations. Once the prompts have been completed, the script will install and configure TechnicSolder and it's dependencies accordingly.

## Result

  * wget
  * curl
  * Nginx
  * MySQL
  * Php5
    * php-fpm
    * php-mysql
    * php-cli
    * php-curl
    * php-mcrypt
    * pyp-apcu
    * php-sqlite
  * composer
  * perl

Once the installation has finished, you can access your Solder web GUI by going to "http://YOUR-IP/Solder.app:8000". This link will be printed to the terminal after the installation has finished.

## NOTICE

The script is currently programmed in Bash (or shell script), and is likely to be completly rewritten completely in either Bash or another language. Please do not rely on the development builds of the script for securely installating Solder as they may be unstable or broken. Instead, use the public version releases.

## Debugging / Troubleshooting
    POST AN ISSUE!
    

