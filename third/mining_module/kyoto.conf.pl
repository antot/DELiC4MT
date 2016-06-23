#!/usr/bin/perl

use strict;

#
# install path
#

our $KYOTO_HOME = ".";

#
# where is the database environment
#
our $DBXML_ENV_PATH = "dbxml";

#
# default container name
#
our $DBXML_DEFAULT_CONTAINER_NAME = "kyoto";

#
# default cotainer name for kybots
#

our $DBXML_KYBOT_DEFAULT_CONTAINER_NAME = "kybots";

#
# xslt/saxon related
#
our $SAXON_EXEC = "java -jar ".$KYOTO_HOME."/xslt/saxon9.jar -versionmsg:off";
our $KAF2TOKAF_XSL = $KYOTO_HOME."/xslt/Kaf2_to_Kaf.xsl";
our $KAFTOKAF2_XSL = $KYOTO_HOME."/xslt/Kaf_to_Kaf2.xsl";

#
# DTD files
#
our $KAF_DTD = $KYOTO_HOME."/dtd/kaf.dtd";

1;
