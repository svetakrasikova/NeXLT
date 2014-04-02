################################################################################
#
# Json2TDumpAllProperties.pl script decodes strings from a JSON file and exports all info
# Usage:
#   Json2TDumpAllProperties.pl "C:\JSONs\a.json"
#
# First argument is a JSON file
#
# CONSIDERATIONS
#	1. Write to dump as UTF-8
#	2. Escaped strings for \n, \r and \t
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
#
################################################################################

use strict ;
use File::Basename ;
use URI::Escape;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use jProject;
binmode(STDOUT, ":utf8");

die( "Script takes three arguments\n" ) if ( ! @ARGV ) ;
my $tgtlang = $ARGV[ 0 ] ;
my $jsonFile = $ARGV[ 1 ] ;
my $aproduct = $ARGV[ 2 ] ;
die( "    ERROR: JSON file $jsonFile doesn't exist!\n" ) if ( ! -e $jsonFile ) ;

my $jsonFileForTextSearch = $jsonFile;
$jsonFileForTextSearch =~ s/\.json/\.properties/;

my %ProdID_ProductRel; # Key: ProductId, Value: Array(Product, Release)
my @ProductRel;

# Load reference file, RAPID_ProductId.tsv
loadRapidIdFile(); # Fill %ProdID_ProductRel


# write as utf8 to fix an issue with print "Wide character in print at F:\scripts\Json2TxtSearchDump.pl line 74."
# Example of such character in deu_Jaws_Mis.lpu -> acadiso.pat -> JIS_LC_20A, LC JIS A 0150
#open(DUMPFILE, ">:utf8", $jsonFileForTextSearch) or die "Cannot open $jsonFileForTextSearch!\n";
# print header
my $Text_Search_Dump_Header = "resource\trestype\tenu\t$tgtlang\tid\tproduct\trelease\tsrclc";
# print UTF-8 BOM
print $Text_Search_Dump_Header . "\n";

my %ResTypeDll = ( "4" => "Menu" , "5" => "Dialog" , "6" => "String Table" , "9" => "Accelerator Table" , "11" => "Message Table" , "16" => "Version" , "23" => "HTML", "240" => "DLGINIT" ) ;

my $script_start_time = time( ) ;

my $project = jProject->read_dump_file($jsonFile);

my $prjCustomProps = $project->prj_custom_props();

my $ProductID;
my $Product;
my $Version;
my $Component;
my $DevBranch;
my $Phase;
my $SrcVersion;
my $LocVersion;
my $LocalizationType;
my $Email;

## print Project level custom properties
foreach my $props (@$prjCustomProps) {
	my @CusPropArray = @$props;
	if ($CusPropArray[0] =~ /M:LPUProductId/i) {
		$ProductID = $CusPropArray[1];
		#$Product = $products{$CusPropArray[1]};
	} elsif ($CusPropArray[0] =~ /M:LPUComponent/i) {
		$Component = $CusPropArray[1];
	} elsif ($CusPropArray[0] =~ /M:LPUDevBranch/i) {
		$DevBranch = $CusPropArray[1];
	} elsif ($CusPropArray[0] =~ /M:LPUPhase/i) {
		$Phase = $CusPropArray[1];
	} elsif ($CusPropArray[0] =~ /M:LPUSrcVersion/i) {
		$SrcVersion = $CusPropArray[1];
	} elsif ($CusPropArray[0] =~ /M:LPULocVersion/i) {
		$LocVersion = $CusPropArray[1];
	} elsif ($CusPropArray[0] =~ /M:LPULocalizationType/i) {
		$LocalizationType = $CusPropArray[1];
	} elsif ($CusPropArray[0] =~ /M:LPUEmail/i) {
		$Email = $CusPropArray[1];
	} else {
		#print "Missed a property??? -> @CusPropArray\n";
	}
}

# Get PRODUCT and RELEASE info based on M:LPUProductId
if ( exists $ProdID_ProductRel{$ProductID} ) {
	my @ProductRelease = @{$ProdID_ProductRel{$ProductID}};
	$Product = $ProductRelease[1];
	$Version = $ProductRelease[0];
}

my $strLists = $project->string_lists();

