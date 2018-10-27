# Mikrotik RouterOS Backup Collector
This script collects Mikrotik RouterOS Exports and Backups via SSH to your machine. It supports [port knocking](https://wiki.mikrotik.com/wiki/Port_Knocking) for enhanced security. It connects to remote Mikrotik via SSH, saves an */export compact* and */backup* unencrypted. To run this script, passwordless authentication using a ssh key is necessary. A dedicated read only backup user should be created on the router.

# How to use

1. Create a *hosts.txt* file, listing all your Mikrotik Routers

	```bash
	10.12.13.14         my-local-router
	remote.example.com  my-remote-router
	# 8.8.8.8           backup-later
	```

1. (Optional) Define custom Environment Variables in a file named *.env*

	```bash
	PRIVKEY="~/.ssh/id_rsa"
	SSH_PORT="1234"
	KNOCK01="1234"
	KNOCK02="5678"
	```

1. Run the script. The argument `--initial` is helpful at the first run. It will add the remote SSH fingerprints to *~/.ssh/known_hosts.*. The argument `--parallel` will do the colection jobs in parallel.

	```bash
	./mikrotik-backup-collector.sh \
	  --initial \       # to accept new SSH fingerprints
	  --parallel        # if you're in a hurry
	```
1. Define a cronjob and never forget to backup again.
