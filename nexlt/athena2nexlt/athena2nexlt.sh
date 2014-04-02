echo "*****************************************************"
date
rm /local/cms/javaDBLink/athena2nexlt/*.out
rm /local/cms/javaDBLink/athena2nexlt/*.csv
cd /local/cms/javaDBLink/athena2nexlt
java -cp /local/cms/javaDBLink/bzip2.jar:/local/cms/javaDBLink/opencsv-2.3.jar:/local/cms/javaDBLink/oracle_11203_ojdbc6.jar:/local/cms/javaDBLink AthenaExportMt jdbc:oracle:thin:@oracmsprd1.autodesk.com:1521:CMSPRD1 cmsuser Demeter7 ALL $(date --date yesterday +%Y.%m.%d) $(date +%Y.%m.%d) 0
bunzip2 /local/cms/javaDBLink/athena2nexlt/*.bz2
rm /local/cms/javaDBLink/athena2nexlt/*.mt
rm /local/cms/javaDBLink/athena2nexlt/*.tm
sed -i 's/""*/"/g' /local/cms/javaDBLink/athena2nexlt/*.csv
for csv in /local/cms/javaDBLink/athena2nexlt/*.csv
do
        echo "Processing $csv"
        perl /local/cms/javaDBLink/athena2nexlt/athena2solr.pl $csv > $csv.out
        curl "http://ec2-54-227-78-139.compute-1.amazonaws.com:8983/solr/update/csv?&separator=%09&commit=true" --data-binary @$csv.out -H 'Content-type:text/plain; charset=utf-8'
done
