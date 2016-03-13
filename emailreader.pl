my $CONFIG_SERVER = 'imap.gmail.com';
my $CONFIG_USER = 'setusernamehere';
my $CONFIG_PASS = 'setpasswordhere';
my $CONFIG_DELAY = '15';

my $CONFIG_SEARCH_TERM_STATUS = 'UNSEEN TO pl-status@cs.umd.edu';
my $CONFIG_SEARCH_TERM_SAY = 'UNSEEN TO plumbigmac+say@gmail.com';

my $CONFIG_VOICES = {'piotrm@gmail.com'    => ["Peter", "Zarvox"],
                     'piotrm@cs.umd.edu'   => ["Peter", "Zarvox"],
                     'mwh@cs.umd.edu'      => ["Mike", "Bruce"],
                     'jfoster@cs.umd.edu'  => ["Jeff", "Fred"],
                     'hammer@cs.umd.edu'   => ["Matt", "Bubbles"],
                     'alex' => ["Alex", "Alex"],
                     'dvanhorn@cs.umd.edu' => ["David", "Junior"]};

# normal voices: Agnes, Alex, Bruce, Fred, Junior, Kathy, Pricess, Ralph (deep), Vicki, Victoria,

my $CONFIG_VOICE_INTRO = "Vicki";
my $CONFIG_VOICE_DEFAULT = "Agnes";

use strict;
use warnings;
use Net::IMAP::Simple::SSL;
use Email::Simple;
use Email::Address;
use Email::MIME;
use IPC::Open3;

my $imap = Net::IMAP::Simple::SSL->new($CONFIG_SERVER);
if (! $imap->login($CONFIG_USER => $CONFIG_PASS)) {
  print STDERR "Login failed: " . $imap->errstr . "\n";
  exit(1);
}

my $nm;
my @ids;

while (1) {
  $nm = $imap->select("INBOX");
  print "getting unread messages\n";

  @ids = $imap->search($CONFIG_SEARCH_TERM_STATUS);
  printf("got %d message(s) for pl-status\n", scalar(@ids));
  process_messages($nm, "on status, ", @ids);

  @ids = $imap->search($CONFIG_SEARCH_TERM_SAY);
  printf("got %d message(s) for say\n", scalar(@ids));
  process_messages($nm, "", @ids);

  if ($imap->waserr) {
    print "last error: " . $imap->errstr . "\n";
  }

  sleep($CONFIG_DELAY);
}

sub process_messages {
  my ($nm, $intro, @ids) = @_;

  foreach my $id (@ids) {
    my $es = Email::Simple->new(join '', @{ $imap->get($id) } );
    my $content = Email::MIME->new(join '', @{ $imap->get($id) } );
    my $from = $es->header('From');
    my $to = $es->header('To');
    my $subject = $es->header('Subject');

    my $first_from = (Email::Address->parse($from))[0];
    my $address = $first_from->address;
    my $name = $first_from->name;

    printf("[%03d] From: %s From Address: %s Subject: %s\n", $id, $from, $address, $subject);

    my $parts_by_type = {};

    foreach my $part ($content->parts) {
      my $temp = $part->content_type;
      $temp =~ s/^([^;]+);.*$/$1/;
      $parts_by_type->{$temp} = $part->body;
    }

    my $say_body = "";
    my $say_name = $name;
    my $say_voice = $CONFIG_VOICE_DEFAULT;

    if (exists $CONFIG_VOICES->{$address}) {
      ($say_name, $say_voice) = @{$CONFIG_VOICES->{$address}};
    }

    if (exists $parts_by_type->{'text/plain'}) {
      $say_body = $parts_by_type->{'text/plain'};
      $say_body = trim_body($say_body);
      print "$say_body\n";
      send_to_say($CONFIG_VOICE_INTRO, "$intro$say_name says,");
      send_to_say($say_voice, $say_body);
    } else {
      send_to_say($CONFIG_VOICE_INTRO, "$intro$say_name says something I do not understand. Please tell them to use text/plain encoding.");
    }

    my $temp = $say_body;

    if ($temp =~ m/.*?shut up.*?/i) {
      if ($temp =~ m/.*?please.*?/i) {
        send_to_say($CONFIG_VOICE_INTRO, "Ok, I'm shutting down. You guys make me sad.");
        $imap->quit;
        exit(0);
      } else {
        send_to_say($CONFIG_VOICE_INTRO, "Hey $say_name! What is the magic word?");
      }
    }
  }
}

sub send_to_say {
  my ($voice, $text) = @_;

  my ($wtr, $rdr, $err);

  my $pid = open3($wtr, $rdr, $err, 'say', '-v', $voice);

  print $wtr $text;

  close ($wtr);
  close ($rdr);
#  close ($err);

  waitpid($pid, 0);
}

sub trim_body {
  my ($body) = @_;

  $body =~ s/^(.*?)(\n\r|\n){2,}.*$/$1/s;
  $body =~ s/^>.*$//mg;
  $body =~ s/\n+/\n/g;

  return $body;
}