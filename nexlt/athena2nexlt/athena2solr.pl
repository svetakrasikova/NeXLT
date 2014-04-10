#!/usr/bin/perl

#"translation type"      "enu"   "deu"   "product"       "release"       "mt score"      "mt translation"        "tm score"      "tm translation"        "creation date"
use URI::Escape;
use Digest::MD5 qw(md5_hex);
#binmode(STDOUT, ":utf8");

my $id, $tgtlang, $srclc, $source, $target, $product, $release;

#open (FILE, "test");
open (FILE, $ARGV[0]);
while (<FILE>) {
	chomp;
	(undef, $source, $target, $product, $release, undef, undef, undef, undef, undef, undef, $id) = split('\t');
	if($. == 1) {
		$tgtlang = substr($target,1,-1);
		print "id\tproduct\tenu\t$tgtlang\trelease\tsrclc\n";
	} else {
		$id = substr($id, 1, -1) . "_". $tgtlang;
		$source = substr($source, 1, -1);
		$product = substr($product, 1, -1);
		$target = substr($target, 1, -1);
		$release = substr($release, 1, -1);
		$srclc = lc($source);
		print "$id\t$product\t$source\t$target\t$release\t$srclc\n";
	}
}
close (FILE);


1;
