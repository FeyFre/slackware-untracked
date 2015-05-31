#!/bin/sh
# 
# Script detects and prints untracked by pkgtools files on filesystem
#
# Sun May 31 16:22:23 EEST 2015
#  Initial release v1.0
#
# Author Panych Y.V. aka FeyFre. Ukraine, Vinnitsa
# e-mail: panychy @ gmail.com
#
# You can freely ditribute and modify this script provided you retain
# original author copyright and links
#
# WARNING: Script detects only standard means of installation
#          it can yield false output if files was created by
#          non-standart doinst.sh routine 
#          ( like in bash package, /bin/bash will be printed )
#          Always examine output manually before removing trash files
#
# Usage: untracked.sh [path-to-ignore]...
#
#   untracked.sh       - print all untracked by pkgtool(see note above)
#
#   untracked.sh /var/lib/mysql - ignore MySQL database storage
# 
#   untracked.sh /mytrash       - ignore known trash location
#
#   NEVER USE untracked.sh |xargs rm -f 
#
# Script already aware of some volatile locations, you can edit BLACKLIST variable
# Script uses default pkgtool admin-zone for temporary file, /var/log/setup/tmp
# Script support ROOT environment variable, but should be tested. Feel free to report.
#
#
# Requirements: coreutils, find, grep, sed and shell itself ;-)
#


### PERMANENT BLACKLIST
BLACKLIST="/mnt /dev /proc /sys /tmp /var/log /mount /home /root /var/tmp /var/spool"
### Allow concurency
PID=$$

### Partialy borrowed from /sbin/removepkg. Thanks to PV

# This makes "sort" run much faster:
export LC_ALL=C

# Make sure there's a proper temp directory:
TMP=$ROOT/var/log/setup/tmp
# If the $TMP directory doesn't exist, create it:
if [ ! -d $TMP ]; then
  rm -rf $TMP # make sure it's not a symlink or something stupid
  mkdir -p $TMP
  chmod 700 $TMP # no need to leave it open
fi
ADM_DIR=/var/log
PRES_DIR=$TMP/preserved_packages

# Extract standard links
extract_links() {
 sed -n 's,^( *cd \([^ ;][^ ;]*\) *; *rm -rf \([^ )][^ )]*\) *) *$,\1/\2,p'
}

# Prepend each line with suffix (arg 1)
prepend() {
 while read line
 do
  echo $1$line
 done
}

# Main reading loop
process() {
 # Read each installed package
 for PKGNAME in $ROOT/$ADM_DIR/packages/*
 do
   if fgrep "./" $PKGNAME 1>/dev/null 2>&1; then
    TRIGGER="^\.\/"
   else
    TRIGGER="FILE LIST:"
   fi
   echo $ROOT/
   sed -n "/$TRIGGER/,/^$/p" <$PKGNAME |fgrep -v "FILE LIST:" |grep -v "^./" |prepend ${ROOT}/ |sed -e 's/\/$//g'
 done
 # Read standart links
 for PKGNAME in $ROOT/$ADM_DIR/scripts/*
 do
   extract_links <$PKGNAME |prepend $ROOT/
 done
}

# Prepare blacklist expr
BLCK=
for IT in $BLACKLIST
do
  if [ -z "$BLCK" ]; then
      BLCK=" -path $ROOT$IT"
  else
      BLCK="$BLCK -o -path $ROOT$IT"
  fi
done
# Done

# Prepare blacklist from user(cmdline)
for IT in $*
do
  BLCK="$BLCK -o -path $ROOT$IT"
done
# Done

# List installed files
process |sort -u >$TMP/list_$PID.lst
# Done

# List real fs tree
find ${ROOT:-/} -type d \( $BLCK \) -prune -o -print |sort -u > $TMP/tree_$PID.lst
# Done

# Do compare
comm -13 $TMP/list_$PID.lst $TMP/tree_$PID.lst >$TMP/comm1st_$PID.lst
#now append .new to differnce
cat $TMP/comm1st_$PID.lst |sed -e 's/$/.new/g' |sort -u >$TMP/comm_new_$PID.lst
#now we check if any .new file was in original list
comm -12 $TMP/list_$PID.lst $TMP/comm_new_$PID.lst |sort -u >$TMP/comm_wasnew_$PID.lst
#now cut out .new suffix
cat $TMP/comm_wasnew_$PID.lst |sed -e 's/\.new$//g' |sort -u >$TMP/comm_wasnewwonew_$PID.lst
#now we remove them from final comaparation
comm -23 $TMP/comm1st_$PID.lst $TMP/comm_wasnewwonew_$PID.lst |sort -u >$TMP/comm_$PID.lst

cat $TMP/comm_$PID.lst
# Done
# Cleanuo our mess
rm -f $TMP/*_$PID.lst 1>/dev/null 2>&1
