# Sentora Transfer Agent (STA)

* Version: 0.1.3-BETA

## Description

Transfer all Sentora DATA to another Sentora server with the SAME OS & SAME Sentora VERSION. Script does all the work for you. Just follow the steps.

Sentora Transfer Agent (STA) Copies all folder/files/DB below -
* /etc/sentora
* /var/sentora/hostdata
* /var/sentora/logs/domains
* /var/sentora/vmail
* /root/passwords.txt
* /etc/letsencrypt # If letsencrypt is installed

Automates tasks to new server like:
* Copying files above
* Update new server hostname in /etc/hosts & /etc/hostname
* Changing MySQL root password
* Exporting/Importing databases
* Checking Databases for issues
* Changing Sentora DB x_settings for OS switching. COMING SOON!!!

### Supported OS:

CentOS 6 & 7

Ubuntu 14.04, 16.04, 18.04

## How to use Sentora Transfer Agent

Run this script on the server you are moving-
```
bash <(curl -L -Ss http://zppy-repo.dukecitysolutions.com/repo/sentora-transfer/sentora_transfer.sh)
```

Follow these steps-

BEFORE YOU BEGIN-
Make sure you can SSH into each server with ROOT user. ONLY works as ROOT user. NO SUDO sorry.

1. Enter REMOTE hostname/ip you want to transfer too.

2. It will ask "Enter file in which to save the key (/root/.ssh/id_rsa)" press ENTER.

3. Leave passphrase empty. Just press ENTER.

4. Leave empty. Just press ENTER.

5. Enter ROOT password for REMOTE server you are transfering too.

If script stops on "ENTER PASSWORD:" Enter REMOTE MYSQL root password. This should be done for you but if something goes wrong it will prompt you.

## Getting support

We are currently building a support page to help with any issues. Please check back soon for updates.

## Disclaimer

Besides the usual disclaimer in the license, we want to specifically emphasize that the authors, and any organizations the authors are associated with, can not be held responsible for data-loss caused by possible malfunctions of Sentora Transfer Agent (STA). There is no warranty. Use at your own risk.
