#!/bin/bash

##TODO:
### Add automated FTP and SSH setup for easy access to the web dir
### Instead of executing 'mysql_secure_installation', import the functions and automate the process
### The actual solder install
### Web based database management (phpmyadmin)
### Add option to choose database manager
### Add support for Amazon S3 configuration - Technic Soler

# Initial root check
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Variables
  # Condition variables
  declare acceptableYNResponses=(Y y N n);

  # Global variables
  declare workingDir=$PWD"/";
  declare PID=$$;

  # Web server variables
  declare nginxDir="/etc/nginx/sites-available/";
  declare webport=80;
  declare webdir="/var/www/html/";
  declare server_name;

  # Local configuration variables
    # solder.php
    declare repo_location;
    declare mirror_url;
    declare md5filetimeout;

    # app.php
    declare debug;
    declare url;
    declare timezone;

# Returns the position of an element in a given array
function getIndexOf {
  local array=$1;
  local element=$2;
	for i in "${!array[@]}"; do
	   if [[ "${array[$i]}" = "${element}" ]]; then
	       return ${i};
	   fi
	done
}

# Function to get the line number corrosponding to a given input
function getLineNumber {
  local file=$1;
  local string=$2;
  # return `awk "match("'$0'",$string){print NR; exit}" $file`;
  local awkArgs="match("'$0,'"$string){print NR; exit}";
  return `awk $awkArgs $file`;
}

# Function to replace the contents at a given line with the given string
function replaceAtLine {
  local line=$1;
  local string=$2;
  local file=$3;
  sed -i $line's/.*'"/$string/" $file
}

# Function to check whether or not the user intended to run the script
function areYouSure {
  local runAlready=$1;
  if [ !runAlready ]; then
    read -p "This script will install a LEMP stack and the Technic Solder API on your system, are you sure that you would like to continue? (Y/N)";
  fi
	if [[ $REPLY == "N" || $REPLY == "n" ]]; then
		echo "Exiting.";
		exit 1;
	elif [[ $REPLY == "Y" || $REPLY == "y" ]]; then
    echo -e "\nContinuing installation...";
  elif [[ $REPLY != "N" && $REPLY != "n" && $REPLY != "Y" && $REPLY != "y" ]]; then
		echo -e "\nPlease choose either Yes [Y] or No [N]...\n";
		areYouSure true;
	fi
}

#TODO Fix these two functions
# # Function to check if the input hostname is valid (not designed to be implemented by other shell scripts)
#   # 1 = false, 0 = true
# function validHostnameCheck {
#   local input=$1;
# 	local positionInFor;
# 	for i in $input; do
# 		((positionInFor++));
#     local iL=`echo $i | grep '[0-9][a-z][A-Z]\-\.'`;
#     if [ ${#iL} <= 0 ]; then
# 			return 1;
# 		elif [ positionInFor == 256 ]; then
# 			if [ ${i:256:1} != '.' ]; then
# 				return 1;
# 			else
# 				break;
# 			fi
# 		fi
# 	done
# 	return 0;
# }
#
# # Function to check and set the hostname
# function hostnameCheck {
#   local runAlready=$1;
#   local systemHostname=`hostname --fqdn`;
#   local validHostname=`validHostnameCheck $systemHostname`;
# 	if [ -z $systemHostname ] || [ "$validHostname" == 1 ]; then
# 		if [ $runAlready != true ]; then
# 			echo "\nThe hostname of this system is currently unset or invalid. Please set a valid hostname.";
# 		fi
#
# 		echo -e "\nEnter a new hostname:\t";
# 		read -p RESULT
# 		if [ -z $RESULT ]; then
# 			hostnameCheck false;
# 		elif [ ${#RESULT} >= 1 ]; then
# 			if [ validHostnameCheck $RESULT == 0 ]; then
# 				echo "$RESULT" > /etc/hostname;
# 				service hostname.sh start
# 			else
# 				hostnameCheck true;
# 			fi
# 		fi
# 		$hstnme=$RESULT;
# 	elif [ ${#systemHostname} -ge 1 ]; then
# 		if [ validHostnameCheck $RESULT  == 0 ]; then
# 			echo "\nThe current hostname of this system is: \n\t$RESULT\n Would you like to change this? [Y/N]:\t";
# 			read -p changeHostname
# 			if [[ $changeHostname == 'Y' || $changeHostname == 'y' ]]; then
# 				hostnameCheck true;
# 			elif [[ $changeHostname == 'N' || $changeHostname == 'n' ]]; then
# 				$hstnme=$RESULT;
#       # This line is redundant because of the if condition in the outer if statement [ validHostnameCheck $RESULT  == true ] which checks whether or not the hostname is valid
# 			# elif [[ $changeHostname != 'Y' &&  $changeHostname != 'y' && $changeHostname != 'N' && $changeHostname != 'n' ]]; then
# 			# 	hostnameCheck false;
# 			fi
# 		elif [ validHostnameCheck $RESULT == 1 ]; then
# 			hostnameCheck false;
# 		fi
# 	fi
# }

