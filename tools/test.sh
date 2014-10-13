# Test case for parseJSON.pl
# Description: Extracts DEU, FRA, and JPN strings from test/en_us_de-DE_3.json in csv format and compares them to reference files.
# Author: Samuel Läubli
# Created on 13 October 2014
perl parseJSON.pl -jsonFile=test/en_us_de-DE_3.json -format=csv -product=INFMDR -release=2015
diff test/deu-passolo-data.csv corpus.sw.deu.csv
diff test/fra-passolo-data.csv corpus.sw.fra.csv
diff test/jpn-passolo-data.csv corpus.sw.jpn.csv
