#####################
#
# ©2011–2014 Autodesk Development Sàrl
#
# Description: This class provides interfaces to access the Resource properties within a String List
#
# Created by Ravi Singh
#
# Changelog
# v2.				Modified by Ventsislav Zhechev on 02 Apr 2014
# Streamlined the getter method.
#
# v1.				Modified by Ravi Singh
#
#####################

package jResource;
use strict;

use Class::Struct qw(struct);

struct 'jResource' => { 
	number    =>  '$',
	restype    =>  '$',
	resname    =>  '$',
	resource_parser    =>  '$',
	firsttokenindex    =>  '$',
	tokencount    =>  '$',
	state_hidden    =>  '$',
	state_readonly    =>  '$',
	src_cust_props    =>  '$',
	trn_cust_props    =>  '$',
	strings =>  '$'
};


sub populate {
	return unless @_;
	my $self = shift;
	my $hob = $self->new();  # Class::Struct made this!        
	$hob->number(shift);
	$hob->restype(shift);
	$hob->resname(shift);
	$hob->resource_parser(shift);
	$hob->firsttokenindex(shift);
	$hob->tokencount(shift);       
	$hob->state_hidden(shift);
	$hob->state_readonly(shift);
	$hob->src_cust_props(shift);
	$hob->trn_cust_props(shift);
	return $hob;
}


sub translatable {
	return !$_[0]->state_hidden && !$_[0]->state_readonly;
}

1;