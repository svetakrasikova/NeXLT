# class jString
# Description: This class provides interfaces to access the String properties within a String List

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


sub populate (@) {
        return unless @_;
        my ( $self ) = shift;
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
    my ( $self ) = @_;    
    return (($self->state_readonly || $self->resource->state_readonly)?1:0);
}

sub isHidden {
    my ( $self ) = @_;    
    return (($self->state_hidden || $self->resource->state_hidden)?1:0);
}

sub translatable{
    my ( $self ) = @_;    
    #print "self=$self\n";
    #print "resource=" . $self->resource . "\n";
    #print "resource no =" . $self->resource->number . "\n";
    return (($self->resource->translatable && !($self->isHidden || $self->isReadOnly))?1:0);
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