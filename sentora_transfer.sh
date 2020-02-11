#!/bin/bash

SSTA_VERSION="0.1.1-BETA"
PANEL_PATH="/etc/sentora"

#--- Display the 'welcome' splash/user warning info..
echo ""
echo "############################################################################################"
echo "#  Welcome to the Official Sentora Server Transfer Agent. Installer v.$SSTA_VERSION  #"
echo "############################################################################################"
echo ""
echo -e "\n- Checking that minimal requirements are ok"

# Check if the user is 'root' before updating
if [ $UID -ne 0 ]; then
    echo "Install failed: you must be logged in as 'root' to install."
    echo "Use command 'sudo -i', then enter root password and then try again."
    exit 1
fi
# Ensure the OS is compatible with the launcher
if [ -f /etc/centos-release ]; then
    OS="CentOs"
    VERFULL=$(sed 's/^.*release //;s/ (Fin.*$//' /etc/centos-release)
    VER=${VERFULL:0:1} # return 6 or 7
elif [ -f /etc/lsb-release ]; then
    OS=$(grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//')
    VER=$(grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//')
elif [ -f /etc/os-release ]; then
    OS=$(grep -w ID /etc/os-release | sed 's/^.*=//')
    VER=$(grep VERSION_ID /etc/os-release | sed 's/^.*"\(.*\)"/\1/')
else
    OS=$(uname -s)
    VER=$(uname -r)
fi
ARCH=$(uname -m)

echo "- Detected : $OS  $VER  $ARCH"

if [[ "$OS" = "CentOs" && ("$VER" = "6" || "$VER" = "7" ) || 
      "$OS" = "Ubuntu" && ( "$VER" = "14.04" || "$VER" = "16.04" || "$VER" = "18.04" ) ]] ; then
    echo "- Ok."
else
    echo "Sorry, this OS is not supported by Sentora." 
    exit 1
fi

### Ensure that sentora is installed
if [ -d /etc/sentora ]; then
    echo "- Found Sentora, processing..."
else
    echo "Sentora is not installed, aborting..."
    exit 1
fi

# -------------------------------------------------------------------------------
# Check local and remote server OS match
# -------------------------------------------------------------------------------

# Get Remote hostname/ip info
read -e -p "Enter HOSTNAME/IP of REMOTE SERVER to Transfer Sentora panel too: " PANEL_FQDN

# SSH key setup for client/server
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t rsa
ssh-copy-id -i ~/.ssh/id_rsa.pub root@$PANEL_FQDN

# Set ssh call
SSH_REMOTE="ssh root@$PANEL_FQDN" # check this

# Get other remote server info
remotemysqlpassword=$($SSH_REMOTE cat /etc/sentora/panel/cnf/db.php | grep "pass =" | sed -s "s|.*pass \= '\(.*\)';.*|\1|")

# Get Remote OS version
if $SSH_REMOTE [ -f /etc/centos-release ]; then
    REMOTE_OS="CentOs"
    REMOTE_VERFULL=$($SSH_REMOTE "sed 's/^.*release //;s/ (Fin.*$//' /etc/centos-release")
    REMOTE_VER=${REMOTE_VERFULL:0:1} # return 6 or 7
elif $SSH_REMOTE [ -f /etc/lsb-release ]; then
    REMOTE_OS=$($SSH_REMOTE grep DISTRIB_ID /etc/lsb-release | sed 's/^.*=//')
    REMOTE_VER=$($SSH_REMOTE grep DISTRIB_RELEASE /etc/lsb-release | sed 's/^.*=//')
elif $SSH_REMOTE [ -f /etc/os-release ]; then
    REMOTE_OS=$($SSH_REMOTE grep -w ID /etc/os-release | sed 's/^.*=//')
    REMOTE_VER=$($SSH_REMOTE grep VERSION_ID /etc/os-release | sed 's/^.*"\(.*\)"/\1/')
else
    REMOTE_OS=$(uname -s)
    REMOTE_VER=$(uname -r)
fi

#REMOTE_OS=$($SSH_REMOTE "lsb_release -d")
#LOCAL_OS=$(lsb_release -d)

# Check OS's Match. Will add support to transfer to other OS's SOON.
if [ "$OS" == "$REMOTE_OS" ]; then
    echo -e "\n- Remote OS MATCH, processing...\n"
else
    echo -e "\nRemote server OS DOES NOT MATCH local server - Remote server Detected : $REMOTE_OS  $REMOTE_VER  $REMOTE_ARCH..."
	echo "Local server OS - Detected : $OS  $VER  $ARCH, aborting..."
    exit 1
fi

# Check REMOTE server has same Sentora version.
SEN_VER=$($PANEL_PATH/panel/bin/setso --show dbversion)
REMOTE_SEN_VER=$($SSH_REMOTE $PANEL_PATH/panel/bin/setso --show dbversion)

if [ "$SEN_VER" == "$REMOTE_SEN_VER" ]; then
    echo -e "\n- Remote Sentora version MATCHED, processing...\n"
else
    echo -e "\nRemote Sentora version DOES NOT MATCH local server - Remote server Detected : $REMOTE_SEN_VER..."
	echo "Local Sentora version - Detected : $SEN_VER, aborting..."
    exit 1
fi

# -------------------------------------------------------------------------------
## Prepare panel for transfer
# -------------------------------------------------------------------------------

## Prepare Database for transfer
# Run Mysql_upgrade to check/fix any issues.
mysqlpassword=$(cat /etc/sentora/panel/cnf/db.php | grep "pass =" | sed -s "s|.*pass \= '\(.*\)';.*|\1|")
while ! mysql -u root -p$mysqlpassword -e ";" ; do
read -p "Cant connect to mysql, please give root password or press ctrl-C to abort: " mysqlpassword
done
echo -e "Connection mysql ok"
mysqldump -uroot -p"$mysqlpassword" --all-databases > ~/sentora_backup.sql

# -------------------------------------------------------------------------------
## Transfer Starts here
# -------------------------------------------------------------------------------

# Transfer Sentora needed Folders/files
echo -e "\nStarting transfer of files ...\n"
rsync -v -a -e ssh ~/passwords.txt root@$PANEL_FQDN:~/passwords.txt
rsync -v -a -e ssh /etc/sentora/ root@$PANEL_FQDN:/etc/sentora
rsync -v -a -e ssh /var/sentora/hostdata/ root@$PANEL_FQDN:/var/sentora/hostdata
rsync -v -a -e ssh /var/sentora/logs/domains/ root@$PANEL_FQDN:/var/sentora/logs/domains
rsync -v -a -e ssh /var/sentora/vmail/ root@$PANEL_FQDN:/var/sentora/vmail

# Transfer Letsencrypt folder/files if they exist
if [ -d "/etc/letsencrypt/" ]; then
    rsync -v -a -r -z -P -e ssh /etc/letsencrypt/ root@$PANEL_FQDN:/etc/letsencrypt
fi

# Transfer DB
echo -e "\nStarting transfer of Databases ...\n"
rsync -v -a -e ssh ~/sentora_backup.sql root@$PANEL_FQDN:~/sentora_backup.sql

# -------------------------------------------------------------------------------
## Transfer Ends here
# -------------------------------------------------------------------------------
# -------------------------------------------------------------------------------
## SSH in to Remote Server for setup
# -------------------------------------------------------------------------------

##Setup root user password, restore DB & check DB

# Setup/change new server Mysql root password to current password
while ! $SSH_REMOTE "mysql -u root -p'$remotemysqlpassword' -e ';'" ; do
	read -p "Cant connect to REMOTE MYSQL, please give root password to REMOTE SQL SERVER or press ctrl-C to abort: " remotemysqlpassword
done
echo -e "Connection mysql ok"
$SSH_REMOTE "mysqladmin -u root -p'$remotemysqlpassword' password '$mysqlpassword'"

## Import DB
$SSH_REMOTE "mysql -u root -p'$mysqlpassword' < ~/sentora_backup.sql"

## Check DB for errors
$SSH_REMOTE "mysqlcheck --all-databases -u root -p'$mysqlpassword'" 

# Change Sentora x_settings if needed for other OS converting
if [ "$OS" != "$REMOTE_OS" ]; then
	if [[ "$REMOTE_OS" = "CentOs" ]]; then	
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set bind_dir "/etc/named/"'
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set bind_service "named"'
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set httpd_exe "httpd"'
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set apache_sn "httpd"'
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set cron_file "/var/spool/cron/apache"'
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set cron_reload_path "/var/spool/cron/apache"'
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set cron_reload_user "apache"'
	elif [[ "$REMOTE_OS" = "Ubuntu" ]]; then	
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set bind_dir "/etc/bind/"'
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set bind_service "bind9"'
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set httpd_exe "apache2"'
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set apache_sn "apache2"'
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set cron_file "/var/spool/cron/crontabs/www-data"'
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set cron_reload_path "/var/spool/cron/crontabs/www-data"'
		$SSH_REMOTE '$PANEL_PATH/panel/bin/setso --set cron_reload_user "www-data"'
	fi
fi

## Setup Folder/files & permissions if needed


## ALL DONE
# Wait until the user have read before restarts the server...
if [[ "$INSTALL" != "auto" ]] ; then
    while true; do
		
        read -e -p "Restart your REMOTE server now to complete the transfer service (y/n)? " rsn
        case $rsn in
            [Yy]* ) break;;
            [Nn]* ) exit;
        esac
    done
    $SSH_REMOTE "shutdown -r now"
fi

