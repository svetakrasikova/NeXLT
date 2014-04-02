#Sequence of steps needed to update SOlR with latest Json files from transaltion repository
/mnt/tr/checkout_new_products.sh
rm /mnt/tr/*passolo-data
/mnt/tr/update-from-svn.sh  
/mnt/tr/newjson2tsv.sh  
/mnt/tr/update-solr.sh
