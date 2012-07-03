#!/bin/bash -ue
# openldap/slapd revision controlled backup with git
# supports config file for e-z administration
#
# Copyright (c) 2012 Christian Bryn <chr.bryn@gmail.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


## default config
backup_path="/srv/backup/ldap"
backup_filename="ldaptree.ldif"
git_remote_origin=""
restore="false"
config_file=/etc/slapd-git-backup.cfg

## functions
function print_usage() {
	cat <<EOF
slapd git backup - Christian Bryn 2012 <chr.bryn@gmail.com>
do git revision controlled slapd backups and push remotely
plays nicely with i.e. cgit (web)

Usage: ${0} [-h|-c <config file>]
	-h		This helpful text.
	-c		Pass alternative config file. 
	        Defaults to ${config_file}

Example config file:
  # cat /etc/slapd-git-backup.cfg
backup_path="/srv/backup/ldap"
backup_filename="ldaptree.ldif"
git_remote_origin="git@githost:ldaptree.git"

Example Usage:
  # vi /etc/slapd-git-backup.cfg
  # ${0}

  # ${0} -c /path/to/alternative/config/file.cfg

Hints:
  * No support for multiple slapd repos in one config file - use 
    multiple config files and fire multiple instances of this script.
  * Distribute script with puppet, write config file using puppet 
    template. Realize slapd node names in cgit frontend node config.

EOF
}

is_bin(){ which "${1}">/dev/null||{ printf '>> fatal: no "%s" command in PATH\n' "${1}"; return 1; }; return 0; }

function slapd_stop() {
	service slapd stop >/dev/null
	trap "service slapd start >/dev/null" EXIT
	pgrep -lf $(which slapd) >/dev/null && { printf '>> fatal: could not stop slapd, unable to perform backup\n'; return 1; }
	return 0
}

function slapd_backup() {
	## slapd backup
	# backup routine: we perform a backup regardless of the git repo status
	slapd_stop || exit 1
	slapcat > "${backup_path}/${backup_filename}"
}

function slapd_restore() {
	## this is destructive
	is_bin slapadd || exit 1
	slapd_stop || exit 1
	#slapd
	#cd $1 
	[ -f "${backup_path}/${backup_filename}" ] || { printf '>> no ldif to restore in: %s' "${backup_path}/${backup_filename}"; return 1; }
	rm -rf /var/lib/ldap/*
	slapadd -l "${backup_path}/${backup_filename}"
	chown -R openldap:openldap /var/lib/ldap/*
	return 0
}

## parse command line
while getopts hc: o
do
	case $o in
		h)
			print_usage 
			exit ;;
		c)
			config_file="$OPTARG" ;;
		r)
			restore="true" ;;
	esac
done
shift $(($OPTIND-1))

## read config file
if [ -f "${config_file}" ]; then
	source <( egrep "^backup_path=|^backup_filename=|^git_remote_origin=" "${config_file}" )
fi

## 'sanity-check'
# cheap config 'verification'
# by excluding git_remote_origin here, we can check whether it's empty later on and skip pushing remotely if it is.
for var in backup_path backup_filename;
do
	eval config_value=\$$var
	[ ${config_value} == '' ] && { printf '>> fatal: config variable %s is unset!' "${var}"; exit 1; }
done

is_bin service || exit 1
is_bin slapcat || exit 1

if [ "${restore}" != "true" ]; then
	[ -d "${backup_path}" ] || { printf '>> info: backup path %s does not exist, creating...\n' "${backup_path}"; mkdir -p "${backup_path}"; }
	slapd_backup
fi

## setup git repo
export GIT_WORK_TREE="${backup_path}"
export GIT_DIR="${GIT_WORK_TREE}/.git"

if [ ! -d "${GIT_DIR}" ]; then
    printf '>> info: %s does not seem to be a git repo, initializing\n' "${GIT_WORK_TREE}"
	if [ "${restore}" != "true" ]
	then
		cd ${GIT_WORK_TREE} && git init .
	elif [ "${restore}" == "true" ]
	then
		[ "${git_remote_origin}" == "" ] && { printf '>> fatal: git_remote_origin needs to be set in restore mode'; exit 1; }
		repo_base_path=${GIT_WORK_TREE%/*}
		repo_name=${GIT_WORK_TREE##*/}
		( cd "${repo_base_path}" && git clone "${git_remote_origin}" "${repo_name}" )
	fi
fi

if [ "${restore}" == "true" ]; then
	slapd_restore
	exit $?
fi

git add "${backup_filename}"
git commit -m "autocommit: $( date )" "${backup_filename}" >/dev/null || true

# empty git_remote_origin: do not push remotely
[ "${git_remote_origin}" == "" ] && exit
	
## configure git remote
git_push_url=$(git remote show origin -n | grep 'Push  URL' | awk '{ print $NF }')
if [ "${git_push_url}" != "${git_remote_origin}" ]; then
	git remote rm origin
	git_push_url=""
fi
if [ "${git_push_url}" == "" ]; then
	printf '>> setting remote origin %s\n' "${git_remote_origin}"
	git remote add origin "${git_remote_origin}"
fi

## push remotely
git push -q origin master >/dev/null

# vim:set ts=4 sw=4 noexpandtab:
