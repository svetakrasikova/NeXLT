#
# Process all new JSON files, "new" being in relation to the date of the empty file lastrefresh
# We need to use a temp copy of that file while the JSON files are being processed
# 
# mirko.plitt@autodesk.com
#
touch /mnt/tr/lastrefresh.new

for mljs in `find /mnt/tr/*/trunk/*/Main/all -name "*json" -newer /mnt/tr/lastrefresh`
do
	echo "Processing multilingual $mljs"
        perl /mnt/tr/mljson2sljson.pl $mljs 
done

for js in `find /mnt/tr -name "*json" -newer /mnt/tr/lastrefresh`
do
echo $js
	#if [[ $js == \.\/AIRMAX* ]] 
	product=`echo -n $js | sed 's/\/mnt\/tr\/\([^\/]*\)\/[^\/]*.*\/\([^\/]*\)\/[^\/]*.json/\1/'` 
	language=`echo -n $js | sed 's/\/mnt\/tr\/[^\/]*\/\([^\/]*\).*\/\([^\/]*\)\/[^\/]*.json/\2/' | tr '[:upper:]' '[:lower:]'` 
	echo "Parsing $js - product: $product, language: $language"
	perl /mnt/tr/json2solr.pl $language $js $product  >> /mnt/tr/$language-passolo-data
	#./json2solr.sh $language $js $product  >> /mnt/tr/$language-`date +%Y-%m-%d`
done

mv /mnt/tr/lastrefresh.new /mnt/tr/lastrefresh
