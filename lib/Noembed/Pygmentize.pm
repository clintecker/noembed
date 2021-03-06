package Noembed::Pygmentize;

use AnyEvent::Worker;
use File::Which qw/which/;

sub new {
  my ($class, %args) = @_;

  bless {
    bin     => $args{bin}     || which("pygmentize") || "/usr/bin/pygmentize",
    lexer   => $args{lexer}   || "text",
    format  => $args{format}  || "html",
    options => $args{options} || "linenos=True,encoding='utf-8'",
  }, $class;
}

sub colorize {
  my $cb = pop;
  my ($self, $text, %opts) = @_;

  $opts{lexer}   = $self->{lexer}   unless defined $opts{lexer};
  $opts{format}  = $self->{format}  unless defined $opts{format};
  $opts{options} = $self->{options} unless defined $opts{options};

  $self->worker->do(colorize => $text, %opts, sub {
    if ($@) {
      warn $@;
      return $cb->($text);
    }
    $cb->($_[1]);
  });
}

sub worker {
  my $self = shift;
  $self->{worker} ||= AnyEvent::Worker->new(
    ['Noembed::Pygmentize::Worker' => $self->{bin}]);
}


package Noembed::Pygmentize::Worker;

use IPC::Run;
use List::Util qw/first/;
use Encode;

sub new {
  my ($class, $bin) = @_;
  bless { bin => $bin }, $class;
}

sub has_lexer {
  my ($self, $lexer) = @_;
  return first { $_ eq $lexer } @{$self->lexers};
}

sub lexers {
  my $self = shift;
  $self->{lexers} ||= $self->build_lexers;
}

sub build_lexers {
  my $self = shift;

  my($in, $out, $err);
  my $pid = IPC::Run::run([$self->{bin}, "-L", "lexers"], \$in, \$out, \$err, );

  my @lexers;

  for my $line (split "\n", $out) {
    if ($line =~ /^* (.+):/) {
      push @lexers, split ", ", $1;
    }
  }

  return \@lexers;
}

sub colorize {
  my ($self, $text, %opts) = @_;

  $text = encode("utf-8", "$text\n");
  my($out, $err);

  eval {
    IPC::Run::run([$self->command(%opts)], \$text, \$out, \$err, IPC::Run::timeout(3));
  };

  if ($err or $@) {
    return "<pre>$text</pre>"
  }

  return decode("utf-8", $out);
}

sub command {
  my ($self, %opts) = @_;

  unless ($opts{lexer} and $self->has_lexer($opts{lexer})) {
    $opts{lexer} = "text";
  }

  return (
    $self->{bin},
    '-l', $opts{lexer},
    '-f', $opts{format},
    '-O', $opts{options},
  );
}

1;