# System hostname variable
declare hstnme;

# Function to update the system
function updateSystem {
	export APT_LISTCHANGES_FRONTEND=none
	apt-get update
	apt-get upgrade -y
	apt-get dist-upgrade -y
}

# Function to install the Technic Solder dependencies
function installSolderDeps {
	export APT_LISTCHANGES_FRONTEND=none
	apt-get install software-properties-common python-software-properties
	apt-get purge `dpkg -l | grep php| awk '{print $2}' |tr "\n" " "`
	add-apt-repository ppa:ondrej/php
	apt-get update 
	apt-get install mysql-server php5.6 php5.6-fpm php5.6-mysql php5.6-cli php5.6-curl php5.6-mcrypt php5.6-apcu php5.6-sqlite3 git perl nginx curl wget nodejs npm -y
}

# Function to automatically setup MySQL
#TODO Deprecated until I can figure out how to do STDIN blocks inside of functions...
# function setupMySQL {
#   echo -e "\nConfiguring MySQL...";
#   mysql_install_db
#   local originalDir=$workingDir;
#   cd /usr/bin/
# 	perl << END_PERL
# 		require "./mysql_secure_installation";
#     prepare();
#
#     get_root_password();
#     if ( $hadpass == 0 ) {
#       print "Set root password? [Y/n] ";
#     } else {
#       print "You already have a root password set, so you can safely answer 'n'.\n\n";
#       print "Change the root password? [Y/n] ";
#     }
#     my $reply = <STDIN>;
#     if ( $reply =~ /n/i ) {
#       print " ... skipping.\n";
#     } else {
#       set_root_password();
#     }
#     print "\n";
#
#     remove_anonymous_users();
#     remove_remote_root();
#     remove_test_database();
#     reload_privilege_tables();
# 	END_PERL
#   cd $originalDir
#
#   echo -e "\nCreating Solder databases...";
#   mysql << "END_MYSQL";
#     CREATE DATABASE solder;
#     GRANT USAGE ON *.* TO solder@localhost IDENTIFIED BY 'solder';
#     GRANT ALL PRIVILEGES ON solder.* TO solder@localhost;
#     FLUSH PRIVILEGES;
#   END_MYSQL;
# }

