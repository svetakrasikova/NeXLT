# Run Subversion update in each product folder
for D in `ls -d /mnt/tr/*/`
do
	echo "Trying $D"
	cd $D
	svn up 
	cd /mnt/tr
done
