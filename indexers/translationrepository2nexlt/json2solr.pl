#!/usr/bin/perl -w
################################################################################
#
# ©2012–2014 Autodesk Development Sàrl
# Based on Json2TDumpAllProperties.pl by Antonio Renna
#
################################################################################
# Revisions:
#   1.0 - Antonio Renna (antonio.renna@autodesk.com) Jun-05-2012
#   1.1 - Antonio Renna (antonio.renna@autodesk.com) Aug-28-2012
#   1.2 - Antonio Renna (antonio.renna@autodesk.com) Oct-04-2012
#		- added LPU Component property to be extracted
#   1.3 - Mirko Plitt (mirko.plitt@autodesk.com) Dec-11-2013
#               - adapted to NeXLT and ported over latest modifications 
#                 from Antonio's script
#		2.0 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) Apr-02-2014
#				– Significant sreamlining of the script
#						➤ remove unnecesary data access
#						➤ remove unused source code
#						➤ properly check integrity conditions before data processing
#						➤ provides proper usage string to the user in case of insufficient command-line options
#				– The script now processes properly multilingual JSONs
#						➤ by default the data is appended to files named <language>-passolo-data
#						➤ threads are created on demand to output the data for each language
#						➤ the target language should no longer be provided as a command-line option
#		2.0.1 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) Apr-03-2014
#				– Added a #! to make this script a proper executable.
#		2.0.2 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) Apr-04-2014
#				– Fixed a small bug in the restype consistency check.
#		2.0.3 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) Apr-09-2014
#				– Added language mapping to fix a JSON language data bug.
#		2.0.4 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) Apr-24-2014
#				– Fixed the path to the RAPID_ProductID.tsv file.
#		2.1 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) May-16-2014
#				– Added a default version year.
#				– Changed the ID generation algorithm.
#				– Only meaningful information is passed through the print queue.
#				– Modified to submit content directly to Solr instead of writing to files first.
#		2.1.1 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) May-17-2014
#				– Added a default value for $prjCustomProps{"M:LPUProductId"}.
#				– Added a character limit to source and target strings.
#				– Updated to match the format of the RAPID_ProductId file.
#		2.1.2 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) May-18-2014
#				– Now we map the product code based on the data in the RAPID_ProductID file.
#		2.1.3 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) May-27-2014
#				– Modified the code reading the RAPID product-code-mapping file.
#		2.1.4 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) May-28-2014
#				– Fixed a bug in an while condition statement.
#		2.1.5 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) Jun-02-2014
#				– Fixed the product code selection.
#				– Modified the rule for creating the document ID to be dependent on the restype.
#		2.1.5 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) Jun-11-2014
#				– Now we include the product code when generating the segment ID.
#		2.2 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) Jul-28-2014
#				– Updated to index the full product name for each segment, based on Solr 4.9.0 functionality.
#		2.2.1 – Ventsislav Zhechev (ventsislav.zhechev@autodesk.com) Aug-13-2014
#				– Modified to use aliases for staging and production Solr servers.
#
################################################################################

use strict;
use utf8;

use threads;
use Thread::Queue;

use Encode qw/encode/;
use Text::CSV;

use URI::Escape;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use JSON::XS;
use jProject;

use HTTP::Tiny;


die( "Script takes two arguments: $0 <JSON_file> <product_code>\n" ) unless @ARGV == 2;
my $jsonFile = $ARGV[0];
my $aproduct = $ARGV[1];
die( "    ERROR: JSON file $jsonFile doesn't exist!\n" ) unless -e $jsonFile;

my $http = HTTP::Tiny->new(agent => "SW JSON Indexer", default_headers => {"Content-type" => "application/json; charset=utf-8"});


my %ResTypeDll = ( "4" => "Menu" , "5" => "Dialog" , "6" => "String Table" , "9" => "Accelerator Table" , "11" => "Message Table" , "16" => "Version" , "23" => "HTML", "240" => "DLGINIT" );

print STDERR "Parsing JSON file.\n";
my $project = jProject->read_dump_file($jsonFile);
print STDERR "JSON file parsed.\n";

#Convert the list of lists into a hash for easier access
my %prjCustomProps = map{$_->[0] => $_->[1]} @{$project->prj_custom_props};
$prjCustomProps{"M:LPUProductId"} ||= -1;

# good to have, but unused
#my ($ProductID, $Component, $DevBranch, $Phase, $SrcVersion, $LocVersion, $LocalizationType, $Email) = @prjCustomProps{qw/M:LPUProductId M:LPUComponent M:LPUDevBranch M:LPUPhase M:LPUSrcVersion M:LPULocVersion M:LPULocalizationType M:LPUEmail/};