foreach my $strList (@$strLists) {
	my $lang = $strList->lang();
	my $FileName = $strList->srcFile();
#	$FileName =~ /(.*\\)(.*)/;
#	$FileName = $2;
	my $srcListId = $strList->ID();
	my $trnListId = $strList->targetID();
	my $src;
	my $trn;
	my $restype;
	my $res_num;
	my $res_name;
	my $res_parser;
	my $res_indexFirstStringInResource;
	my $res_numberStringsInResource;
	my $res_hidden;
	my $res_readonly;
	my $res_srcCustomProp;
	my $res_trnCustomProp;
	my @strArray = @{$strList->strings()};
	my $id;
	my $idext;
	my $num;
	my $numext;
	my $translationMemoryID;
	my $controlclass;
	my $comment;
	my $trans_comment;
	my $new;
	my $changed;
	my $hidden;
	my $readonly;
	my $translated;
	my $review;
	my $pretranslated;
	my $srclowercase;
	
	foreach my $str (@strArray) {
		$restype = $str->resource->restype;
		if ( $restype =~ /^\d+$/ ) {
			if (exists $ResTypeDll{$restype}) {
				$restype = $ResTypeDll{$restype};
			}
		}
		$res_num = $str->resource->number;
		$res_name = $str->resource->resname;
		$res_parser = $str->resource->resource_parser;
		$res_indexFirstStringInResource = $str->resource->firsttokenindex;
		$res_numberStringsInResource = $str->resource->tokencount;
		$res_hidden = $str->resource->state_hidden;
		$res_readonly = $str->resource->state_readonly;
		$res_srcCustomProp = $str->resource->src_cust_props;
		$res_trnCustomProp = $str->resource->trn_cust_props;
				
		$src = $str->src_text;
		$src =~ s/&amp;/\&/g;
		$src =~ s/&(\w)/$1/g;
		$src =~ s/&(\w)/$1/g;
		#$srclength = length($src);
		#$src = escapeString($src);
		$src =~ s/[\h\v]+/ /g;
		$src =~ s/\\$/\\ /g;
		$src =~ s/\\\t/\\ \t/g;
		$srclowercase = lc($src);
		$srclowercase =~ s/\\$//;
		$trn = $str->trn_text;
		$trn =~ s/&amp;/\&/g;
		$trn =~ s/&(\w)/$1/g;
		#$trn = escapeString($trn);
		$trn =~ s/[\h\v]+/ /g;
		$trn =~ s/\\$/\\ /g;
		$trn =~ s/\\\t/\\ \t/g;
		$id = $str->id;
		$id =~ s/\s+//g; 
		#$id = $lang . "_" . $id . "_" . md5_hex(uri_escape_utf8($str->src_text));
		$id = $tgtlang . "_" . $id . "_" . md5_hex(uri_escape_utf8($str->src_text));
		$idext = $str->extid;
		$num = $str->number;
		$numext = $str->extnumber;
		$translationMemoryID = $str->tm_id;
		$controlclass = $str->ctl_class;
		$comment = $str->comment;
		$comment = escapeString($comment);
		$trans_comment = $str->trans_comment;
		$trans_comment = escapeString($trans_comment);
		$new = $str->state_new;
		$changed = $str->state_changed;
		$hidden = $str->state_hidden;
		$readonly = $str->state_readonly;
		$translated = $str->state_translated;
		$review = $str->state_review;
		$pretranslated = $str->state_pretranslated;
		if( $restype && $src && $trn && $id && $aproduct && $srclowercase && !$review && ($translated || $pretranslated) && !$readonly) {
			print "Software\t$restype\t$src\t$trn\t$id\t$aproduct\t$Version\t$srclowercase\n";
		}
	}
}

exit( 1 ) ;

sub escapeString {
	my ( $string ) = @_;
	if ( $string =~ /\n|\r|\t|\^H|\"/) {
		$string =~ s/\n/ /g;
		$string =~ s/\r/ /g;
		$string =~ s/\t/ /g;
		$string =~ s/\^H/ /g;
		# This is to have excel not to break on the "
		#$string =~ s/\"/\"\"/g;
	}
	return $string;
}

sub loadRapidIdFile {
        open( PRODIDFILE , "RAPID_ProductId.tsv" ) or die "Cannot open RAPID_ProductId.tsv file!\n";
        while(<PRODIDFILE>) {
                my @line = split /\t/, $_;
                if ( ! exists $ProdID_ProductRel{$line[0]} ) {
                        my @ProdRel = ($line[9],$line[8]);
                        $ProdID_ProductRel{$line[0]} = \@ProdRel;
                }
        }
        close(PRODIDFILE);
}

