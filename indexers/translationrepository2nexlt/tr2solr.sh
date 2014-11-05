#!/bin/bash
#
# ©2013–2014 Autodesk Development Sàrl
#
# Sequence of steps needed to update Solr with latest JSON files from transaltion repository
# 
# Creted by Mirko Plitt
#
# Changelog
#
# v3.1.1  Modified by Samuel Läubli on 5 Nov 2014
# Connect to SVN server via https instead of http
#
# v3.1		Modified by Ventsislav Zhechev on 10 Jun 2014
# Added some output to make the logs more readable.
# Fixed a bug where the data from a newly added repository might not be indexed immediately.
# Updated the code to make it more robust with fewer points of failure.
#
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

echo "*****************************************************"
date
cd /local/cms/NeXLT/indexers/translationrepository2nexlt

touch /var/www/solrUpdate/passolo.lastrefresh.new

# Update the local SVN store.
for product in `cat product.lst`
do
  echo "Updating $product from SVN…"
  svn --username ferrotp --password 2@klopklop --non-interactive up $product
done

# Check if new SVN repositories have been added.
mv -f product.lst old.product.lst
echo "Fetching current product list…"
curl -s --user 'ferrotp:2@klopklop' https://lsdata.autodesk.com/svn/jsons/ |sed 's!.*"\(.*\)/".*!\1!;/<\|test/d' | sort -f >product.lst

# Make sure we index the new products’ data.
for product in `comm -23 product.lst old.product.lst`
do
  echo "Checking out $product from SVN…"
  svn --username ferrotp --password 2@klopklop --non-interactive co https://lsdata.autodesk.com/svn/jsons/$product
  for js  in `find $product -name "*json"`
  do
    echo "Parsing $js - product: $product"
    ./json2solr.pl $js $product
  done
done

# Index all files that have been changed since the last indexing.
for product in `cat old.product.lst`
do
  for js  in `find $product -name "*json" -newer /var/www/solrUpdate/passolo.lastrefresh`
  do
    echo "Parsing $js - product: $product"
    ./json2solr.pl $js $product
  done
done

mv -f /var/www/solrUpdate/passolo.lastrefresh.new /var/www/solrUpdate/passolo.lastrefresh
