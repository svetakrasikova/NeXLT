#!/bin/bash
#
# ©2013–2014 Autodesk Development Sàrl
#
# Process all new JSON files, "new" being in relation to the date of the empty file lastrefresh
# We need to use a temp copy of that file while the JSON files are being processed
# 
# Creted by Mirko Plitt mirko.plitt@autodesk.com
#
# Changelog
# v2.0.1	Modified by Ventsislav Zhechev on 03 Apr 2014
# Modified to skip the test and ACD_old_test repositories.
# Added a #! to make this script a proper executable.
#
# v2.			Modified by Ventsislav Zhechev on 02 Apr 2014
# Modified to process all JSON files using json2solr.pl
#
# v1.			Modified by Mirko Plitt
# Initial version
#

touch /mnt/tr/lastrefresh.new

for js in `find /mnt/tr -name "*json" -newer /mnt/tr/lastrefresh`
do
#	echo $js
	product=`echo -n $js | sed 's/\/mnt\/tr\/\([^\/]*\)\/[^\/]*.*\/\([^\/]*\)\/[^\/]*.json/\1/'`
	if [ $product != test ] && [ $product != ACD_old_test ]
	then
		echo "Parsing $js - product: $product"
		/mnt/tr/json2solr.pl $js $product
	fi
done

mv /mnt/tr/lastrefresh.new /mnt/tr/lastrefresh
