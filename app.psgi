use FindBin;
use lib "$FindBin::Bin/extlib/lib/perl5";
use lib "$FindBin::Bin/lib";
use File::Basename;
use Plack::Builder;
use Kannuki::Web;

use Authen::Htpasswd;

my $root_dir = File::Basename::dirname(__FILE__);

my $app = Kannuki::Web->new($root_dir);
my $htpasswd_file = $app->htpasswd_file;
builder {
    enable_if {-f $htpasswd_file} 'Auth::Basic', authenticator => sub {
        my ($user, $passwd) = @_;
        $app->htpasswd->check_user_password($user, $passwd);
    };
    enable 'ReverseProxy';
    enable 'Static',
        path => qr!^/(?:(?:css|js|img)/|favicon\.ico$)!,
        root => $root_dir . '/public';
    $app->psgi;
};

