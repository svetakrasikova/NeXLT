rm /home/ubuntu/nexlt/termtranslationcentral2nexlt/terms/*
mysql -hlocalhost -uroot -pDemeter7 Terminology -e "select TermID, Term, TermTranslation, LangCode3Ltr, ProductCode from TermList where Approved = 1" |awk 'BEGIN { OFS="\t"; FS="\t" }; NR > 1 { uid = $4 "_" $2 "_" $1; gsub(" *","",uid); print "Terminology", "", $2, $3, uid, $5, "", tolower($2) >> "/home/ubuntu/nexlt/termtranslationcentral2nexlt/terms/"$4 }'
for termfile in /home/ubuntu/nexlt/termtranslationcentral2nexlt/terms/*
do
	lang=`basename $termfile`
	echo "Indexing $lang"
	curl "http://ec2-54-227-78-139.compute-1.amazonaws.com:8983/solr/update/csv?&separator=%09&fieldnames=resource,,enu,$lang,id,product,,srclc&commit=true" --data-binary @$termfile -H 'Content-type:text/plain; charset=utf-8'
done
