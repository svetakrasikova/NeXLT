#!/bin/bash
#
# ©2013–2014 Autodesk Development Sàrl
#
# Sequence of steps needed to update Solr with latest JSON files from transaltion repository
# 
# Creted by Mirko Plitt
#
# Changelog
# v3.0.3	Modified by Ventsislav Zhechev on 27 May 2014
# Updated the commands to connect to the SVN repository.
# Moved the check for new products/repositories after the general repository update.
#
# v3.0.2	Modified by Ventsislav Zhechev on 19 May 2014
# Changed the location of the file indicating the last refresh date.
#
# v3.0.1	Modified by Ventsislav Zhechev on 18 May 2014
# Updated to match the working dir on deployment server.
#
# v3.			Modified by Ventsislav Zhechev on 17 May 2014
# Consolidated all shell scripts into one.
#
# v2.0.1	Modified by Ventsislav Zhechev on 16 May 2014
# We no longer need to use a stand-alone script to submit data to Solr.
#
# v2.			Modified by Ventsislav Zhechev on 03 Apr 2014
# Added a #! to make this script a proper executable.
#
# v1.			Modified by Mirko Plitt
# Initial version
#

cd /local/cms/NeXLT/indexers/translationrepository2nexlt
for D in `ls -d ./*/`
  do
    if [ $D != ./test/ ] && [ $D != ./ACD_old_test/ ]
    then
      echo "Trying $D"
      cd $D
      svn --username ferrotp --password 2@klopklop --non-interactive up
      cd /local/cms/NeXLT/indexers/translationrepository2nexlt
    fi
  done


mv -f product.lst old.product.lst
curl --user 'ferrotp:2@klopklop' http://lsdata.autodesk.com/svn/jsons/ |sed 's/.*"\(.*\)".*/\1/
/</d' | sort -f >product.lst
comm -23 product.lst old.product.lst | sed 's/^/svn --username ferrotp --password 2@klopklop --non-interactive co http:\/\/lsdata.autodesk.com\/svn\/jsons\//' | xargs -L 1 xargs -t


touch /var/www/solrUpdate/passolo.lastrefresh.new

for js in `find . -name "*json" -newer /var/www/solrUpdate/passolo.lastrefresh`
  do
    product=`echo -n $js | sed 's/.\/\([^\/]*\)\/[^\/]*.*\/\([^\/]*\)\/[^\/]*.json/\1/'`
    if [ $product != test ] && [ $product != ACD_old_test ]
    then
      echo "Parsing $js - product: $product"
      ./json2solr.pl $js $product
    fi
  done

mv -f /var/www/solrUpdate/passolo.lastrefresh.new /var/www/solrUpdate/passolo.lastrefresh
