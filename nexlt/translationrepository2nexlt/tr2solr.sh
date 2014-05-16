#!/bin/bash
#
# ©2013–2014 Autodesk Development Sàrl
#
# Sequence of steps needed to update Solr with latest JSON files from transaltion repository
# 
# Creted by Mirko Plitt
#
# Changelog
# v2.0.1	Modified by Ventsislav Zhechev on 16 May 2014
# We no longer need to use a stand-alone script to submit data to Solr.
#
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
