package Webservice::Sendy::API;

use v5.10;
use strict;
use warnings;

my $VERSION = "6.1.2";

use HTTP::Tiny;
use JSON            qw/decode_json/;
use Util::H2O::More qw/baptise ddd HTTPTiny2h2o h2o ini2h2o o2d/;

sub new {
    my $pkg = shift;
    my $params = { @_, ua => HTTP::Tiny->new };
    my $self = baptise $params, $pkg, qw/config/;
    if (not $self->config) {
      my $HOME = (getpwuid($<))[7];
      $self->config("$HOME/.sendy.conf");
    }
    # update config field with contents of the config file
    $self->config(ini2h2o $self->config);
    return $self;
}

sub form_data {
  my $self = shift;
  return {
    api_key => $self->config->defaults->api_key,
    @_,
  };
}

sub get_subscription_status {
  my $self      = shift;
  my $params    = {@_};

  #NOTE - Util::H2O::More::ini2h2o needs a "autoundef" option! Workaround is use of "exists" and ternary
  my $list_id   = $params->{list_id};
  if (not $list_id) {
     $list_id = '';
     if ($self->config->defaults->{list_id}) {
       $list_id = $self->config->defaults->list_id;
     }
  }
  my $email     = $params->{email} // '';

  my $form_data = $self->form_data(list_id => $list_id, email => $email);
  my $URL       = sprintf "%s/subscribers/subscription-status.php", $self->config->defaults->base_url; 
  my $resp      = h2o $self->ua->post_form($URL, $form_data);

  # catch "Not Subscribed"
  if ($resp->content eq "Email does not exist in list") {
    return sprintf "Not Subscribed %s %s\n", $list_id, $email;
  }

  # report Error
  if ($resp->content and $resp->content =~ m/no/i) {
    die sprintf "Server replied: %s!\n", $resp->content;
  }

  # report general failure (it is not clear anything other than HTTP Status of "200 OK" is returned)
  if (not $resp->success) {
    die sprintf("Server Replied: HTTP Status %s %s\n", $resp->status, $resp->reason);
  }

  return sprintf "%s %s %s\n", $resp->content, $list_id, $email;
}

sub get_active_subscriber_count {
  my $self      = shift;
  my $params    = {@_};

  #NOTE - Util::H2O::More::ini2h2o needs a "autoundef" option! Workaround is use of "exists" and ternary
  my $list_id   = $params->{list_id};
  if (not $list_id) {
     $list_id = '';
     if ($self->config->defaults->{list_id}) {
       $list_id = $self->config->defaults->list_id;
     }
  }

  my $form_data = $self->form_data( list_id => $list_id);
  my $URL       = sprintf "%s/subscribers/active-subscriber-count.php", $self->config->defaults->base_url; 
  my $resp      = h2o $self->ua->post_form($URL, $form_data);

  # report Error
  if ($resp->content and $resp->content =~ m/no/i) {
    die sprintf "Server replied: %s!\n", $resp->content;
  }

  # report general failure (it is not clear anything other than HTTP Status of "200 OK" is returned)
  if (not $resp->success) {
    die sprintf("Server Replied: HTTP Status %s %s\n", $resp->status, $resp->reason);
  }

  return sprintf "%s %s\n", $resp->content // -1, $list_id;
}

sub get_brands() {
  my $self      = shift;
  my $form_data = $self->form_data();
  my $URL       = sprintf "%s/brands/get-brands.php", $self->config->defaults->base_url; 
  my $resp      = h2o $self->ua->post_form($URL, $form_data);

  # report Error
  if ($resp->content and $resp->content =~ m/no/i) {
    die sprintf "Server replied: %s!\n", $resp->content;
  }

  # report general failure (it is not clear anything other than HTTP Status of "200 OK" is returned)
  if (not $resp->success) {
    die sprintf("Server Replied: HTTP Status %s %s\n", $resp->status, $resp->reason);
  }

  $resp = HTTPTiny2h2o o2d $resp;
  return $resp->content;
}

sub get_lists {
  my $self      = shift;
  my $params    = {@_};
  my $form_data = $self->form_data( brand_id => $params->{brand_id} // $self->config->defaults->brand_id // 1);
  my $URL       = sprintf "%s/lists/get-lists.php", $self->config->defaults->base_url; 
  my $resp      = h2o $self->ua->post_form($URL, $form_data);

  # report Error
  if ($resp->content and $resp->content =~ m/no/i) {
    die sprintf "Server replied: %s!\n", $resp->content;
  }

  # report general failure (it is not clear anything other than HTTP Status of "200 OK" is returned)
  if (not $resp->success) {
    die sprintf("Server Replied: HTTP Status %s %s\n", $resp->status, $resp->reason);
  }

  $resp = HTTPTiny2h2o o2d $resp;
  return $resp->content;
}

777

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
