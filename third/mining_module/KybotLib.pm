
package KybotLib;

use strict;

sub openContainer {

  my ($mgr, $c_name) = @_;

  my $container_name = $c_name;
  $container_name.=".dbxml" unless $container_name =~ /\.dbxml$/;

  return undef unless $mgr->existsContainer($container_name);

  my $container;

  eval {
    $container = $mgr->openContainer($container_name);
  };

  if (my $e = catch XmlException) {
    die $e->what();
  }

  return $container;
}

# Creates a container and adds the indices for quick document access,
# namely:
#
# addIndex "" lemma edge-attribute-substring-string
# addIndex "" pos edge-attribute-substring-string
# addIndex "" sensecode edge-attribute-substring-string

sub createDocContainer {

  my ($mgr, $c_name) = @_;

  my $container_name = $c_name;
  $container_name.=".dbxml" unless $container_name =~ /\.dbxml$/;

  my $container;
  if (! $mgr->existsContainer($container_name)) {
    $container = $mgr->createContainer($container_name);
    &try_setAutoIndexing($container, 0);
    eval {
      $container->addIndex("", "lemma", "edge-attribute-substring-string");
      $container->addIndex("", "pos", "edge-attribute-substring-string");
      $container->addIndex("", "reftype", "edge-attribute-substring-string");
      $container->addIndex("", "reference", "edge-attribute-substring-string");
      #$container->addIndex("", "reftype", "edge-attribute-equality-string");
      #$container->addIndex("", "reference", "edge-attribute-equality-string");
    };
    if (my $e = catch XmlException) {
      die $e->what();
    }
  } else {
    eval {
      $container = $mgr->openContainer($container_name);
    };
    if (my $e = catch XmlException) {
      die $e->what();
    }
  };
  return $container;
}

# Creates a container without indexes


sub createSimpleContainer {

  my ($mgr, $c_name) = @_;


  my $container_name = $c_name;
  $container_name.=".dbxml" unless $container_name =~ /\.dbxml$/;

  if (! $mgr->existsContainer($container_name)) {
    $mgr->createContainer($container_name);
  }

  my $container;

  eval {
    $container = $mgr->openContainer($container_name);
  };

  if (my $e = catch XmlException) {
    die $e->what();
  }

  return $container;
}

# Remove environment files

sub rmEnvFiles {

  my $dir = shift ;
  my $dh;
  unless (opendir($dh, $dir)) {
    warn "Can not open $dir:$!\n";
    return;
  }

  my @F = readdir($dh);
  foreach my $f (@F) {
    next unless $f =~ /^__db\./;
    unlink ($dir."/".$f);
  }
}


sub try_setAutoIndexing {

  my ($THIS, $value) = @_;

  eval {
    $THIS->_setAutoIndexing(undef, $value);
  };
}

1;
