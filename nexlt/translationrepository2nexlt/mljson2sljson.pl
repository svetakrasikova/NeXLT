#
# MLJson2SLJsons.pl C:\SubversionRep\jsons\LIRAFX\trunk\DLM\Main\all\All_DLM_Bin.json
#
# A Passolo JSON file is defined as following:
#	- GLOB SECTION
#	- Multiple ENU/MUI & LANG pair sections for each source and target file
#	- Closing GLOB section
#
# The script does the following:
#	1. Load the ALL JSON file into an array
#	2. Read the array to get start and end for each sections. Associates these limits to the language and source file (hash)
#	3. reads and writes the different sections into an array
#	4. writes to single language Json files in language sub-folder prefixing the "all" Json file
#	name with the corresponding language code as:
#		 C:\SubversionRep\jsons\LIRAFX\trunk\DLM\Main\deu\deu_All_DLM_Bin.json
#		 C:\SubversionRep\jsons\LIRAFX\trunk\DLM\Main\jpn\jpn_All_DLM_Bin.json
#
# Version 1.0 - 26.11.2013 - antonio.renna@autodesk.com
# Version 1.1 - 12.12.2013 - mirko.plitt@autodesk.com -- Added gre and rom, corrected directory character from DOS-style only to \ or /.
# Version 1.2 - 10.02.2014 - antonio.renna@autodesk.com (merged by mirko.plitt@autodesk.com)
#	- Fixed the rule for matching a language section (bug with ACD360MOB / WSMobile French extraction as it stopped on "fin", line)

use strict ;
use File::Basename;

my ($json) = @ARGV[0];

my @JsonArray; # array loaded with JSON file
my @SLJsonArray; # writing single language json into array for processing the last 2 lines before writing to file
my %SourceFilesAndLanguageSections; # Key1 = Language, Key2 = Source file name, Values = Index array with start ans stop of the ENUMUI-LANG sections
my $GLOBEndIndex; # End of glob section index
my %jsontgtlang; # list of languages contained in the multi-lingual JSON
my $CurrentJsonLang;

my $JsonFolder = dirname $json; # C:\SubversionRep\jsons\LIRAFX\trunk\DLM\Main\all
my $JsonFileName = basename $json; # All_DLM_Bin.json
my $JsonNeutralFolder = $JsonFolder;
$JsonNeutralFolder =~ s/[\/\\]all$//i; # C:\SubversionRep\jsons\LIRAFX\trunk\DLM\Main

# All existing languages processed through Passolo
my @languages = ("eng","deu","fra","ita","gre","rom","esp","esn","ptb","ptg","fin","nor","nld","jpn","kor","chs","cht","csy","plk","rus","hun","ara");

# Read and load the Json file in an array
open( JSON_FILE , $json );
while( <JSON_FILE> ) {
	my $currentLine = $_;
	chomp $currentLine;

	# Push into array buffer
	push @JsonArray, $currentLine;
}
close( JSON_FILE ) ;

# Set the hash of LANG/SRC FILE sections with their start?end indexes and return the index of the end of GLOB section
$GLOBEndIndex = setENUMUILANGSectionIndexes();

# Process all languages found in the multi-lingual JSON file
foreach my $tgtLang ( sort keys %jsontgtlang ) {
	print "Processing '$tgtLang'\n";
	
	# write GLOB section into SL array
	writeToSLJsonArray("0", $GLOBEndIndex);
	
	# write ENU/MUI - LANG section into SL array
	foreach my $key_lang ( sort keys %SourceFilesAndLanguageSections ) {
		if ( $key_lang =~ /$tgtLang/i ) {
			# if the language matches, go through the source file names
			foreach my $key_srcFile ( sort keys %{$SourceFilesAndLanguageSections{$key_lang}} ) {
				my $SectionIndex_ref = $SourceFilesAndLanguageSections{$key_lang}{$key_srcFile};
				my @SectionIndex = @$SectionIndex_ref;
#				print "$SectionIndex[0], $SectionIndex[1]\n";
				writeToSLJsonArray($SectionIndex[0], $SectionIndex[1]);
			}
		}
	}
	
	# Edit the last line of the last ENUMUI - LANG section where we have "]," to be changed to "]" in SL array
	my $lastIndex = scalar(@SLJsonArray);
	$SLJsonArray[$lastIndex-1] = "]\n";
	
	# Add the closing JSON GLOB section in SL array
	$SLJsonArray[$lastIndex] = "]";
	
	# Write the SL array to SL Json file
	my $JsonLangFolder = "$JsonNeutralFolder/$tgtLang";
	mkdir $JsonLangFolder;
		
	# Write into current TGT Lang JSON file
	open( SL_JSON_FILE, ">$JsonNeutralFolder/$tgtLang/${tgtLang}_$JsonFileName" );
	binmode SL_JSON_FILE ; # This will keep the end of line UNIX style as the original JSON file (\n = \x0a) Otherwise it converts them to DOS (\r\n = \x0d\x0a)
	
	foreach my $line (@SLJsonArray) {
		print SL_JSON_FILE $line;
	}
	
	close( SL_JSON_FILE );
	
	# Clean SL array
	@SLJsonArray = ();
}

########################################## SUBS ###########################################

