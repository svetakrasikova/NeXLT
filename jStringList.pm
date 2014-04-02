#class jStringList
package jStringList;
use strict;

use JSON;

use jString;
use jResource;

my %StringListFields = (
"ID"    =>  "ID",
"srcFile"   =>  "srcFile",
"srcCustomProps"    =>  "srcCustomProps",
"targetID"    =>  "targetID",
"lang"  =>  "lang",
"targetFile"    =>  "targetFile",
"targetCustomProps"    =>  "targetCustomProps",
"strings"   =>  "strings",
"resources" =>  "resources"
);



#constructor
sub new {
    my ($class) = shift;
    
    my @strArray = ();
    my @resArray = ();
             
    my $self = {
        $StringListFields{"ID"} =>  shift,
        $StringListFields{"srcFile"} =>  shift,
        $StringListFields{"srcCustomProps"} =>  shift,
        $StringListFields{"targetID"} =>  shift,
        $StringListFields{"lang"} =>  shift,
        $StringListFields{"targetFile"} =>  shift,
        $StringListFields{"targetCustomProps"} =>  shift,
        $StringListFields{"strings"} => \@strArray,
        $StringListFields{"resources"} => \@resArray
    }; 
    
    #print "props: " . $self->{$StringListFields{"targetCustomProps"}} . "\n";
    
    #$self{$StringListFields{"strings"}} = \@strArray;
    #$self{$StringListFields{"resources"}} = \@resArray;
    
    my $jStringsRef = shift;
    my $jResourceRef = shift;
    
    foreach (@{$jStringsRef}) {
        push @strArray, jString->populate(@{$_});
    }
    
    foreach (@{$jResourceRef}) {
        push @resArray, jResource->populate(@{$_});
    }
    
    #print "size = " . $#resArray . "\n";
    my $counter1 = 0;
    foreach my $res(@resArray) {
        $counter1++;
        next if(!defined $res);
        my $tokenStart = $res->firsttokenindex;
        my $tokenEnd = $res->firsttokenindex + $res->tokencount -1;
        my @strArraySubset = @strArray[$tokenStart..$tokenEnd];
        #print "strArray size = " . $#strArraySubset . "\n"; 
        $res->strings(\@strArraySubset);
        foreach my $str(@strArraySubset) {
        #print "str1= " . $str->src_text . "\n";
            next if (!defined $str);
            $str->resource($res);
        }
    }   
    #print "counter = $counter1\n";
    bless $self, $class;
    return $self;
}


#accessor method for string list ID
sub ID {
    my ( $self ) = @_;    
    return $self->{$StringListFields{"ID"}};
}

#accessor method for string list source file
sub srcFile {
    my ( $self ) = @_;
    return $self->{$StringListFields{"srcFile"}};
}

#ADDED: accessor method for string list CustomProps
sub srcCustomProps {
    my ( $self ) = @_;    
    return $self->{$StringListFields{"srcCustomProps"}};
}

#accessor method for string list ID
sub targetID {
    my ( $self ) = @_;    
    return $self->{$StringListFields{"targetID"}};
}

#accessor method for string list language
sub lang {
    my ( $self ) = @_;    
    return $self->{$StringListFields{"lang"}};
}

#accessor method for string list target file
sub targetFile {
    my ( $self ) = @_;    
    return $self->{$StringListFields{"targetFile"}};
}

#ADDED: accessor method for string list CustomProps
sub targetCustomProps {
    my ( $self ) = @_;    
    return $self->{$StringListFields{"targetCustomProps"}};
}

#accessor method for strings in the string list
sub strings {
    my ( $self ) = @_;    
    return $self->{$StringListFields{"strings"}};
}

#accessor method for resources in the string list
sub resources {
    my ( $self ) = @_;    
    return $self->{$StringListFields{"resources"}};
}

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