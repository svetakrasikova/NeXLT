#####################
#
# ©2011–2014 Autodesk Development Sàrl
#
# Created by Ravi Singh
#
# Changelog
# v2.				Modified by Ventsislav Zhechev on 02 Apr 2014
# Removed unnecessary indirection when declaring the class structure.
# Streamlined the getter methods.
# Removed some unused debug code.
#
# v1.				Modified by Ravi Singh on 16 Sep 2011
#
#####################

package jStringList;
use strict;

use JSON;

use jString;
use jResource;


#constructor
sub new {
	my ($class) = shift;
	
	my @strArray = ();
	my @resArray = ();
	
	my $self = {
		ID =>  shift,
		srcFile =>  shift,
		srcCustomProps =>  shift,
		targetID =>  shift,
		lang =>  shift,
		targetFile =>  shift,
		targetCustomProps =>  shift,
		strings => \@strArray,
		resources => \@resArray
	}; 
		
	my $jStringsRef = shift;
	my $jResourceRef = shift;
	
	push @strArray, jString->populate(@$_) foreach @$jStringsRef;
	
	push @resArray, jResource->populate(@$_) foreach @$jResourceRef;
	
	foreach my $res (@resArray) {
		next unless defined $res;
		my $tokenStart = $res->firsttokenindex;
		my $tokenEnd = $res->firsttokenindex + $res->tokencount - 1;
		my @strArraySubset = @strArray[$tokenStart..$tokenEnd];
		$res->strings(\@strArraySubset);
		foreach my $str (@strArraySubset) {
			next unless defined $str;
			$str->resource($res);
		}
	}   
	bless $self, $class;
	return $self;
}


#accessor method for string list ID
sub ID {
	return $_[0]->{ID};
}

#accessor method for string list source file
sub srcFile {
	return $_[0]->{srcFile};
}

#accessor method for string list CustomProps
sub srcCustomProps {
	return $_[0]->{srcCustomProps};
}

#accessor method for string list ID
sub targetID {
	return $_[0]->{targetID};
}

#accessor method for string list language
sub lang {
	return $_[0]->{lang};
}

#accessor method for string list target file
sub targetFile {
	return $_[0]->{targetFile};
}

#ADDED: accessor method for string list CustomProps
sub targetCustomProps {
	return $_[0]->{targetCustomProps};
}

#accessor method for strings in the string list
sub strings {
	return $_[0]->{strings};
}

#accessor method for resources in the string list
sub resources {
	return $_[0]->{resources};
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