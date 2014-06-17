#!/bin/bash
#####################
#
# ©2014 Autodesk Development Sàrl
#
# Based on several Solr indexing scripts by Mirko Plitt
#
# Changelog
# v1.1		Modified by Ventsislav Zhechev on 17 Jun 2014
# Added some output to make the logs more readable.
# Updated the code to make it more robust with fewer points of failure.
# Updated the commands to connect to the SVN repository.
#
# v1.0.2	Modified by Ventsislav Zhechev on 27 May 2014
# Moved the check for new products/repositories after the general repository update.
#
# v1.0.1	Modified by Ventsislav Zhechev on 17 May 2014
# Added an option to make sure the product.lst file is processed properly.
#
# v1.			Modified by Ventsislav Zhechev on 03 Apr 2014
# Initial version
#
#####################

cd /OptiBay/SW_JSONs

# Update the local SVN store.
for product in `cat product.lst`
do
  echo "Updating $product from SVN…"
  svn --username ferrotp --password 2@klopklop --non-interactive up $product
done

# Check if new SVN repositories have been added.
cd /OptiBay/SW_JSONs/tools
mv -f product.lst old.product.lst
echo "Fetching current product list…"
curl -s --user 'ferrotp:2@klopklop' http://lsdata.autodesk.com/svn/jsons/ |sed 's!.*"\(.*\)/".*!\1!;/<\|test/d' | sort -f >product.lst

cd /OptiBay/SW_JSONs
# Make sure we index the new products’ data.
for product in `comm -23 product.lst old.product.lst`
do
  echo "Checking out $product from SVN…"
  svn --username ferrotp --password 2@klopklop --non-interactive co http://lsdata.autodesk.com/svn/jsons/$product
done

/OptiBay/SW_JSONs/tools/parseJSON.pl -threads=8
