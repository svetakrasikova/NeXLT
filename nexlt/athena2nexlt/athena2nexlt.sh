#!/bin/bash
#
# ©2013–2014 Autodesk Development Sàrl
#
# Creted by Mirko Plitt
#
# Changelog
# v2.			Modified by Ventsislav Zhechev on 15 Apr 2014
# Added a #! to make this script a proper executable.
# Removed unnecessary commands, as AthenaExportMt now produces proper output for Solr.
#
# v1.			Modified by Mirko Plitt
# Initial version
#

echo "*****************************************************"
date
cd /local/cms/NeXLT/nexlt/athena2nexlt
rm -f *.csv
java -cp bzip2.jar:opencsv-2.3.jar:oracle_11203_ojdbc6.jar:. AthenaExportMt jdbc:oracle:thin:@oracmsprd1.autodesk.com:1521:CMSPRD1 cmsuser Ten2Four ALL $(date --date yesterday +%Y.%m.%d) $(date +%Y.%m.%d) 0 1
for csv in *.csv
do
	echo "Indexing $csv"
	curl "http://ec2-54-227-78-139.compute-1.amazonaws.com:8983/solr/update/csv?&separator=%09&commit=true" --data-binary @$csv -H 'Content-type:text/plain; charset=utf-8'
done
