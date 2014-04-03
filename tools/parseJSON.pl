#!/usr/bin/perl -ws
#####################
#
# ©2014 Autodesk Development Sàrl
#
# Based on json2solr.pl by Mirko Plitt
#
# Changelog
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

use jProject;

our ($threads);
$threads ||= 8;

my %ProdID_ProductRel; # Key: ProductId, Value: Array(Product, Release)
# Load reference file, RAPID_ProductId.tsv
open( PRODIDFILE , "/OptiBay/SW_JSONs/tools/RAPID_ProductId.tsv" ) or die "Cannot open RAPID_ProductId.tsv file!\n";
while(<PRODIDFILE>) {
	my @line = split /\t/, $_;
	$ProdID_ProductRel{$line[0]} = [$line[9],$line[8]] unless exists $ProdID_ProductRel{$line[0]};
}
close(PRODIDFILE);
print STDERR "RAPID file loaded.\n";

my %ResTypeDll = ( "4" => "Menu" , "5" => "Dialog" , "6" => "String Table" , "9" => "Accelerator Table" , "11" => "Message Table" , "16" => "Version" , "23" => "HTML", "240" => "DLGINIT" );

my @workers;
my $fileQueue = new Thread::Queue;
my %languageQueues :shared;

my $printer = sub {
	my $language = shift;
	{ lock %languageQueues;
		return unless defined $languageQueues{$language};
	}
	
	my $out = IO::Compress::Bzip2->new("/OptiBay/SW_JSONs/corpus/corpus.sw.$language.bz2");
	while (my $data = $languageQueues{$language}->dequeue()) {
		print $out encode "utf-8", $data;
	}
	close $out;
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
				push @workers, threads->create($printer, $language);
			}
		}
	}
	$languageQueues{$language}->enqueue(shift);
}

my $processJSON = sub {
	while (my $jsonFile = $fileQueue->dequeue()) {
		my ($product) = $jsonFile =~ m!/OptiBay/SW_JSONs/(\w+)/!;

		print STDERR threads->tid().": Parsing $jsonFile.\n";
		my $project = jProject->read_dump_file($jsonFile);
		print STDERR threads->tid().": $jsonFile parsed.\tOutputting strings.\n";
		
		foreach my $strList (@{$project->string_lists}) {
			my $lang = $strList->lang;
			my $src;
			my $trn;
			my $restype;
			
			foreach my $str (@{$strList->strings}) {
				#Short-circuit exit conditions
				next if $str->src_text =~ /^\s*$/ ||
								$str->trn_text =~ /^\s*$/ ||
								$str->id =~ /^\s*$/ ||
								$str->state_review ||
								$str->state_readonly ||
								(!$str->state_translated && !$str->state_pretranslated);
				
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
				
				printForLanguage $lang, "$src$trn$product◊÷\n";
			}
		}
		print STDERR threads->tid().": $jsonFile processing finished.\n";
	}
};

@workers = map { scalar threads->create($processJSON) } 1..$threads;

my @jsons = find(sub {$fileQueue->enqueue($File::Find::name) if /.json$/}, "/OptiBay/SW_JSONs");

#Notify the worker threads that we’ve finished processing
$fileQueue->enqueue(undef) foreach 1..$threads;
$languageQueues{$_}->enqueue(undef) foreach keys %languageQueues;
$_->join foreach @workers;



1;