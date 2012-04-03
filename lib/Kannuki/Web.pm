package Kannuki::Web;

use strict;
use warnings;
use utf8;
use Kossy;

use Kannuki::User;

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
        my $user = $c->req->env->{REMOTE_USER};
        if ($user) {
            $c->stash->{user} = Kannuki::User->new($self->htpasswd->lookup_user($user))
        }
        $c->stash->{site_name} = __PACKAGE__;
        $app->($self,$c);
    }
};

get '/' => [qw/set_title/] => sub {
    my ( $self, $c )  = @_;
    my $user = $c->stash->{user};
    if ($user) {
        $c->render('index.tx', { greeting => "Hello ". $user->username });
    }
    else {
        $c->redirect('/register');
    }
};

router [qw/get post/] => '/register' => sub {
    my ($self, $c) = @_;
    if (-f $self->htpasswd_file) {
        $c->res_403;
    }
    else {
        if ($c->is_post) {
            my $result = $c->req->validator([
                username => {
                    rule => [
                        ['NOT_NULL', 'username required.'],
                        [sub {
                            my ($req, $val) = @_;
                            $val =~ /\A[a-z]+(?:-[a-z]+)*\z/ms;
                        }, 'invalid username']
                    ],
                },
                password => {
                    rule => [
                        ['NOT_NULL', 'password required']
                    ],
                },
                password_confirm => {
                    rule => [
                        ['NOT_NULL', 'password_confirm required.'],
                        [sub {
                            my ($req, $val) = @_;
                            $val eq $req->param('password');
                        }, 'input password and password_confirm correctly.']
                    ],
                },
            ]);
            if (!$result->has_error) {
                $result->valid->get('username');
                $self->htpasswd->add_user($result->valid->get('username'), $result->valid->get('password'), 'owner');
                return $c->redirect('/');
            }
            $c->stash->{errors} = $result->errors;
        }
        $c->render('register.tx', {errors => $c->stash->{errors} || {}});
    }
};

1;

package Kossy::Connection;
use strict;
use warnings;
use utf8;

sub is_post {
    shift->req->method eq 'POST';
}

my %code_map = (
    400 => 'Bad Request',
    401 => 'Unauthorized',
    403 => 'Forbidden',
    404 => 'Not Found',
    500 => 'Internal Server Error',
    503 => 'Service Unavailable',
);

for my $code (keys %code_map) {
    my $text = $code_map{$code};
    my $method = "res_$code";
    no strict 'refs';
    *{'Kossy::Connection::' . $method} = sub {
        use strict 'refs';
        my $self = shift;
        $self->res->code($code);
        $self->res->body($text);
        $self->res;
    };
}

1;

