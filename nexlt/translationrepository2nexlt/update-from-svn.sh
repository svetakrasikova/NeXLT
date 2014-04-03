#!/bin/bash
#
# ©2013–2014 Autodesk Development Sàrl
#
# Run Subversion update in each product folder
# 
# Creted by Mirko Plitt
#
# Changelog
# v2.			Modified by Ventsislav Zhechev on 03 Apr 2014
# Modified to skip the test and ACD_old_test repositories.
# Added a #! to make this script a proper executable.
#
# v1.			Modified by Mirko Plitt
# Initial version
#

for D in `ls -d /mnt/tr/*/`
do
	if [ $D != /mnt/tr/test/ ] && [ $D != /mnt/tr/ACD_old_test/ ]
	then
		echo "Trying $D"
		cd $D
		svn up 
		cd /mnt/tr
	fi
done
