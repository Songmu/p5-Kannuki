package Kannuki::Web;

use strict;
use warnings;
use utf8;
use Kossy;

use Kannuki::User;
use String::Random;

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

filter 'get_user' => sub {
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

get '/' => [qw/get_user/] => sub {
    my ( $self, $c )  = @_;
    my $user = $c->stash->{user};
    if ($user) {
        if ($user->is_registerd) {
            $c->render('index.tx', { greeting => "Hello ". $user->username, user => $user });
        }
        else {
            $c->redirect('/change_password');
        }
    }
    elsif (! -f $self->htpasswd_file) {
        $c->redirect('/register');
    }
    else {
        $c->res_401;
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
                $self->htpasswd->add_user($result->valid->get('username'), $result->valid->get('password'), 'owner', '1');
                return $c->redirect('/');
            }
            $c->stash->{errors} = $result->errors;
        }
        $c->render('register.tx', {errors => $c->stash->{errors} || {}});
    }
};

router [qw/get post/] => '/change_password' => [qw/get_user/] => sub {
    my ($self, $c) = @_;
    my $user = $c->stash->{user};

    if ($c->is_post) {
        my $result = $c->req->validator([
            old_password    => {
                rule => [
                    ['NOT_NULL', 'old password required'],
                    [sub {
                        my ($req, $val) = @_;
                        $user->check_password($val);
                    }, 'old password invalid'],
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
            $self->htpasswd->update_user($user->username, $result->valid->get('password'), $user->role, '1');
            return $c->redirect('/');
        }
        $c->stash->{errors} = $result->errors;
    }
    $c->render('change_password.tx', {errors => $c->stash->{errors} || {}});
};

router [qw/get post/] => '/add_user' => [qw/get_user/] => sub {
    my ($self, $c) = @_;
    my $user = $c->stash->{user};

    return $c->res_403 unless $user->is_admin;

    if ($c->is_post) {
        my $result = $c->req->validator([
            username => {
                rule => [
                    ['NOT_NULL', 'username required.'],
                    [sub {
                        my ($req, $val) = @_;
                        !$self->htpasswd->lookup_user($val);
                    }, "user already exists."],
                    [sub {
                        my ($req, $val) = @_;
                        $val =~ /\A[a-z]+(?:-[a-z]+)*\z/ms;
                    }, 'invalid username'],
                ],
            },
            is_admin    => {
            },
            password => {
                rule => [
                    ['NOT_NULL', 'old password required'],
                    [sub {
                        my ($req, $val) = @_;
                        $user->check_password($val);
                    }, 'password invalid'],
                ],
            },
        ]);
        if (!$result->has_error) {
            my $username = $result->valid->get('username');
            my $password = String::Random->new->randregex('[a-zA-Z0-9]{12}');
            my $role     = $result->valid->get('is_admin') ? 'admin' : 'general';
            $self->htpasswd->update_user($username, $password, $role, '0');
            return $c->render('add_user_complete.tx', {username => $username, password => $password});
        }
        $c->stash->{errors} = $result->errors;
    }
    $c->render('add_user.tx', {errors => $c->stash->{errors} || {}});
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

