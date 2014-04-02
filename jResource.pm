# class jResource
# Description: This class provides interfaces to access the Resource properties within a String List

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


sub populate (@) {
        return unless @_;
        my ( $self ) = shift;
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


sub translatable{
    my ( $self ) = @_;    
    return (( !($self->state_hidden || $self->state_readonly))?1:0);
}

1;