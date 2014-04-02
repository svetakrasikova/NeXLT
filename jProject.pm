# class jProject
# Description: This class provides interfaces to access the Project properties

package jProject;
use strict;

use JSON;

use jStringList;

use Class::Struct qw(struct);

struct 'jProject' => { 
        version    =>  '$',
        res_prop_names    =>  '$',
        string_prop_names    =>  '$',
        prj_custom_props    =>  '$',
        string_lists =>  '$'
};

sub read_dump_file {
	return unless @_;
	my ( $self ) = shift;
	my ($dumpFile) = shift;
	my $fh;
	my @StringListArray = ();

	local $/;

	open($fh, "$dumpFile");
	my $json_text   = <$fh>;
	my $json_text_decoded = decode_json( $json_text );

	my @jsonRootArray = @$json_text_decoded;
        	
	my $hob = $self->new();  # Class::Struct made this!        
	$hob->version(shift @jsonRootArray);
	$hob->res_prop_names(shift @jsonRootArray);
	$hob->string_prop_names(shift @jsonRootArray);
	$hob->prj_custom_props(shift @jsonRootArray);
	
	foreach (@jsonRootArray) {
		my @stringList = @$_;
		next if ($#stringList == -1);
		push @StringListArray, jStringList->new(@stringList);
	}
    
	$hob->string_lists(\@StringListArray);
	return $hob;
}

## Return JSON file version
## my $json_version = jProject->version();

## Return array of Project custom properties
## my $prj_custom_props = jProject->prj_custom_props();
## 
## This array contains each project custom property key-value pair as an individual
## array as demonstrated below
=head
	[
		[
		20000,
		"This is test."
		],
		[
		"U:NewUserProp",
		"This is new property."
		]
	],
=cut

1;

__END__

=head1 NAME



=head1 SYNOPSIS
    


=head1 DESCRIPTION



=head2 Methods



=head1 EXAMPLES

Run these code snippets to get a quick feel for the behavior of this
module.  

=head1 BUGS

=head1 AUTHOR

Ravi Singh        ravi.singh@autodesk.com

=head1 VERSION

Version 1.0  (Sep 16 2011)

=head1 SEE ALSO

perl(1)

=cut