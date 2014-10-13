#!/usr/bin/perl -ws
#####################
#
# ©2014 Autodesk Development Sàrl
#
# Based on json2solr.pl by Mirko Plitt
#
# Changelog
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

use JSON::XS;
use jString;

our ($threads, $jsonFile, $jsonDir, $targetDir, $format, $product, $release);
$threads ||= 8;
$format ||= 'moses';
die "Error: -format must be either 'moses' or 'csv'.\n"
	unless ($format eq 'moses' or $format eq 'csv');
$targetDir = getcwd()
	unless defined $targetDir; # use current directory by default
die "Error: Either a single Passolo JSON file or a directory containing Passolo JSON files must be provided via the -jsonFile or -jsonDir argument, respectively.\n"
	unless (defined $jsonFile or defined $jsonDir);
if ($format eq 'csv') {
	print STDERR "Warning: No product name specified (parameter -product is undefined).\n"
		unless (defined $product or defined $jsonDir);
	print STDERR "Warning: No release specified (parameter -release is undefined).\n"
		unless defined $release;
}

$| = 1;
select STDERR;
$| = 1;

my @workers :shared;
my $fileQueue = new Thread::Queue;
my %languageQueues :shared;

my $printer = sub {
	my $language = shift;
	{ lock %languageQueues;
		return unless defined $languageQueues{$language};
	}
	
	my $counter = 0;
	if ($format eq 'moses') {
		my $out = IO::Compress::Bzip2->new( File::Spec->catfile($targetDir,"corpus.sw.$language.bz2") );
		# write data for Moses training
		while (my $data = $languageQueues{$language}->dequeue()) {
			print $out encode "utf-8", $data->[0];
			$counter += $data->[1];
		}
		close $out;
	} else {
		open( my $out, '>', File::Spec->catfile($targetDir, "corpus.sw.$language.csv") );
		# write CSV header
		print $out encode "utf-8", join("\t", 'resource', 'restype', 'enu', $language, 'id', 'product', 'release', 'srclc') . "\n";
		# write CSV data
		while (my $data = $languageQueues{$language}->dequeue()) {
			print $out encode "utf-8", $data->[0];
			$counter += $data->[1];
		}
		close $out;
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
	while (my $currentJSONFile = $fileQueue->dequeue()) {
		
		# extract product name from path (if not given as a command line argument)
		if (defined $jsonDir) {
			($product) = File::Spec->catfile($jsonDir, $currentJSONFile) =~ m/trunk\/(\w+)\//g
				unless defined $product;
		}
		
		print STDERR threads->tid().": Parsing $currentJSONFile.\n";

		my $json = new JSON::XS;
				
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
		while (!$done) {
			# in this loop we read data until we got a JSON object
			for (;;) {
				if (my $data = $json->incr_parse) {
					# Skip four first arrays, as they only contain metadata.
					last if ++$skipCount <= 4;

					last unless @$data;
					
					my $lang = $data->[4];
						#Fix some bugs in the JSON files.
						$lang = "esp" if $lang eq "esn";
						$lang = "eng" if $lang eq "enu";
					my $src;
					my $trn;
					my $resource = $data->[1];
						$resource =~ s/.*\\(.*)/$1/;
					my $restype = $data->[8]->[0]->[1];				
					
					my $toPrint = "";
					my $counter = 0;
					
					#print Dumper $data;
					
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
							$toPrint .= "$src$trn$product◊÷\n";
						} elsif ($format eq 'csv') {
							# note: product and release are not extracted from the JSON file
							#       they are provided as command line arguments
							my @fields = ($resource, $restype, $src, $trn, $str->id, $product, $release, lc $src);
							$toPrint .= formatCSVRow(@fields);
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
};

sub formatCSVRow {
	# @param: array of fields
	# return
	my $csvRow = '';
	foreach my $field (@_) {
		$field =~ s/\t/ /; #TODO: Better escaping for \t ?
		$csvRow .= "$field\t"; # fields are separated by \t
	}
	chop($csvRow); #remove last comma
	return $csvRow . "\n";
}

#Launch the desired number of worker threads.
@workers = @{shared_clone ([map { scalar threads->create($processJSON) } 1..$threads])};

#Find all files that should be processed.
if ($jsonDir) {
	find(sub {$fileQueue->enqueue($File::Find::name) if /.json$/}, $jsonDir);
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