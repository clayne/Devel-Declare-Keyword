package Devel::Declare::Keyword::Parser;
use strict;
use warnings;
use Carp;
use Devel::Declare::Keyword::Context;
use Data::Dumper;

our %BUILTIN = (
	proto => 'Devel::Declare::Keyword::Parse::Proto::parse_proto',
	ident => 'Devel::Declare::Keyword::Parse::Ident::parse_ident',
	block => 'Devel::Declare::Keyword::Parse::Block::new',
);

sub new {
	my ($class, $self) = @_;
	$self->{proto} or confess 'no proto provided';
	$self->{module} or confess 'no module provided';
	$self->{keyword} or confess 'no keyword provided';
	bless($self,$class);	
}

sub build {
	my $self = shift;
	$self->_build_ident_list;
	$self->_lookup_routines;
	
	return sub {
		my $kd = Devel::Declare::Keyword::Context->new(@_);
		$kd->skip_token($kd->declarator);
		$kd->skip_ws;

		$self->declare($kd);

		my @arg;
		#call each parse routine and action
		for my $pa (@{$self->{plist}}) {
			push @arg, $self->exec($pa);	
		}

		# if it has a block execute keyword block at compile
		if($self->{block}) { 
			&{$Devel::Declare::Keyword::__keyword_block}(@arg);
		}
		else { # no block execute at runtime, save arg
			@Devel::Declare::Keyword::__keyword_block_arg = @arg;
		}
	};
}

sub declare {
	my ($self, $d) = @_;
	$self->{declare} = $d if $d;
	return $self->{declare};
}

#executes a parse routine and its action
sub exec {
	my ($self, $pa) = @_;
	my $match = &{$pa->{parse}}($self->declare); 
	$self->declare->skip_ws;
	confess "failed to parse $pa->{name}" unless $match or $pa->{opt};
	return &{$pa->{action}}($match);
}

sub _build_ident_list {
	my $self = shift;
	$self->{proto} =~ s/\s//g;
	my @i = split /\,/, $self->{proto};
	for my $ident (@i){
		$ident =~ /^[a-z]{1}\w+[\?]?$/i or 
		confess "bad identifier '$ident' in prototype.";
		my $opt;
		$ident =~ s/\?//g and $opt = 1 if $ident =~ /\?$/;
		push @{$self->{plist}}, {name=>lc($ident),optional=>$opt};
	}
}

sub _lookup_routines {
	my $self = shift;
	for my $p (@{$self->{plist}}) {
		$p->{parse} = $self->_find_parse_sub($p->{name});
		$p->{action} = $self->_find_action_sub($p->{name});
	}
}

sub _find_parse_sub {
	my ($self, $ident) = @_;
	no strict 'refs';
	if (exists $BUILTIN{$ident}) {
		return \&{$BUILTIN{$ident}};
	}
	else {
		#	"$self->{module}"->can("parse_$ident");
		return \&{$self->{module}."::parse_$ident"};
	}
}

sub _find_action_sub {
	my ($self, $ident) = @_;
	no strict 'refs';
	if($ident eq 'block') {
		return sub {@_};
	}
	else {
		return \&{$self->{module}."::action_$ident"};
	}
}
