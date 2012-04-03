use FindBin;
use lib "$FindBin::Bin/extlib/lib/perl5";
use lib "$FindBin::Bin/lib";
use File::Basename;
use Plack::Builder;
use Kannuki::Web;

use Authen::Htpasswd;

my $root_dir = File::Basename::dirname(__FILE__);

my $basic_file = "$FindBin::Bin/data/htpasswd";

my $app = Kannuki::Web->psgi($root_dir);
builder {
    enable_if {-f $basic_file} 'Auth::Basic', authenticator => sub {
        my ($user, $passwd) = @_;
        my $authen = Authen::Htpasswd->new($basic_file, { encrypt_hash => 'md5' });
        $authen->check_user_password($user, $passwd);
    };
    enable 'ReverseProxy';
    enable 'Static',
        path => qr!^/(?:(?:css|js|img)/|favicon\.ico$)!,
        root => $root_dir . '/public';
    $app;
};

