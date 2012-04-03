package Kannuki::Web;

use strict;
use warnings;
use utf8;
use Kossy;

sub config {
    my $self = shift;
    $self->{_config} ||= do $self->root_dir . '/config.pl';
}

sub htpasswd_file {
    my $self = shift;
    $self->{_htpasswd_file} ||= sub {
        my $file = $self->config->{htpasswd_file};
        return $self->root_dir. '/data/.htpasswd' unless $file;
        $file .= $self->root_dir . $file unless $file =~ m!^/!;
        $file;
    }->();
}

sub htpasswd {
    my $self = shift;
    $self->{_htpasswd} ||= Authen::Htpasswd->new($self->htpasswd_file, { encrypt_hash => $self->config->{encrypt_hash} || 'md5' });
}

filter 'set_title' => sub {
    my $app = shift;
    sub {
        my ( $self, $c )  = @_;
        $c->stash->{site_name} = __PACKAGE__;
        $app->($self,$c);
    }
};

get '/' => [qw/set_title/] => sub {
    my ( $self, $c )  = @_;
    $c->render('index.tx', { greeting => "Hello" });
};

get '/json' => sub {
    my ( $self, $c )  = @_;
    my $result = $c->req->validator([
        'q' => {
            default => 'Hello',
            rule => [
                [['CHOICE',qw/Hello Bye/],'Hello or Bye']
            ],
        }
    ]);
    $c->render_json({ greeting => $result->valid->get('q') });
};

1;

