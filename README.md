openldap-git-backup
===================

do git revision controlled backups of slapd/openldap-trees and push remotely

<pre>
slapd git backup - Christian Bryn 2012 <chr.bryn@gmail.com>
do git revision controlled slapd backups and push remotely
plays nicely with i.e. cgit (web)

Usage: ./backup-slapd-git.sh [-h|-c <config file>]
	-h		This helpful text.
	-c		Pass alternative config file. 
	        Defaults to /etc/slapd-git-backup.cfg

Example config file:
  # cat /etc/slapd-git-backup.cfg
backup_path="/srv/backup/ldap"
backup_filename="ldaptree.ldif"
git_remote_origin="git@githost:ldaptree.git"

Example Usage:
  # vi /etc/slapd-git-backup.cfg
  # ./backup-slapd-git.sh

  # ./backup-slapd-git.sh -c /path/to/alternative/config/file.cfg

Hints:
  * No support for multiple slapd repos in one config file - use 
    multiple config files and fire multiple instances of this script.
  * Distribute script with puppet, write config file using puppet 
    template. Realize slapd node names in cgit frontend node config.

</pre>
