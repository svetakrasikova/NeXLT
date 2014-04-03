#!/bin/bash
#
# ©2013–2014 Autodesk Development Sàrl
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

mv /mnt/tr/product.lst /mnt/tr/old.product.lst
curl --user 'ferrotp:2@klopklop' https://lsdata.autodesk.com/svn/jsons/ |sed 's/.*"\(.*\)".*/\1/
/</d' | sort -f > /mnt/tr/product.lst
cd /mnt/tr
comm -23 /mnt/tr/product.lst /mnt/tr/old.product.lst | sed 's/^/svn co https:\/\/lsdata.autodesk.com\/svn\/jsons\//' | xargs -L 1 xargs -t
