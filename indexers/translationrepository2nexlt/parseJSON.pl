#!/usr/local/bin/perl -ws
#####################
#
# ©2014–2015 Autodesk Development Sàrl
#
# Based on json2solr.pl by Mirko Plitt
#
# Changelog
# v1.3		Modified by Ventsislav Zhechev on 23 Jan 2015
# Added a mode for submitting processed JSON data to Solr for indexing, including the option to provide a timestamp file.
# Product meta data is now loaded directly from RAPID for all modes.
# Improved CSV output based on Text::CSV.
# Moved over from /tools
#
# v1.2.1	Modified by Ventsislav Zhechev on 12 Jan 2015
# Fixed a bug where the wrong part of a file’s path would be taken as the product code, when operating in the -moses mode.
#
# v1.2		Modified by Samuel Läubli on 13 October 2014
# Removed static path to Passolo root directory and replaced it with a command line argument (-jsonDir).
# Added option to parse a single JSON file (using -jsonFile)
# Added tab-separated CSV as output format (use -format=csv or -format=moses).
# Added command line arguments for product name (-product) and release (-release).
# 
# v1.1.1	Modified by Ventsislav Zhechev on 17 May 2014
# Added a character limit to source and target strings.
# Relocated the language renaming that fixes some JSON file contents.
#
# v1.1		Modified by Ventsislav Zhechev on 04 Apr 2014
# Switched to incremental parsing of the JSON files—processing one string list at a time.
# Switched to batch printing to reduce the number of subroutine calls.
# Added progress output.
#
# v1.			Modified by Ventsislav Zhechev on 03 Apr 2014
# Initial version
#
#####################

use strict;
use utf8;

use threads;
use threads::shared;
use Thread::Queue;

use Encode qw/encode/;
use File::Find;
use File::Spec;
use File::Basename;
use Cwd;
use IO::Compress::Bzip2;

use Text::CSV::Encoded;
use JSON::XS;
use jString;

use HTTP::Tiny;
use URI::Escape;
use Digest::MD5 qw(md5 md5_hex md5_base64);

use DBI;


our ($threads, $jsonFile, $jsonDir, $targetDir, $format, $product, $release, $lastUpdateFile);
$threads ||= 8;
$format ||= 'moses';
die encode "utf-8", "Error: -format must be either ‘moses’ or ‘csv’ or ‘solr’.\n"
unless ($format eq 'moses' or $format eq 'csv' or $format eq "solr");
$targetDir = getcwd() unless defined $targetDir; # use current directory by default
die "Error: Either a single Passolo JSON file or a directory containing (SVN repositories with) Passolo JSON files must be provided via the -jsonFile or -jsonDir argument, respectively.\n"
unless (defined $jsonFile or defined $jsonDir);
#if ($format eq 'csv') {
#	print STDERR "Warning: No product name specified (parameter -product is undefined).\n" 
#	unless defined $product;
#	print STDERR "Warning: No release specified (parameter -release is undefined).\n"
#	unless defined $release;
#}

$| = 1;
select STDERR;
$| = 1;

my $http = HTTP::Tiny->new(agent => "SW JSON Indexer", default_headers => {"Content-type" => "application/json; charset=utf-8"});

$ENV{'NLS_LANG'} = 'AMERICAN_SWITZERLAND.UTF8'; # needed to fetch perl-ready bytecode data from the DB

# DB Connection Parameters (RAPID: LSPRD)
my $DB_PORT = 1528;
my $DB_HOST="oralsprd.autodesk.com";
my $DB_SERVICE_NAME = "LSPRD.autodesk.com";
my $DB_USER = "wwl_lcm_read";
my $DB_PASSWORD = "lcm_r3ad";

my @workers :shared;
my $fileQueue = new Thread::Queue;
my %languageQueues :shared;
my %ResTypeDll = ( "4" => "Menu" , "5" => "Dialog" , "6" => "String Table" , "9" => "Accelerator Table" , "11" => "Message Table" , "16" => "Version" , "23" => "HTML", "240" => "DLGINIT" );

my $postToSolr = sub {
	my $content = shift;
	my $response = $http->request('POST', 'http://aws.prd.solr:8983/solr/update/json', { content => $content });
#	my $response = $http->request('POST', 'http://aws.stg.solr:8983/solr/update/json', { content => $content });
	die encode "utf-8", "HTML request to Solr failed!\n $response->{status} $response->{reason}\n$response->{content}\nContent submitted:\n$content\n" unless $response->{success};
};

