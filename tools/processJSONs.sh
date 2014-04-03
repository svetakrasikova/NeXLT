#!/bin/bash
#####################
#
# ©2014 Autodesk Development Sàrl
#
# Based on several Solr indexing scripts by Mirko Plitt
#
# Changelog
# v1.			Modified by Ventsislav Zhechev on 03 Apr 2014
# Initial version
#
#####################

mv /OptiBay/SW_JSONs/tools/product.lst /OptiBay/SW_JSONs/tools/old.product.lst
curl --user 'ferrotp:2@klopklop' http://lsdata-internal.autodesk.com/svn/jsons/ |sed 's/.*"\(.*\)".*/\1/
/</d' | sort > /OptiBay/SW_JSONs/tools/product.lst
cd /OptiBay/SW_JSONs
comm -23 /OptiBay/SW_JSONs/tools/product.lst /OptiBay/SW_JSONs/tools/old.product.lst | sed 's/^/co http:\/\/lsdata-internal.autodesk.com\/svn\/jsons\//' | xargs -tL 1 svn


for repo in `cat /OptiBay/SW_JSONs/tools/product.lst`
do
	if [ $repo != test/ ] && [ $repo != ACD_old_test/ ]
	then
		svn up /OptiBay/SW_JSONs/$repo
	fi
done

/OptiBay/SW_JSONs/tools/parseJSON.pl -threads=4
