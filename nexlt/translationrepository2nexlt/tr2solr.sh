#!/bin/bash
#
# ©2013–2014 Autodesk Development Sàrl
#
# Sequence of steps needed to update Solr with latest JSON files from transaltion repository
# 
# Creted by Mirko Plitt
#
# Changelog
# v2.			Modified by Ventsislav Zhechev on 03 Apr 2014
# Added a #! to make this script a proper executable.
#
# v1.			Modified by Mirko Plitt
# Initial version
#

/mnt/tr/checkout_new_products.sh
rm -fv /mnt/tr/*passolo-data
/mnt/tr/update-from-svn.sh  
/mnt/tr/newjson2tsv.sh  
/mnt/tr/update-solr.sh