# Function for automatically setting up Nginx
function setupNginx {
  service nginx start
  echo "\nDetecting IP adderess...";
  ifconfig eth0 | grep inet | awk '{ print $2 }'
  echo "\nBacking up the default Nginx daemon configuration to $nginxDir/default~";
  cp -r $nginxDir"default" $nginxDir"default~";

  #Setting nginx config
  echo -e "\nSetting new Nginx configuration..."
  local nginxConfig = "#Automatically generated by the TechnicSolder install script.\n#DO NOT MANUALLY MODIFY.\nserver {\n\tlisten $webport;\n\n\troot $webdir;\n\tindex index.php index.html index.htm;\n\n\tserver_name $server_name;\n\tlocation / {\n\ttry_files "'$uri $uri/ /index.html;'"\n\t}\n\n\terror_page 404 /404.html;\n\n\terror_page 500 502 503 504 /50x.html;\n\tlocation = /50x.html {\n\t\troot $webdir;\n\t}\n\n "'# pass the PHP scripts to FastCGI server listening on /var/run/php5-fpm.sock'"\nlocation ~ "'\.php$ {'"\n\ttry_files "'$uri =404;'"\n\tfastcgi_pass unix:/var/run/php5-fpm.sock;\n\tfastcgi_index index.php;\n\tfastcgi_param SCRIPT_FILENAME "'$document_root$fastcgi_script_name;'"\n\tinclude fastcgi_params;\n\t}\n}";
  echo -e nginxConfig > $nginxDir"default"
}

# Function for setting up php5-fpm
function setupPhp {
  local phpdir="/etc/php/5.6/";
  local fpmdir="fpm/";
  echo -e "\nBacking up php5.6-fpm config...";
  cp -r $phpdir$fpmdir"php.ini" $phpdir$fpmdir"php.ini~"

  echo -e "\nSetting new php5-fpm config...";
  echo "cgi.fix_pathinfo=0" > $phpdir$fpmdir"php.ini";

  echo -e "\nEnabling php5-mcrypt...";
  phpenmod mcrypt

  echo -e "\nRestarting the php5-fpm service..."
  service php5.6-fpm restart
}

function installComposer {
  # Deprecated blockquote until I can figure out how to do STDIN blocks in functions
  # : << '_blockquote_';
  # echo -e "\nWould you like to install composer locally or globally? [L/G]";
  # read -p composerPrmpt
  # if [[ $composerPrmpt == 'L' || $composerPrmpt == 'l' ]]; then
  #   echo -e "\nInstalling composer locally..."
  # fi
  # _blockquote_;

  echo -e "\nInstalling composer...";
  mkdir $workingDir"composer"
  cd composer
  curl -sS https://getcomposer.org/installer | php
  mv composer.phar /usr/local/bin/composer

  echo -e "\nChecking for updates...";
  composer self-update
}