my ($Version, $Product, $ProductName);
my $foundProduct = 0;
# Load reference file, RAPID_ProductId.tsv
open( my $prodFile , "../RAPID_ProductId.csv" ) or die "Cannot open ../RAPID_ProductId.csv file!\n";
my $csv = Text::CSV->new({ binary => 1, eol => "\n", sep_char => ";" });
while (my $line = $csv->getline($prodFile) and !$foundProduct) {
	if (!$foundProduct && $aproduct eq $line->[5]) {
		$Product = $line->[7];
		$ProductName = $line->[3];
		if ($prjCustomProps{"M:LPUProductId"} > 0) {
			next unless $prjCustomProps{"M:LPUProductId"} == $line->[0];
			$Version = $line->[4];
			$foundProduct = 1;
		} else {
			$Version = 2015;
			$foundProduct = 1;
		}
	}
}
close $prodFile;
print STDERR "RAPID file loaded.\n";
unless ($foundProduct) {
	warn "Could not find product $aproduct in the database with ID ".$prjCustomProps{"M:LPUProductId"}."!\n";
	$Product ||= $aproduct;
	$ProductName ||= $aproduct;
	$Version ||= 2015;
}

my %languageQueues;
my @workers;

my $json = JSON::XS->new->allow_nonref;

my $printer = sub {
	my $language = shift;
	return unless defined $languageQueues{$language};
	
	my $content = '{ ';
	my $first = 1;
	while (my $data = $languageQueues{$language}->dequeue()) {
		unless ($first) {
			$content .= ', '."\n";
		} else {
			$first = 0;
		}
		$content .= encode "utf-8", 
		'"add": { "doc": { "resource": {"set":"Software"}, '.
		'"product": {"set":'.$json->encode($Product).'}, '.
		'"productname": {"remove":'.$json->encode($ProductName).'}, '.
		'"release": {"set":'.$json->encode($Version).'}, '.
		'"id": "'.$data->{id}.'", '.
		'"restype": {"set":'.$json->encode($data->{restype}).'}, '.
		'"enu": {"set":'.$json->encode($data->{enu}).'}, '.
		'"'.$language.'": {"set":'.$json->encode($data->{$language}).'}, '.
		'"srclc": {"set":'.$json->encode($data->{srclc}).'} '.
		'} },'.
		'"add": { "doc": { "id": "'.$data->{id}.'", '.
		'"productname": {"add":'.$json->encode($ProductName).'} '.
		'} }';
	}
	$content .= ', "commit": {} }';
#	open my $f, ">>passolo.$Product.$language";
#	print $f $content;
#	close $f;
	print STDERR encode "utf-8", "Posting $language content for indexing…\n";
	my $response = $http->request('POST', 'http://aws.prd.solr:8983/solr/update/json', { content => $content });
#	my $response = $http->request('POST', 'http://aws.stg.solr:8983/solr/update/json', { content => $content });
	die "HTML request to Solr failed!\n $response->{status} $response->{reason}\n$response->{content}\n" unless $response->{success};
	print STDERR "$language content sucessfully posted!\n";
};

sub printForLanguage {
	my $language = shift;
	unless (exists $languageQueues{$language}) {
		print STDERR "Starting thread for outputting $language.\n";
		$languageQueues{$language} = new Thread::Queue;
		push @workers, threads->create($printer, $language);
	}
	$languageQueues{$language}->enqueue(shift);
}

foreach my $strList (@{$project->string_lists}) {
	my $lang = $strList->lang;
	#Fix some bugs in the JSON files.
	$lang = "esp" if $lang eq "esn";
	$lang = "eng" if $lang eq "enu";
	my ($src, $trn, $restype, $id);
	
	foreach my $str (@{$strList->strings}) {
		#Short-circuit exit conditions
		next if $str->src_text =~ /^\s*$/ ||
						$str->trn_text =~ /^\s*$/ ||
						$str->id =~ /^\s*$/ ||
						$str->state_review ||
						$str->state_readonly ||
						(!$str->state_translated && !$str->state_pretranslated);

		$restype = exists $ResTypeDll{$str->resource->restype} && $str->resource->restype =~ /^\d+$/ ? $ResTypeDll{$str->resource->restype} : $str->resource->restype;
		next unless $restype;
		
		$src = $str->src_text;
		$src =~ s/&amp;/\&/g;
		$src =~ s/&(\w)/$1/g;
		$src =~ s/[\h\v]+/ /g;
		$src =~ s/\\$/\\ /g;
		$src =~ s/\\\t/\\ \t/g;
		next if length $src > 5000;

		$trn = $str->trn_text;
		$trn =~ s/&amp;/\&/g;
		$trn =~ s/&(\w)/$1/g;
		$trn =~ s/[\h\v]+/ /g;
		$trn =~ s/\\$/\\ /g;
		$trn =~ s/\\\t/\\ \t/g;
		next if length $trn > 5000;
		
		$id = $str->id;
		$id =~ s/\s+//g;
		$id = md5_hex(uri_escape_utf8("$id$src$restype$ProductSoftware"));

		printForLanguage $lang, {
			id			=> $id,
			restype	=> $restype,
			enu			=> $src,
			$lang		=> $trn,
			srclc		=> lc($src),
		};
	}
}

#Notify the worker threads that we’ve finished processing
$languageQueues{$_}->enqueue(undef) foreach keys %languageQueues;
$_->join foreach @workers;



1;