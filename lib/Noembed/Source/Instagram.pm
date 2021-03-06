package Noembed::Source::Instagram;

use Web::Scraper;

use parent 'Noembed::Source';

sub prepare_source {
  my $self = shift;

  $self->{scraper} = scraper {
    process 'meta[property="og:description"]', description => '@content';
    process 'meta[property="og:image"]', url => '@content';
    process 'div.caption', caption => 'TEXT';
  };
}

sub patterns { 'https?://instagr\.am/p/.+' }
sub provider_name { "Instagram" }

sub serialize {
  my ($self, $body) = @_;
  my $data = $self->{scraper}->scrape($body);

  return +{
    title => ($data->{caption} || $data->{title}),
    html  => $self->render($data),
  };
}

1;
