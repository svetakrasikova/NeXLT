#####################
#
# ©2011–2014 Autodesk Development Sàrl
#
# Created by Ravi Singh
#
# Description: This class provides interfaces to access the String properties within a String List
#
# Changelog
# v2.				Modified by Ventsislav Zhechev on 02 Apr 2014
# Streamlined the getter methods.
#
# v1.				Modified by Ravi Singh
#
#####################

package jString;
use strict;

use Class::Struct qw(struct);


struct 'jString' => { 
	id    =>  '$',
	extid    =>  '$',
	number    =>  '$',
	extnumber    =>  '$',
	tm_id    =>  '$',
	variable_id    =>  '$',
	ctl_class    =>  '$',
	src_text    =>  '$',
	#src_text_notag    =>  '$',
	oldtext    =>  '$',
	trn_text    =>  '$',
	#trn_text_notag    =>  '$',
	comment    =>  '$',
	trans_comment    =>  '$',
	state_new    =>  '$',
	state_changed    =>  '$',
	state_hidden    =>  '$',
	state_readonly    =>  '$',
	state_translated    =>  '$',
	state_review    =>  '$',
	state_pretranslated =>  '$',
	resource    =>  '$'
};


sub populate {
	return unless @_;
	my $self = shift;
	my $hob = $self->new();  # Class::Struct made this!
	#print "---HOB:$hob---\n";
	$hob->id(shift);
	$hob->extid(shift);
	$hob->number(shift);
	$hob->extnumber(shift);
	$hob->tm_id(shift);
	$hob->variable_id(shift);
	$hob->ctl_class(shift);
	# get src_text and process Passolo html tags (start and end)
	$hob->src_text(parseTag(shift));
	#$hob->src_text_notag(shift);
	# get src_text and process Passolo html tags (start and end)
	$hob->oldtext(parseTag(shift));
	# get src_text and process Passolo html tags (start and end)
	$hob->trn_text(parseTag(shift));
	#$hob->trn_text_notag(shift);
	$hob->comment(shift);
	$hob->trans_comment(shift);
	$hob->state_new(shift);
	$hob->state_changed(shift);
	$hob->state_hidden(shift);
	$hob->state_readonly(shift);
	$hob->state_translated(shift);
	$hob->state_review(shift);
	$hob->state_pretranslated(shift);
	return $hob;
}

sub isReadOnly{
	return $_[0]->state_readonly || $_[0]->resource->state_readonly;
}

sub isHidden {
	return $_[0]->state_hidden || $_[0]->resource->state_hidden;
}

sub translatable {
	return $_[0]->resource->translatable && !$_[0]->isHidden && !$_[0]->isReadOnly;
}

sub parseTag{
	my ( $string ) = @_;
	my $starttag = "\2";
	my $endtag = "\3";
	if ($string =~ /$starttag/) {
		$string =~ s/$starttag$endtag//g;
		$string =~ s/$starttag.*?$endtag//g;
	}
	return $string;
}

1;