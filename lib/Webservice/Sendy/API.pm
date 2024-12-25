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

sub _country_codes {
  return qw(
    AD AE AF AG AI AL AM AO AR AS AT AU AW AX AZ
    BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS
    BT BU BV BW BY BZ CA CC CD CF CG CH CI CK CL CM
    CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ
    EC EE EG EH ER ES ET FI FJ FM FO FR GA GB GD
    GE GF GG GH GI GL GM GN GP GQ GR GT GU GW GY
    HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS
    IT JE JM JO JP KE KG KH KI KM KN KP KR KW
    KY KZ LA LB LC LI LK LR LS LT LU LV LY
    MA MB MC MD ME MF MG MH MK ML MM MN MO MP
    MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF
    NG NI NL NO NP NR NU NZ OM PA PE PF PG PH
    PK PL PM PN PR PT PW PY QA RE RO RS RU RW
    SA SB SC SD SE SG SH SI SJ SK SL SM SN
    SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ
    TK TL TM TN TO TR TT TV TZ UA UG US UY
    UZ VA VC VE VG VI VN VU WF WG WS YE YT ZA
    ZM ZW
  );
}

sub subscribe {
  my $self     = shift;
  my $params   = {@_};
  my @required = qw/email list_id/;
  my @optional = qw/name country ipaddress referrer gdpr silent hp/;
  h2o $params, @required, @optional;

  #NOTE - Util::H2O::More::ini2h2o needs a "autoundef" option! Workaround is use of "exists" and ternary
  if (not $params->list_id) {
     $params->list_id('');
     if ($self->config->defaults->{list_id}) {
       $params->list_id($self->config->defaults->list_id);
     }
  }
  die "email required!\n" if not $params->email;

  # processing other white-listed options
  my $other_options = {}; 
  foreach my $opt (@optional) {
    if (defined $params->$opt) {
      $other_options->{$opt} = $params->$opt;
    }
  }

  my $form_data = $self->form_data(list => $params->list_id, email => $params->email, boolean => "true", %$other_options);
  my $URL       = sprintf "%s/subscribe", $self->config->defaults->base_url;
  my $resp      = h2o $self->ua->post_form($URL, $form_data);

  # report Error
  if ($resp->content and $resp->content =~ m/Already|missing|not|valid|Bounced|suppressed/) {
    my $msg = $resp->content;
    $msg =~ s/\.$//g;
    die sprintf "[subscribe] Server replied: %s!\n", $msg;
  }

  # report general failure (it is not clear anything other than HTTP Status of "200 OK" is returned)
  if (not $resp->success) {
    die sprintf("Server Replied: HTTP Status %s %s\n", $resp->status, $resp->reason);
  }

  return sprintf "%s %s %s\n", ($resp->content eq "1")?"Subscribed":$resp->content, $params->list_id, $params->email;
}

#NOTE: this call is different from "delete_subscriber" in that it just marks the
# subscriber as unsubscribed; "delete_subscriber" fully removes it from the list (in the DB)
#NOTE: this call uses a different endpoint than the others ...
sub unsubscribe {
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
  my $email     = $params->{email};
  die "email required!\n" if not $email;

  my $form_data = $self->form_data(list => $list_id, email => $email, boolean => "true");
  my $URL       = sprintf "%s/unsubscribe", $self->config->defaults->base_url;
  my $resp      = h2o $self->ua->post_form($URL, $form_data);

  # report Error
  if ($resp->content and $resp->content =~ m/Some|valid|not/i) {
    my $msg = $resp->content;
    $msg =~ s/\.$//g;
    die sprintf "[unsubscribe] Server replied: %s!\n", $msg;
  }

  # report general failure (it is not clear anything other than HTTP Status of "200 OK" is returned)
  if (not $resp->success) {
    die sprintf("Server Replied: HTTP Status %s %s\n", $resp->status, $resp->reason);
  }

  return sprintf "%s %s %s\n", ($resp->content == 1)?"Unsubscribed":$resp->content, $list_id, $email;
}

#NOTE: this call is different from "unsubscribe" in that it deletes the subscriber
# "unsubscribe" simply marks them as unsubscribed
sub delete_subscriber {
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
  my $email     = $params->{email};
  die "email required!\n" if not $email;

  my $form_data = $self->form_data(list_id => $list_id, email => $email);
  my $URL       = sprintf "%s/api/subscribers/delete.php", $self->config->defaults->base_url;
  my $resp      = h2o $self->ua->post_form($URL, $form_data);

  # report Error
  if ($resp->content and $resp->content =~ m/No|valid|List|not/i) {
    my $msg = $resp->content;
    $msg =~ s/\.$//g;
    die sprintf "[delete] Server replied: %s!\n", $msg;
  }

  # report general failure (it is not clear anything other than HTTP Status of "200 OK" is returned)
  if (not $resp->success) {
    die sprintf("Server Replied: HTTP Status %s %s\n", $resp->status, $resp->reason);
  }

  return sprintf "%s %s %s\n", ($resp->content == 1)?"Deleted":$resp->content, $list_id, $email;
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
  my $email     = $params->{email};
  die "email required!\n" if not $email;

  my $form_data = $self->form_data(list_id => $list_id, email => $email);
  my $URL       = sprintf "%s/api/subscribers/subscription-status.php", $self->config->defaults->base_url;
  my $resp      = h2o $self->ua->post_form($URL, $form_data);

  # catch "Not Subscribed"
  if ($resp->content eq "Email does not exist in list") {
    return sprintf "Not Subscribed %s %s\n", $list_id, $email;
  }

  # report Error
  if ($resp->content and $resp->content =~ m/No|vlaid|not/i) {
    my $msg = $resp->content;
    $msg =~ s/\.$//g;
    die sprintf "[status] Server replied: %s!\n", $msg;
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
  my $URL       = sprintf "%s/api/subscribers/active-subscriber-count.php", $self->config->defaults->base_url;
  my $resp      = h2o $self->ua->post_form($URL, $form_data);

  # report Error
  if ($resp->content and $resp->content =~ m/No|valid|not/i) {
    my $msg = $resp->content;
    $msg =~ s/\.$//g;
    die sprintf "[count] Server replied: %s!\n", $msg;
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
  my $URL       = sprintf "%s/api/brands/get-brands.php", $self->config->defaults->base_url;
  my $resp      = h2o $self->ua->post_form($URL, $form_data);

  # report Error
  if ($resp->content and $resp->content =~ m/No|valid/i) {
    my $msg = $resp->content;
    $msg =~ s/\.$//g;
    die sprintf "[brands] Server replied: %s!\n", $msg;
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
  my $URL       = sprintf "%s/api/lists/get-lists.php", $self->config->defaults->base_url;
  my $resp      = h2o $self->ua->post_form($URL, $form_data);

  # report Error
  if ($resp->content and $resp->content =~ m/No|valid|not/i) {
    my $msg = $resp->content;
    $msg =~ s/\.$//g;
    die sprintf "[lists] Server replied: %s!\n", $msg;
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
