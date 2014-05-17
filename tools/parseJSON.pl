#!/usr/bin/perl -ws
#####################
#
# ©2014 Autodesk Development Sàrl
#
# Based on json2solr.pl by Mirko Plitt
#
# Changelog
# v1.1.1	Modified by Ventsislav Zhechev on 17 May 2014
# Added a character limit to source and target strings.
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
use IO::Compress::Bzip2;

use JSON::XS;
use jString;

our ($threads);
$threads ||= 8;

$| = 1;
select STDERR;
$| = 1;

#my %ResTypeDll = ( "4" => "Menu" , "5" => "Dialog" , "6" => "String Table" , "9" => "Accelerator Table" , "11" => "Message Table" , "16" => "Version" , "23" => "HTML", "240" => "DLGINIT" );

my @workers :shared;
my $fileQueue = new Thread::Queue;
my %languageQueues :shared;

my $printer = sub {
	my $language = shift;
	{ lock %languageQueues;
		return unless defined $languageQueues{$language};
	}
	
	my $counter = 0;
	my $out = IO::Compress::Bzip2->new("/OptiBay/SW_JSONs/corpus/corpus.sw.$language.bz2");
	while (my $data = $languageQueues{$language}->dequeue()) {
		print $out encode "utf-8", $data->[0];
		$counter += $data->[1];
	}
	close $out;
	print STDERR threads->tid().": Output $counter segments for language $language.\n";
};

sub printForLanguage {
	my $language = shift;
	#Fix some bugs in the JSON files.
	$language = "esp" if $language eq "esn";
	$language = "eng" if $language eq "enu";
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
	while (my $jsonFile = $fileQueue->dequeue()) {
		my ($product) = $jsonFile =~ m!/OptiBay/SW_JSONs/(\w+)/!;

		print STDERR threads->tid().": Parsing $jsonFile.\n";

		my $json = new JSON::XS;
				
		open my $fh, "<$jsonFile";
		# first parse the initial "["
		my $done = 0;
		for (;;) {
      my $charsRead = sysread $fh, my $buf, 65536;
			die "read error: $!" unless defined $charsRead;
			unless ($charsRead) {
				$done = 1;
				print STDERR "1. EOF found for $jsonFile\n";
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
					my $src;
					my $trn;
#					my $restype;
					
					my $toPrint = "";
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
						
						#TODO: implement this type of check, without using jStringList.pm
#						$restype = exists $ResTypeDll{$str->resource->restype} && $str->resource->restype =~ /^\d+$/ ? $ResTypeDll{$str->resource->restype} : $str->resource->restype;
#						next unless $restype;
						
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
						
						$toPrint .= "$src$trn$product◊÷\n";
						++$counter;
					}
#					print STDERR encode "utf-8", threads->tid().": Printing for language $lang:\n$toPrint\n";
					printForLanguage $lang, $toPrint, $counter if $counter;
					last;
				}
				
				# add more data
				my $charsRead = sysread $fh, my $buf, 65536;
				die "read error: $!" unless defined $charsRead;
				unless ($charsRead) {
					$done = 1;
					print STDERR "2. EOF found for $jsonFile\n";
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
					print STDERR "3. EOF found for $jsonFile\n";
					last;
				}
				$json->incr_parse($buf); # void context, so no parsing
			}
		}
		close $fh;
		print STDERR threads->tid().": $jsonFile processing finished.\n";
		
		my $filesLeft = $fileQueue->pending();
		print STDERR threads->tid().": $filesLeft files left to process.\n" if $filesLeft && !($filesLeft % 10);
	}
	print STDERR threads->tid().": Finished work!\n";
};

#Launch the desired number of worker threads.
@workers = @{shared_clone ([map { scalar threads->create($processJSON) } 1..$threads])};

#Find all files that should be processed.
my @jsons = find(sub {$fileQueue->enqueue($File::Find::name) if /.json$/}, "/OptiBay/SW_JSONs");

#Notify the file worker threads that we’ve finished processing
$fileQueue->enqueue(undef) foreach 1..$threads;
$_->join foreach @workers[0..($threads-1)];

#Notify the per-language printer threads that we’ve finished processing
$languageQueues{$_}->enqueue(undef) foreach keys %languageQueues;
$_->join foreach @workers[$threads..$#workers];



1;