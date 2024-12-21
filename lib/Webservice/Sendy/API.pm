use v5.10;
use strict;
use warnings;

my $VERSION = "6.1.2";

use HTTP::Tiny;
use JSON            qw/decode_json/;
use Util::H2O::More qw/baptise ddd HTTPTiny2h2o h2o/;

use constant {
    BASEURL => "",  # get from config? API key also?
};

sub _auth {

}

sub new {
    my $pkg  = shift;
    my $self = baptise { ua => HTTP::Tiny->new }, $pkg;
    return $self;
}

__END__

=head1 NAME

Webservice::Sendy::API - Perl client for Sendy's integration API

=head1 SYNOPSIS

=head2 C<sendy> Commandline Client

=head1 DESCRIPTION

=head2 Internal Methods

=head1 ENVIRONMENT

Nothing special required.

=head1 AUTHOR

Brett Estrade L<< <oodler@cpan.org> >>

=head1 BUGS

Please report.

=head1 LICENSE AND COPYRIGHT

Same as Perl/perl.