sub setENUMUILANGSectionIndexes {
	my $ENUMUIStartIndex = 0;
	my $PreviousENUMUIStartIndex = 0;
	my $SourceFileName = "";
	my $PreviousSourceFileName = "";
	my $Lang = "";
	my $ProcessingGLOBSection = 0;
	my $GlobEndIndex = 0;
	
	for ( my $i = 0; $i < scalar(@JsonArray); $i++ ) {
		
		#print "$JsonArray[$i]\n";
		
		# if first line, then we retrieve the end of the global section = start of first section
		if ( $i == 0 ) {
			$ProcessingGLOBSection = 1;
		}
		
		# Retrieve start of ENUMUI - LANG section (corresponds to an ending one as well but not for the very last section!)
		if ( ( $JsonArray[$i-1] =~ /null,/i ) && ( $JsonArray[$i] =~ /enu\\\\|mui\\\\/i ) ) {
			$ENUMUIStartIndex = $i - 3;
				
			# Set end of GLOB section
			if ( $ProcessingGLOBSection ) {
				$GlobEndIndex = $ENUMUIStartIndex;
				$PreviousENUMUIStartIndex = $GlobEndIndex + 1;
				$PreviousSourceFileName = $SourceFileName;
				$SourceFileName = "";
				$ENUMUIStartIndex = 0;
				$ProcessingGLOBSection = 0;
			}
		}
		
		#if ( $JsonArray[$i] =~ /"eng",|"rom",|"gre",|"deu",|"fra",|"ita",|"esp",|"esn",|"ptb",|"ptg",|"fin",|"nor",|"nld",|"jpn",|"kor",|"chs",|"cht",|"csy",|"plk",|"rus",|"hun",|"ara",/i ) {
		# We need to check the 2 "language" lines to make sure we have found a language section as with previous rule,
		# the string "Fin" in French made the section to be interpreted as Finish.
		#	"cht",
		#	"mui\\AdDLMRes.dll",
		
		# For language section, there are cases where the file is generated in  mui\\AdDLMRes.dll (i.e. DLM) or enu\\ or whatever else we dont know as en-US maybe
		if ( $JsonArray[$i] =~ /".*\\.*\..*",/i ) {
			if ( $JsonArray[$i-1] =~ /"eng",|"deu",|"fra",|"ita",|"esp",|"esn",|"ptb",|"ptg",|"gre",|"rom",|"fin",|"nor",|"nld",|"jpn",|"kor",|"chs",|"cht",|"csy",|"plk",|"rus",|"hun",|"ara",/i ) {
				# Set the language
				if ( $JsonArray[$i-1] =~ /"([a-z]{3})",/i ) {
					$Lang = lc $1;
					# Store found languages
					if ( ! exists $jsontgtlang{$Lang} ) {
						$jsontgtlang{$Lang} = 1;
					}
				}
			}
		}
		
		my @ENUMUILangSection;
		# Setting the section for each ENUMUI - LANG and Source file
		if ( ( $ENUMUIStartIndex != 0 ) && ( ! exists $SourceFilesAndLanguageSections{$Lang}{$SourceFileName} ) ) {
			# Apply the indexes as found while parsing ENUMUI - LANG section
			@ENUMUILangSection = ($PreviousENUMUIStartIndex,$ENUMUIStartIndex);
#			print "$Lang - $PreviousSourceFileName - $PreviousENUMUIStartIndex, $ENUMUIStartIndex\n";
			$SourceFilesAndLanguageSections{$Lang}{$PreviousSourceFileName} = \@ENUMUILangSection;
			$PreviousENUMUIStartIndex = $ENUMUIStartIndex + 1;
			$Lang = "";
			$SourceFileName = "";
			$ENUMUIStartIndex = 0;
		}

		# When parsing the last ENUMUI - LANG section, there is no new section that will tell when the section ends.
		# The section ends with the second last index in the array. The last one being the closing GLOB section
		if ( $i == scalar(@JsonArray) - 1 ) {
			@ENUMUILangSection = ($PreviousENUMUIStartIndex,$i-1);
			$SourceFilesAndLanguageSections{$Lang}{$PreviousSourceFileName} = \@ENUMUILangSection;
#			print "$Lang - $PreviousSourceFileName - $PreviousENUMUIStartIndex, $i-1\n";
		}
		
		# This needs to happen separately from retrieving the index so that we assign the section indexes to the previous source file name
		# Set the latest source file name
		if ( ( $JsonArray[$i-1] =~ /null,/i ) && ( $JsonArray[$i] =~ /enu\\\\|mui\\\\/i ) ) {
			$PreviousSourceFileName = $JsonArray[$i];
		}
	}
	return $GlobEndIndex;
}

sub writeToSLJsonArray {
	my ($startIndex, $EndIndex) = @_;
	for ( my $i = $startIndex; $i <= $EndIndex; $i++ ) {
		my $stringToWrite = $JsonArray[$i];
		# The very last section of ENUMUI - LANG section doesn't end with a comma as "],", so lets add it when missing
		# When writing the last section, we will need to remove it to have "]"
		if ( ( $i == $EndIndex ) && ( $JsonArray[$i] eq "]" ) ) {
			$stringToWrite = $stringToWrite . ",";
		}
		push @SLJsonArray, "$stringToWrite\n";
	}
}

