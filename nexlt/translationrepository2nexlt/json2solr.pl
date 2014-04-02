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
#
################################################################################

use strict;
use utf8;

use threads;
use Thread::Queue;

use Encode qw/encode/;

use URI::Escape;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use jProject;

#binmode(STDOUT, ":utf8");

die( "Script takes two arguments: $0 <JSON_file> <product_code>\n" ) unless @ARGV == 2;
my $jsonFile = $ARGV[0];
my $aproduct = $ARGV[1];
die( "    ERROR: JSON file $jsonFile doesn't exist!\n" ) unless -e $jsonFile;


my %ProdID_ProductRel; # Key: ProductId, Value: Array(Product, Release)
# Load reference file, RAPID_ProductId.tsv
open( PRODIDFILE , "RAPID_ProductId.tsv" ) or die "Cannot open RAPID_ProductId.tsv file!\n";
while(<PRODIDFILE>) {
	my @line = split /\t/, $_;
	$ProdID_ProductRel{$line[0]} = [$line[9],$line[8]] unless exists $ProdID_ProductRel{$line[0]};
}
close(PRODIDFILE);
print STDERR "RAPID file loaded.\n";

my %ResTypeDll = ( "4" => "Menu" , "5" => "Dialog" , "6" => "String Table" , "9" => "Accelerator Table" , "11" => "Message Table" , "16" => "Version" , "23" => "HTML", "240" => "DLGINIT" );

print STDERR "Parsing JSON file.\n";
my $project = jProject->read_dump_file($jsonFile);
print STDERR "JSON file parsed.\n";

#Convert the list of lists into a hash for easier access
my %prjCustomProps = map{$_->[0] => $_->[1]} @{$project->prj_custom_props};

# good to have, but unused
#my ($ProductID, $Component, $DevBranch, $Phase, $SrcVersion, $LocVersion, $LocalizationType, $Email) = @prjCustomProps{qw/M:LPUProductId M:LPUComponent M:LPUDevBranch M:LPUPhase M:LPUSrcVersion M:LPULocVersion M:LPULocalizationType M:LPUEmail/};
my ($Version, $Product) = exists $ProdID_ProductRel{$prjCustomProps{"M:LPUProductId"}} ? @{$ProdID_ProductRel{$prjCustomProps{"M:LPUProductId"}}} : (undef, undef);

my %languageQueues;
my @workers;

my $printer = sub {
	my $language = shift;
	return unless defined $languageQueues{$language};
	
	open OUTPUT, ">>$language-passolo-data";
	while (my $data = $languageQueues{$language}->dequeue()) {
		print OUTPUT encode "utf-8", $data;
	}
	close OUTPUT;
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
	my $src;
	my $trn;
	my $restype;
	my $id;
	
	foreach my $str (@{$strList->strings}) {
		#Short-circuit exit conditions
		next if $str->src_text =~ /^\s*$/ ||
						$str->trn_text =~ /^\s*$/ ||
						$str->id =~ /^\s*$/ ||
						$str->state_review ||
						$str->state_readonly ||
						(!$str->state_translated && !$str->state_pretranslated);
#						!$str->state_pretranslated;

		$restype = exists $ResTypeDll{$str->resource->restype} && $ResTypeDll{$str->resource->restype} =~ /^\d+$/ ? $ResTypeDll{$str->resource->restype} : $str->resource->restype;
		next unless $restype;
		
		$src = $str->src_text;
		$src =~ s/&amp;/\&/g;
		$src =~ s/&(\w)/$1/g;
		$src =~ s/[\h\v]+/ /g;
		$src =~ s/\\$/\\ /g;
		$src =~ s/\\\t/\\ \t/g;

		$trn = $str->trn_text;
		$trn =~ s/&amp;/\&/g;
		$trn =~ s/&(\w)/$1/g;
		$trn =~ s/[\h\v]+/ /g;
		$trn =~ s/\\$/\\ /g;
		$trn =~ s/\\\t/\\ \t/g;
		
		$id = $str->id;
		$id =~ s/\s+//g;
		$id = $lang . "_" . $id . "_" . md5_hex(uri_escape_utf8($str->src_text));

		printForLanguage $lang, "Software\t$restype\t$src\t$trn\t$id\t$aproduct\t$Version\t".lc($src)."\t$lang\n";
	}
}

#Notify the worker threads that we’ve finished processing
$languageQueues{$_}->enqueue(undef) foreach keys %languageQueues;
$_->join foreach @workers;



1;