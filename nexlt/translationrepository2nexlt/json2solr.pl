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
#						➤ properly check integrity conditions before data processing
#						➤ provides proper usage string to the user in case of insufficient command-line options
#
################################################################################

use strict;
use URI::Escape;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use jProject;

binmode(STDOUT, ":utf8");

die( "Script takes three arguments: $0 target_language JSON_file product_code\n" ) unless @ARGV == 3;
my $tgtlang = $ARGV[0];
my $jsonFile = $ARGV[1];
my $aproduct = $ARGV[2];
die( "    ERROR: JSON file $jsonFile doesn't exist!\n" ) unless -e $jsonFile;


my %ProdID_ProductRel; # Key: ProductId, Value: Array(Product, Release)
# Load reference file, RAPID_ProductId.tsv
loadRapidIdFile(); # Fill %ProdID_ProductRel

# print header
print "resource\trestype\tenu\t$tgtlang\tid\tproduct\trelease\tsrclc\n";

my %ResTypeDll = ( "4" => "Menu" , "5" => "Dialog" , "6" => "String Table" , "9" => "Accelerator Table" , "11" => "Message Table" , "16" => "Version" , "23" => "HTML", "240" => "DLGINIT" );

my $script_start_time = time();

my $project = jProject->read_dump_file($jsonFile);

#Convert the list of lists into a hash for easier access
my %prjCustomProps = map{$_->[0] => $_->[1]} @{$project->prj_custom_props};

my ($ProductID, $Component, $DevBranch, $Phase, $SrcVersion, $LocVersion, $LocalizationType, $Email) = @prjCustomProps{qw/M:LPUProductId M:LPUComponent M:LPUDevBranch M:LPUPhase M:LPUSrcVersion M:LPULocVersion M:LPULocalizationType M:LPUEmail/};

## print Project level custom properties
#foreach my $props (@$prjCustomProps) {
#	if ($props->[0] =~ /M:LPUProductId/i) {
#		$ProductID = $props->[1];
#		#$Product = $products{$props->[1]};
#	} elsif ($props->[0] =~ /M:LPUComponent/i) {
#		$Component = $props->[1];
#	} elsif ($props->[0] =~ /M:LPUDevBranch/i) {
#		$DevBranch = $props->[1];
#	} elsif ($props->[0] =~ /M:LPUPhase/i) {
#		$Phase = $props->[1];
#	} elsif ($props->[0] =~ /M:LPUSrcVersion/i) {
#		$SrcVersion = $props->[1];
#	} elsif ($props->[0] =~ /M:LPULocVersion/i) {
#		$LocVersion = $props->[1];
#	} elsif ($props->[0] =~ /M:LPULocalizationType/i) {
#		$LocalizationType = $props->[1];
#	} elsif ($props->[0] =~ /M:LPUEmail/i) {
#		$Email = $props->[1];
#	} else {
#		#print "Missed a property??? -> @CusPropArray\n";
#	}
#}

my ($Version, $Product) = exists $ProdID_ProductRel{$ProductID} ? @{$ProdID_ProductRel{$ProductID}} : (undef, undef);
# Get PRODUCT and RELEASE info based on M:LPUProductId
#if ( exists $ProdID_ProductRel{$ProductID} ) {
#	my @ProductRelease = @{$ProdID_ProductRel{$ProductID}};
#	$Product = $ProductRelease[1];
#	$Version = $ProductRelease[0];
#}


foreach my $strList (@{$project->string_lists}) {
	my $lang = $strList->lang;
#	my $FileName = $strList->srcFile;
#	my $srcListId = $strList->ID;
#	my $trnListId = $strList->targetID;
	my $src;
	my $trn;
	my $restype;
#	my $res_num;
#	my $res_name;
#	my $res_parser;
#	my $res_indexFirstStringInResource;
#	my $res_numberStringsInResource;
#	my $res_hidden;
#	my $res_readonly;
#	my $res_srcCustomProp;
#	my $res_trnCustomProp;
	my $id;
#	my $idext;
#	my $num;
#	my $numext;
#	my $translationMemoryID;
#	my $controlclass;
#	my $comment;
#	my $trans_comment;
#	my $new;
#	my $changed;
#	my $hidden;
#	my $readonly;
#	my $translated;
#	my $review;
#	my $pretranslated;
#	my $srclowercase;
	
	foreach my $str (@{$strList->strings}) {
		#Short-circuit exit conditions
		next if $str->src_text =~ /^\s*$/ ||
						$str->trn_text =~ /^\s*$/ ||
						$str->id =~ /^\s*$/ ||
						$str->state_review ||
						$str->state_readonly ||
#						(!$str->state_translated && !$str->state_pretranslated)
						!$str->state_pretranslated;

		$restype = exists $ResTypeDll{$str->resource->restype} && $ResTypeDll{$str->resource->restype} =~ /^\d+$/ ? $ResTypeDll{$str->resource->restype} : $str->resource->restype;
		next unless $restype;

#		$res_num = $str->resource->number;
#		$res_name = $str->resource->resname;
#		$res_parser = $str->resource->resource_parser;
#		$res_indexFirstStringInResource = $str->resource->firsttokenindex;
#		$res_numberStringsInResource = $str->resource->tokencount;
#		$res_hidden = $str->resource->state_hidden;
#		$res_readonly = $str->resource->state_readonly;
#		$res_srcCustomProp = $str->resource->src_cust_props;
#		$res_trnCustomProp = $str->resource->trn_cust_props;
				
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
#		$idext = $str->extid;
#		$num = $str->number;
#		$numext = $str->extnumber;
#		$translationMemoryID = $str->tm_id;
#		$controlclass = $str->ctl_class;
#		$comment = escapeString($str->comment);
#		$trans_comment = escapeString($str->trans_comment);
#		$new = $str->state_new;
#		$changed = $str->state_changed;
#		$hidden = $str->state_hidden;
#		$readonly = $str->state_readonly;
#		$translated = $str->state_translated;
#		$review = $str->state_review;
#		$pretranslated = $str->state_pretranslated;
		print "Software\t$restype\t$src\t$trn\t$id\t$aproduct\t$Version\t".lc($src)."\t$lang\n";
	}
}


#sub escapeString {
#	my $string = shift;
#	$string =~ s/[\h\v]|\^H/ /g;
#	return $string;
#}

sub loadRapidIdFile {
	open( PRODIDFILE , "RAPID_ProductId.tsv" ) or die "Cannot open RAPID_ProductId.tsv file!\n";
	while(<PRODIDFILE>) {
		my @line = split /\t/, $_;
		$ProdID_ProductRel{$line[0]} = [$line[9],$line[8]] unless exists $ProdID_ProductRel{$line[0]};
	}
	close(PRODIDFILE);
}



1;