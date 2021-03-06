#!/bin/bash
#####################
#
# ©2014–2015 Autodesk Development Sàrl
#
# Based on several Solr indexing scripts by Mirko Plitt
#
# Usage: processJSONs.sh svn_user svn_password
#
# Changelog
# v1.2.3	Modified by Ventsislav Zhechev on 23 Jan 2015
# Updated curl command line parameters.
#
# v1.2.2	Modified by Samuel Läubli on 12 Jan 2015
# Use --trust-server-cert flag for svn in order to connect to SVN server via https
#
# v1.2.1	Modified by Samuel Läubli on 5 Nov 2014
# Connect to SVN server via https instead of http
#
# v1.2		Modified by Samuel Läubli on 13 Oct 2014
# Included additional parameters for parseJSON.pl.
# Parametrised SVN login credentials.
#
# v1.1.1	Modified by Ventsislav Zhechev on 30 Jun 2014
# Fixed the path to the product.lst file.
#
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

# make sure SVN user and password are supplied as positional arguments
if (( "$#" != 2 )) 
then
	echo "Usage: processJSON.sh svnUserName svnPassword"
	exit 1
fi

cd /OptiBay/SW_JSONs

# Update the local SVN store.
for product in `cat tools/product.lst`
do
  echo "Updating $product from SVN…"
  svn --username $1 --password $2 --non-interactive --trust-server-cert up $product
done

# Check if new SVN repositories have been added.
cd /OptiBay/SW_JSONs/tools
mv -f product.lst old.product.lst
echo "Fetching current product list…"
curl -sSk --user "$1:$2" https://lsdata.autodesk.com/svn/jsons/ |sed 's!.*"\(.*\)/".*!\1!;/<\|test/d' | sort -f >product.lst

cd /OptiBay/SW_JSONs
# Make sure we index the new products’ data.
for product in `comm -23 tools/product.lst tools/old.product.lst`
do
  echo "Checking out $product from SVN…"
  svn --username $1 --password $2 --non-interactive --trust-server-cert co https://lsdata.autodesk.com/svn/jsons/$product
done

/OptiBay/SW_JSONs/tools/parseJSON.pl -threads=8 -jsonDir=/OptiBay/SW_JSONs -targetDir=/OptiBay/SW_JSONs/corpus -format=moses
