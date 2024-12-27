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
      $self->config("$HOME/.sendy.ini");
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

# .. modify for create_campaign
sub create_campaign {
  my $self     = shift;
  my $params   = {@_};

  my @required = qw/from_name from_email reply_to title subject html_text
                  list_ids brand_id track_opens track_clicks send_campaign/;
  my @optional = qw/plain_text segment_ids exclude_list_ids query_string schedule_date_time schedule_timezone/;

  h2o $params, @required, @optional;

  # FATAL error if title, subject, and html_text is not provided; the other fields
  # required by the API can use defaults in the configuration file, listed after
  # the check:

  # look up hash for defaults to use
  my $required_defaults = h2o {
    title         => undef,
    subject       => undef,
    html_text     => undef,
    from_name     => $self->config->campaign->from_name,
    from_email    => $self->config->campaign->from_email,
    reply_to      => $self->config->campaign->reply_to,
    brand_id      => $self->config->defaults->brand_id,
    list_ids      => $self->config->defaults->list_id,
    track_opens   => 0,
    track_clicks  => 0,
    send_campaign => 0,
  };


  my $required_options = {};
  foreach my $param (keys %$required_defaults) { 
    if (not defined $params->$param and defined $required_defaults->$param) {
      $params->$param($required_defaults->$param);
    }
    # FATAL for anything in $required_defaults set to 'undef'
    elsif (not defined $params->$param and not defined $required_defaults->$param) {
      die sprintf "[campaign] creation requires: %s; died on '%s'\n", join(",", keys %$required_defaults), $param;
    }
    $required_options->{$param} = $params->$param;
  }

  # processing other white-listed options in @optional
  my $other_options = {}; 
  foreach my $opt (@optional) {
    if (defined $params->$opt) {
      $other_options->{$opt} = $params->$opt;
    }
  }

  my $form_data = $self->form_data(%$required_options, %$other_options);
  my $URL       = sprintf "%s/api/campaigns/create.php", $self->config->defaults->base_url;
  my $resp      = h2o $self->ua->post_form($URL, $form_data);

  # report Error
  if ($resp->content and $resp->content =~ m/Already|missing|not|valid|Unable/i) {
    my $msg = $resp->content;
    $msg =~ s/\.$//g;
    die sprintf "[create] Server replied: %s!\n", $msg;
  }

  # report general failure (it is not clear anything other than HTTP Status of "200 OK" is returned)
  if (not $resp->success) {
    die sprintf("Server Replied: HTTP Status %s %s\n", $resp->status, $resp->reason);
  }

ddd $resp;

  #return sprintf "%s %s %s\n", ($resp->content eq "1")?"Subscribed":$resp->content, $params->list_id, $params->email;
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
  if ($resp->content and $resp->content =~ m/Already|missing|not|valid|Bounced|suppressed/i) {
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

Webservice::Sendy::API - Sendy's integration API Perl client and commandline utility

=head1 SYNOPSIS

  use v5.10;   # enables "say" and turns on "use warnings;"
  use strict;
  use Webservice::Sendy::API qw//;
  
  my $sendy  = Webservice::Sendy::API->new; # looks for default config file 
  my $brands = $sendy->get_brands;
  
  foreach my $key (sort keys %$brands) {
    my $brand = $brands->$key;
    printf "%-3d  %s\n", $brand->id, $brand->name;
  }

=head1 DESCRIPTION

=head1 METHODS

=head1 C<sendy> COMMANDLINE CLIENT

When installed, this module provides the commandline client, C<sendy>. This script
is both a real tool and a reference implementation for a useful client. It is meant
for use on the commandline or in cron or shell scripts. It's not intended to be
used inside of Perl scripts. It is recommended the library be used directly inside
of the Perl scripts. Checkout the source code of C<sendy> to see how to do it, if
this documentation is not sufficient.

=head1 ENVIRONMENT

=head2 C<$HOME/.sendy.ini> Configuration

A configuration file is required. The default file is C<$HOME/.sendy.ini>.
It is I<highly> recommended that this file be C<chmod 600> (read only to
the C<$USER>. B<Note:> Future versions of this module may enforce this file
mode or automatically change permissions on the file.

  ; defaults used for specified options
  [defaults]
  api_key=sOmekeyFromSendy
  base_url=https://my.domain.tld/sendy
  brand_id=1
  list_id=lumdsPnpwnazrcoOzKJ763Ow
  ; campaign information used for default brand_id 
  [campaign]
  from_name=List Sender Name
  from_email=your-email-list@domain.tld
  reply_to=some-other-reply-to@domain.tld

=head1 AUTHOR

Brett Estrade L<< <oodler@cpan.org> >>

=head1 BUGS

Please report.

=head1 LICENSE AND COPYRIGHT

Same as Perl/perl.
