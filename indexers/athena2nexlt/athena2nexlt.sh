#!/bin/bash
#
# ©2013–2015 Autodesk Development Sàrl
#
# Creted by Mirko Plitt
#
# Changelog
# v2.1		Modified by Ventsislav Zhechev on 23 Jan 2015
# We now take DB user/password as command line parameters.
#
# v2.0.5	Modified by Ventsislav Zhechev on 05 Jun 2014
# Made sure the Java tool has enough heap memory to run properly.
#
# v2.0.4	Modified by Ventsislav Zhechev on 03 Jun 2014
# AthenaExportMt no longer requires us to pass the database details on the command line.
#
# v2.0.3	Modified by Ventsislav Zhechev on 19 May 2014
# Added a file indicating the last refresh date.
#
# v2.0.2	Modified by Ventsislav Zhechev on 17 May 2014
# Updated the list of jars in the classpath.
#
# v2.0.1	Modified by Ventsislav Zhechev on 16 May 2014
# The Java tool now submits the data directly to Solr for indexing.
#
# v2.			Modified by Ventsislav Zhechev on 15 Apr 2014
# Added a #! to make this script a proper executable.
# Removed unnecessary commands, as AthenaExportMt now produces proper output for Solr.
#
# v1.			Modified by Mirko Plitt
# Initial version
#

# make sure database user and password are supplied as positional arguments
if (( "$#" != 2 )) 
then
	echo "Usage: athena2nexlt.sh DBUserName DBPassword"
	exit 1
fi

echo "*****************************************************"
date
cd /local/cms/NeXLT/indexers/athena2nexlt
java -cp bzip2.jar:oracle_11203_ojdbc6.jar:httpclient-4.3.3.jar:httpcore-4.3.2.jar:commons-logging-1.1.3.jar:json-simple-1.1.1.jar:. -Xmx4096m AthenaExportMt jdbc:oracle:thin:@oracmsprd1.autodesk.com:1521:CMSPRD1 $1 $2 ALL $(date --date yesterday +%Y.%m.%d) $(date +%Y.%m.%d) 0 1 1

touch /var/www/solrUpdate/athena.lastrefresh
