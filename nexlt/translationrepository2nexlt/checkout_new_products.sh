mv /mnt/tr/product.lst /mnt/tr/old.product.lst
curl --user 'ferrotp:2@klopklop' https://lsdata.autodesk.com/svn/jsons/ |sed 's/.*"\(.*\)".*/\1/
/</d' | sort -f > /mnt/tr/product.lst
cd /mnt/tr
comm -23 /mnt/tr/product.lst /mnt/tr/old.product.lst | sed 's/^/svn co https:\/\/lsdata.autodesk.com\/svn\/jsons\//' | xargs -L 1 xargs -t