my $printer = sub {
	my $language = shift;
	{ lock %languageQueues;
		return unless defined $languageQueues{$language};
	}

	my $counter = 0;
	if ($format eq 'moses') {
		my $out = IO::Compress::Bzip2->new(File::Spec->catfile($targetDir, "corpus.sw.$language.bz2"));
		# write data for Moses training
		while (my $data = $languageQueues{$language}->dequeue()) {
			print $out encode "utf-8", $data->[0];
			$counter += $data->[1];
		}
		close $out;
	} elsif ($format eq "csv") {
		my $csv = Text::CSV::Encoded->new({binary => 1, sep_char => "\t", eol => $/, encoding_out => "utf-8"});
		open(my $out, '>', File::Spec->catfile($targetDir, "corpus.sw.$language.csv"));
		# write CSV header
#		print $out encode "utf-8", join("\t", 'resource', 'restype', 'enu', $language, 'id', 'product', 'release', 'srclc') . "\n";
		$csv->print($out, ["resource", "restype", "enu", $language, "id", "product", "release", "srclc"]);
		# write CSV data
		while (my $data = $languageQueues{$language}->dequeue()) {
#			print $out encode "utf-8", $data->[0];
			$csv->print($out, $_) foreach @{$data->[0]};
			$counter += $data->[1];
		}
		close $out;
	} elsif ($format eq "solr") {
		my $jsonEncoder = JSON::XS->new->allow_nonref;
		my $content = '{ ';
		while (my $data = $languageQueues{$language}->dequeue()) {
			foreach my $data (@{$data->[0]}) {
				if ($counter > 0 && $counter % 25000 == 0) {
					$content .= ', "commit": {} }';
					print STDERR encode "utf-8", "Posting $language content for indexing ($counter)…\n";
					&$postToSolr($content);
					print STDERR encode "utf-8", "$language content sucessfully posted!\n";
					$content = '{ ';
				}
				unless ($counter % 25000 == 0) {
					$content .= ', '."\n";
				}
				++$counter;
				if ($data->{productName} =~ /\[\"/) {
					$content .= encode "utf-8",
					'"add": { "doc": { "resource": {"set":"Software"}, '.
					'"product": {"set":'.$jsonEncoder->encode($data->{product}).'}, '.
					'"productname": {"set":'.$data->{productName}.'}, '.
					'"release": {"set":'.$jsonEncoder->encode($data->{version}).'}, '.
					'"id": "'.$data->{id}.'", '.
					'"restype": {"set":'.$jsonEncoder->encode($data->{restype}).'}, '.
					'"enu": {"set":'.$jsonEncoder->encode($data->{enu}).'}, '.
					'"'.$language.'": {"set":'.$jsonEncoder->encode($data->{$language}).'}, '.
					'"srclc": {"set":'.$jsonEncoder->encode($data->{srclc}).'} '.
					'} }';
				} else {
					$content .= encode "utf-8",
					'"add": { "doc": { "resource": {"set":"Software"}, '.
					'"product": {"set":'.$jsonEncoder->encode($data->{product}).'}, '.
					'"productname": {"remove":'.$jsonEncoder->encode($data->{productName}).'}, '.
					'"release": {"set":'.$jsonEncoder->encode($data->{version}).'}, '.
					'"id": "'.$data->{id}.'", '.
					'"restype": {"set":'.$jsonEncoder->encode($data->{restype}).'}, '.
					'"enu": {"set":'.$jsonEncoder->encode($data->{enu}).'}, '.
					'"'.$language.'": {"set":'.$jsonEncoder->encode($data->{$language}).'}, '.
					'"srclc": {"set":'.$jsonEncoder->encode($data->{srclc}).'} '.
					'} },'.
					'"add": { "doc": { "id": "'.$data->{id}.'", '.
					'"productname": {"add":'.$jsonEncoder->encode($data->{productName}).'} '.
					'} }';
				}
			}
		}
		$content .= ', "commit": {} }';
		print STDERR encode "utf-8", "Posting $language content for indexing ($counter)…\n";
		&$postToSolr($content);
		print STDERR encode "utf-8", "$language content sucessfully posted!\n";
	}
	print STDERR threads->tid().": Output $counter segments for language $language.\n";
};

sub printForLanguage {
	my $language = shift;
	unless (exists $languageQueues{$language}) {
		{ lock %languageQueues;
			unless (exists $languageQueues{$language}) {
				print STDERR "Starting thread for outputting $language.\n";
				$languageQueues{$language} = new Thread::Queue;
				push @workers, shared_clone(threads->create($printer, $language));
			}
		}
	}
	$languageQueues{$language}->enqueue([@_]);
}

my $processJSON = sub {
	my $rapidDB = DBI->connect("dbi:Oracle:SERVICE_NAME=$DB_SERVICE_NAME;host=$DB_HOST;port=$DB_PORT", $DB_USER, $DB_PASSWORD, { RaiseError => 1, AutoCommit => 0, RowCacheSize => 50, AutoInactiveDestroy => 1 });
	my $jsonEncoder = JSON::XS->new->allow_nonref;
	
	while (my $currentJSONFile = $fileQueue->dequeue()) {
		next unless $format ne "solr" || $currentJSONFile =~ m!trunk/!;
		# extract product name from path (if working with a jsonDir)
		($product) = $currentJSONFile =~ m/\/(\w+)\/trunk/g if defined $jsonDir;
		
		print STDERR encode "utf-8", threads->tid().": Parsing $currentJSONFile. ($product)\n";

		my $json = new JSON::XS;

		my ($Version, $Product, $ProductName);
		
		open my $fh, "<$currentJSONFile";
		# first parse the initial "["
		my $done = 0;
		for (;;) {
      my $charsRead = sysread $fh, my $buf, 65536;
			die "read error: $!" unless defined $charsRead;
			unless ($charsRead) {
				$done = 1;
				print STDERR "1. EOF found for $currentJSONFile\n";
				last;
			}
			$json->incr_parse($buf);
			last if $json->incr_text =~ s#^\s*\[.*?\[#[#s;
				;
		}
		my $skipCount = 1;
		my %prjCustomProps;
		while (!$done) {
			# in this loop we read data until we got a JSON object
			for (;;) {
				if (my $data = $json->incr_parse) {
					# Skip four first arrays, as they only contain metadata.
					last if ++$skipCount <= 3;
					if ($skipCount == 4) {
						%prjCustomProps = map{$_->[0] => $_->[1]} @$data;
						if (defined $prjCustomProps{"M:LPUProductId"} && $prjCustomProps{"M:LPUProductId"} > 0) {
							my $productData = $rapidDB->selectrow_arrayref("select VERSION, MTSHORTNAME, PRODUCT_RELEASED from WWL_SPS.GET_NEXLT_PROJECT_INFO where ID_REL_PROJECT = '$prjCustomProps{'M:LPUProductId'}'");
							($Version, $Product, $ProductName) = @$productData;
						} else {
							print STDERR encode "utf-8", "ID_REL_PROJECT not found for file ‘$currentJSONFile’!\n";
							my $productQuery = $rapidDB->prepare("select distinct MTSHORTNAME, PRODUCT_RELEASED from WWL_SPS.GET_NEXLT_PROJECT_INFO where SWSHORTNAME = '$product'");
							$productQuery->execute();
							my $productData = $productQuery->fetch();
							if (defined $productData) {
								$Product = $productData->[0];
								$ProductName = "[".$jsonEncoder->encode($productData->[1]);
								while ($productData = $productQuery->fetch()) {
									$ProductName .= ",".$jsonEncoder->encode($productData->[1]);
									$Product ||= $productData->[0];
								}
								$ProductName .= "]";
							} else {
								print STDERR encode "utf-8", "SWSHORTNAME not found for file ‘$currentJSONFile’!\n";
								$ProductName = $Product = $product;
							}
						}
						unless (defined $Version) {
							#Set $Version to current year plus one
							(undef, undef, undef, undef, undef, $Version) = localtime();
							++$Version;
						}
						unless (defined $Product) {
							print STDERR encode "utf-8", "MTSHORTNAME not found for file ‘$currentJSONFile’!\n";
							$Product = $product;
						}
						last;
					}

					last unless @$data;
					
					my $lang = $data->[4];
					#Fix some bugs in the JSON files.
					$lang = "esp" if $lang eq "esn";
					$lang = "eng" if $lang eq "enu";
					$lang = "tur" if $lang eq "trk";
					my ($src, $trn, $id);
					my $resource = $data->[1];
					$resource =~ s/.*\\(.*)/$1/;
					my $restype = $data->[8]->[0]->[1] || "";
					$restype = $ResTypeDll{$restype} if defined $ResTypeDll{$restype};
#					print STDERR encode "utf-8", "No restype specified in file ‘$currentJSONFile’!\n" if $restype eq "";
					
					my $toPrint = $format ne "moses" ? [] : "";
					my $counter = 0;
					
					foreach my $str (@{$data->[7]}) {
						$str = jString->populate(@$str);
						#Short-circuit exit conditions
						next if $str->src_text =~ /^\s*$/ ||
							$str->trn_text =~ /^\s*$/ ||
							$str->id =~ /^\s*$/ ||
							$str->state_review ||
							$str->state_readonly ||
							(!$str->state_translated && !$str->state_pretranslated);
						
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
						
						if ($format eq 'moses') {
							$toPrint .= "$src$trn$Product◊÷\n";
						} elsif ($format eq 'csv') {
							# note: product and release my be provided as command line arguments, but will also be retrieved from RAPID based on available metadata
#							$toPrint .= formatCSVRow($resource, $restype, $src, $trn, $str->id, $product || $Product, $release || $Version, lc $src);
							push @$toPrint, [$resource, $restype, $src, $trn, $str->id, $product || $Product, $release || $Version, lc $src];
						} elsif ($format eq "solr") {
							$id = md5_hex(uri_escape_utf8($str->id."$src$resource$restype$Product"))."Software";

							push @$toPrint, {
								id			=> $id,
								restype	=> $restype,
								enu			=> $src,
								$lang		=> $trn,
								srclc		=> lc($src),
								version => $Version,
								product => $Product,
								productName => $ProductName,
							};
						}
						++$counter;
					}
					printForLanguage $lang, $toPrint, $counter if $counter;
					last;
				}
				
				# add more data
				my $charsRead = sysread $fh, my $buf, 65536;
				die "read error: $!" unless defined $charsRead;
				unless ($charsRead) {
					$done = 1;
					print STDERR "2. EOF found for $currentJSONFile\n";
					last;
				}
				$json->incr_parse($buf); # void context, so no parsing
			}
			
			# in this loop we read data until we either found and parsed the
			# separating "," between elements, or the final "]"
			while (!$done) {
				# if we find "]", we are done
				if ($json->incr_text =~ m"^\s*\]") {
					$done = 1;
					last;
				}
				# if we find ",", we can continue with the next element
				last if $json->incr_text =~ s/^\s*,//;
				# if we find anything else, we have a parse error!
				die "parse error near ", $json->incr_text if length $json->incr_text;
				
				# else add more data
				my $charsRead = sysread $fh, my $buf, 65536;
				die "read error: $!" unless defined $charsRead;
				unless ($charsRead) {
					$done = 1;
					print STDERR "3. EOF found for $currentJSONFile\n";
					last;
				}
				$json->incr_parse($buf); # void context, so no parsing
			}
		}
		close $fh;
		print STDERR threads->tid().": $currentJSONFile processing finished.\n";
		
		my $filesLeft = $fileQueue->pending();
		print STDERR threads->tid().": $filesLeft files left to process.\n" if $filesLeft && !($filesLeft % 10);
	}
	print STDERR threads->tid().": Finished work!\n";
	
	$rapidDB->disconnect();
};

#sub formatCSVRow {
#	# @param: array of fields
#	# return
#	my $csvRow = '';
#	foreach my $field (@_) {
#		$field =~ tr/\t/ /; #TODO: Better escaping for \t ?
#		$csvRow .= "$field\t"; # fields are separated by \t
#	}
#	chop($csvRow); #remove last comma
#	return $csvRow . "\n";
#}
#

#Launch the desired number of worker threads.
@workers = @{shared_clone ([map { scalar threads->create($processJSON) } 1..$threads])};

#Find all files that should be processed.
if ($jsonDir) {
	find(sub {$fileQueue->enqueue($File::Find::name) if /\.json$/ && (!defined $lastUpdateFile || -M $lastUpdateFile >= -M $_)}, $jsonDir);
} else {
	$fileQueue->enqueue($jsonFile);
}

#Notify the file worker threads that we’ve finished processing
$fileQueue->enqueue(undef) foreach 1..$threads;
$_->join foreach @workers[0..($threads-1)];

#Notify the per-language printer threads that we’ve finished processing
$languageQueues{$_}->enqueue(undef) foreach keys %languageQueues;
$_->join foreach @workers[$threads..$#workers];


1;