#
# ©2013–2014 Autodesk Development Sàrl
#
# Update the Solr index
# 
# Creted by Mirko Plitt
#
# Changelog
# v2.			Modified by Ventsislav Zhechev on 03 Apr 2014
# Now we are going through all *-passolo-data files in a loop to simplify the addition of new langauges and avoid pinging Solr for non-existing files.
#
# v1.			Modified by Mirko Plitt
# Initial version
#

for file in /mnt/tr/*-passolo-data
do
	echo "Executing http://localhost:8983/solr/update/csv?stream.file=$file&escape=\&stream.contentType=text/plain;charset=utf-8&separator=%09&commit=true"
	curl "http://localhost:8983/solr/update/csv?stream.file=$file&escape=\&stream.contentType=text/plain;charset=utf-8&separator=%09&commit=true"
done