###TODO Add checks for non-existant folders on user specified repository locations
###TODO Change the variable setting to arrays that house the variable fields per file and are iterated upon to set their values instead of setting each variable manually
function setupTechnicSolder {
  echo -e "\nCreating new user and home directory for solder setup...";
  adduser solder
  mkhomedir_helper solder

  echo -e "\nChanging working directory to solder home directory...";
  cd /home/solder/

  echo -e "\nCloning TechnicSolder...";
  git clone https://github.com/TechnicPack/TechnicSolder.git
  composer install --no-dev --no-interaction
  php artisan migrate:install
  php artisan migrate

  echo -e "\nConfiguring Solder...";
  # Writing the solder configs
    # repo_location
    local blankRepoConfigLine="'repo_location' => '',";
    local setRepoConfigLine="'repo_location' => '$repo_location',";
    local repoConfigLocat="config/solder.php";

    local lineNum=getLineNumber $PWD/$repoConfigLocat $blankMirrorConfigLine;
    replaceAtLine $lineNum $setRepoConfigLine "$PWD/$repoConfigLocat";

    #mirror_url
    local blankMirrorConfigLine="'mirror_url' => '',";
    local setMirrorConfigLine="'mirror_url' => '$mirror_url',";
    local mirrorConfigLocat="config/solder.php";

    lineNum=getLineNumber "$PWD/$mirrorConfigLocat" $blankMirrorConfigLine;
    replaceAtLine $lineNum $setMirrorConfigLine "$PWD/$mirrorConfigLocat";

    #md5filetimeout
    local blankmd5ConfigLine="'md5_file_timeout' => 30,";
    local setmd5ConfigLine="'md5_file_timeout' => $md5_file_timeout,";
    local md5ConfigLocat="config/solder.php";

    lineNum=getLineNumber "$PWD/$md5ConfigLocat" $blankmd5ConfigLine;
    replaceAtLine $lineNum $setmd5ConfigLine "$PWD/$md5ConfigLocat";

    #debug
    local blankDebugConfigLine="'debug' => false,";
    local setDebugConfigLine="'debug' => $debug,";
    local debugConfigLocat="config/app.php";

    lineNum=getLineNumber "$PWD/$debugConfigLocat" $blankDebugConfigLine;
    replaceAtLine $lineNum $setDebugConfigLine "$PWD/$debugConfigLocat";

    #url
    local blankURLConfigLine="'url' => 'http://solder.app:8000',";
    local setURLConfigLine="'debug' => $debug,";
    local URLConfigLocat="config/app.php";

    lineNum=getLineNumber "$PWD/$URLConfigLocat" $blankURLConfigLine;
    replaceAtLine $lineNum $setURLConfigLine "$PWD/$URLConfigLocat";

    #timezone
    local blankTimezoneConfigLine="'url' => 'http://solder.app:8000',";
    local setTimezoneConfigLine="'debug' => $debug,";
    local timezoneConfigLocat="config/app.php";

    lineNum=getLineNumber "$PWD/$timezoneConfigLocat" $blankTimezoneConfigLine;
    replaceAtLine $lineNum $setTimezoneConfigLine "$PWD/$timezoneConfigLocat";

    #Databases
    cp -r database.php /config/
    php artisan migrate:install
    chmod /public 664
    chmod /app/storage 664
}

