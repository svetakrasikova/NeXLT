#####################
#
# ©2011–2014 Autodesk Development Sàrl
#
# Description: This class provides interfaces to access the Project properties
#
# Created by Ravi Singh
#
# Changelog
# v2.				Modified by Ventsislav Zhechev on 02 Apr 2014
# Removed unnecessary indirection when declaring the class structure.
# Removed some unused debug code.
#
# v1.				Modified by Ravi Singh on 16 Sep 2011
#
#####################

package jProject;
use strict;

use JSON;

use jStringList;

use Class::Struct qw(struct);

struct 'jProject' => { 
	version => '$',
	res_prop_names => '$',
	string_prop_names => '$',
	prj_custom_props => '$',
	string_lists => '$'
};

sub read_dump_file {
	return unless @_;
	my $self = shift;
	my $dumpFile = shift;
	my $fh;
	my @StringListArray = ();
	
	local $/;
	
	open $fh, "<$dumpFile";
	my $json_text_decoded = decode_json(<$fh>);
	close $fh;
	
	my $hob = $self->new();  # Class::Struct made this!        
	$hob->version(shift @$json_text_decoded);
	$hob->res_prop_names(shift @$json_text_decoded);
	$hob->string_prop_names(shift @$json_text_decoded);
	$hob->prj_custom_props(shift @$json_text_decoded);
	
	foreach (@$json_text_decoded) {
		next unless @$_;
		push @StringListArray, jStringList->new(@$_);
	}
	
	$hob->string_lists(\@StringListArray);
	return $hob;
}


1;

__END__

=head1 NAME
 
 
 
 =head1 SYNOPSIS
 
 
 
 =head1 DESCRIPTION
 
 
 
 =head2 Methods
 
 
 
 =head1 EXAMPLES
 
 
 =head1 BUGS
 
 =head1 AUTHOR
 
 Ravi Singh        ravi.singh@autodesk.com
 
 =head1 VERSION
 
 Version 1.0  (Sep 16 2011)
 
 =head1 SEE ALSO
 
 perl(1)
 
 =cut