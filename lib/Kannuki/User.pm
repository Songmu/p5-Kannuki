package Kannuki::User;

use strict;
use warnings;
use utf8;

sub new {
    my ($cls, $authen) = @_;
    bless {_authen => $authen}, $cls;
}

sub authen {
    shift->{_authen};
}

sub username {
    shift->authen->username;
}

sub check_password {
    shift->authen->check_password(@_);
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

sub is_registerd {
    my $self = shift;
    my (undef, $is_registerd) = $self->authen->extra_info;
    $is_registerd;
}


1;