function askConfig {
  #Web server configs
    #Web port configuration
    echo -e "\nUse default web port:\t80? [Y/N]\n";
    read -p wp;
    if [[ $wp == 'N' || $wp == 'n' ]]; then
      echo -e "\nPlease enter a new web port:\t";
      read -p webp;
      $webpot=$webp;
    else
        echo -e "\nSetting web port to default:\t80";
    fi

    #Web directory configuration
    echo -e "\nUse default root web directory:\t'$webdir'?\ [Y/N]\n";
    read -p webdirprompt;
    if [[ $webdirprompt == 'N' || $webdirprompt == 'n' ]]; then
      echo -e "\nPlease enter a new root web directory:\t";
      read -p newwebdir;
      $webdir=$newwebdir;
    else
      echo -e "\nUsing default root web directory:\t'$webdir'"
    fi

    #Server name configuration
    echo -e "\nUse default domain name:\t'$server_name'?\ [Y/N]\n";
    read -p servnmeprompt;
    if [[ $servnmeprompt == 'N' || $servnmeprompt == 'n' ]]; then
      echo -e "\nPlease enter a new domain name:\t";
      read -p newservnme;
      $server_name=$newservnme;
    else
      echo -e "\nUsing default domain name:\t'$server_name'";
    fi

  #Solder configs
    #modpack_repo
    echo -e "\nPlease enter the modpack repository location followed by a trailing [/]: (Default: '/home/solder/modpack_repo/')\t";
    read -p modpackRepoLocation
    if [ -z $modpackRepoLocation ]; then
      echo -e "\nUsing default repository location: '/home/solder/modpack_repo/'";
      mkdir /home/solder/modpack_repo
    elif [ ${#modpackRepoLocation} >= 1 ]; then
      echo -e "\nUsing new repository location: '$modpackRepoLocation'";
      $repo_location=$modpackRepoLocation;
    fi

    #mirror_url
    echo -e "\nPlease enter the mirror repository location followed by a trailing [/]: (Default: '/home/solder/modpack_repo/mods/')\t";
    read -p modpackRepoLocation
    if [ -z $mirrorRepoLocation ]; then
      echo -e "\nUsing default mirror location: '/home/solder/modpack_repo/mods/'";
      mkdir /home/solder/modpack_repo/mods
    elif [ ${#mirrorRepoLocation} >= 1 ]; then
      echo -e "\nUsing new mirror location: '$mirrorRepoLocation'";
      $mirror_location=$mirrorRepoLocation;
    fi

    #md5filetimeout
    echo -e "\nPlease enter the timeout for MD5 file hashes: (Default: 30)\t";
    read -p md5timout
    if [ -z $md5timout ]; then
      echo -e "\nUsing default timeout: 30";
      $md5filetimeout=30;
    elif [ ${#md5timout} >= 1 ]; then
      echo -e "\nUsing new timeout: '$md5timout'";
      $md5filetimeout=$md5timout;
    fi

    #debug
    echo -e "\nEnable debugging? (Default: false)\t";
    read -p debugging
    if [ ${#debugging} >= 1 ]; then
      echo -e "\nDebugging enabled.";
      $debug=true;
    else
      echo -e "\nDebugging disabled.";
      $debug=false;
    fi

    #url
    echo -e "\nPlease enter the web adderess and port for the Solder web interface: (Default: http://solder:8000)\t";
    read -p waap
    if [ -z $waap ]; then
      echo -e "\nUsing default web adderss and port: 'http://solder:8000'";
      $url="http://solder:8000";
    elif [ ${#waap} >= 1 ]; then
      echo -e "\nUsing new web adderess and port: '$waap'";
      $url=$waap;
    fi

    #timezone
    echo -e "\nPlease enter your timezone: (Default: EST)\t";
    read -p tz
    if [ -z $tz ]; then
      echo -e "\nUsing default timezone: 'EST'";
      $timezome="EST";
    elif [ ${#tz} >= 1 ]; then
      echo -e "\nUsing new timezone: '$tz'";
      $timezone=$tz;
    fi
}

# Echo the working directory to terminal
echo $workingDir

# Are you sure that you want to run this script?
areYouSure;

# Hostname null / invalid check
# $hstnme=hostnameCheck false;
# hostnameCheck false;
$hstnme=`hostname --fqdn`;

# Setting the server_name to the system hostname
server_name=$hstnme;

askConfig;

echo -e "\nUpdating system..."
updateSystem;

echo -e "\nInstalling LEMP stack"
echo -e "\nInsalling dependencies..."
installSolderDeps;

echo -e "\nSetting up MySql..."
# setupMySQL;
echo -e "\nConfiguring MySQL...";
mysql_install_db
local originalDir=$workingDir;
cd /usr/bin/
perl <<END_PERL
	require "./mysql_secure_installation";
  prepare();

  get_root_password();
  if ( $hadpass == 0 ) {
    print "Set root password? [Y/n] ";
  } else {
    print "You already have a root password set, so you can safely answer 'n'.\n\n";
    print "Change the root password? [Y/n] ";
  }
  my $reply = <STDIN>;
  if ( $reply =~ /n/i ) {
    print " ... skipping.\n";
  } else {
    set_root_password();
  }
  print "\n";

  remove_anonymous_users();
  remove_remote_root();
  remove_test_database();
  reload_privilege_tables();
END_PERL;
cd $originalDir

echo -e "\nCreating Solder databases...";
mysql <<'END_MYSQL';
  CREATE DATABASE solder;
  GRANT USAGE ON *.* TO solder@localhost IDENTIFIED BY 'solder';
  GRANT ALL PRIVILEGES ON solder.* TO solder@localhost;
  FLUSH PRIVILEGES;
END_MYSQL;


echo -e "\nSetting up Nginx..."
setupNginx;

echo -e "\nSetting up php5-fpm..."
setupPhp;

echo -e "\nInstalling and configuring composer..."
installComposer;

echo -e "\nSetting up Technic Solder..."
setupTechnicSolder;

echo -e "\nThe installation is complete. You can access your solder web interface by going to '$url' in your browser."
