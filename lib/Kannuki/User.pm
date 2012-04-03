package Kannuki::User;

use strict;
use warnings;
use utf8;

sub new {
    my ($cls, $authen) = shift;
    bless {_authen => $authen}, $cls;
}

sub authen {
    shift->{_authen};
}

sub user_name {
    shift->authen->user_name;
}

sub is_owner {
    my $self = shift;
    $self->role eq 'owner';
}

sub is_admin {
    my $self = shift;
    $self->is_owner || $self->role eq 'admin';
}

sub role {
    my $self = shift;
    my ($role) = $self->authen->extra_info;
    $role // '';
}







1;
