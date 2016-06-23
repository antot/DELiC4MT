
1. Kyoto mining module
   *******************

This is a collection of programs for implementing the Kyoto Mining
module. The overall architecture of the system, as well as its design goals,
are described in Kyoto project's Deliverable D5.2. As stated in this
document, the source documents, kybots and fact documents are stored in a
big native XML database, using the Berkeley XML DB. 

In this distribution there are the following files/directories:

README.txt              this file
KPROFILES.txt           Document explaining Kybot profile syntax
kyoto.conf.pl           main configuration file
KybotLib.pm             library module
container_ls.pl         list documents in a collection
doc_dump.pl             dump documents from the database to files
kybot_dump.pl           dump kybot profiles from the database to files
doc_load.pl             load documents to a database collection
kybot_load.pl           load documents to a database collection
kybot_run.pl            execute a kybot over a collection
dtd/kaf.dtd             KAF DTD
xslt/Kaf2_to_Kaf.xsl    XSLT stylesheet
xslt/Kaf_to_Kaf2.xsl    XSLT stylesheet
pr_benchmark10		Profile samples on benchmark documents (2010)

2. Installing the system
   *********************

There are some requisites for executing the mining module:

      - a Linux platform with Perl support
      - Java support (needed by the XSLT saxon processor)
      - Berkeley XML DB, with perl support (see Section 2.1)
      - Perl module XML::LibXML

2.1 Installing Berkeley XML DB
    --------------------------

This document contains instructions to install the Berkeley DB XML from the
original sources. You can also check whether your Linux distribution already
offers precompiled packages of the database.

The Berkeley DB XML can be downloaded from:

        http://www.oracle.com/technology/software/products/berkeley-db/xml/index.html
        
Download version 2.4.16 or newer. Other versions may cause incompatibility
problems.

Easy installation:

        1) tar -xzf dbxml-2.4.16.tar.gz
        2) cd dbxml-2.4.16
        3) sudo ./buildall.sh --prefix=/usr/local --enable-perl

        * This will configure, build and install the database with the perl module needed.      

For testing the installation, try this command:

        dbxml

This should open the database command prompt:
  
        dbxml>

that means the installation has been successfull.

Close it with the "exit" command.

** In case of the kybot scripts could not locate dbxml libraries, execute
   this before calling any program:

   export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib


3. Simple use scenario
   *******************

Suppose an user succesfully installs the required software and downloads
mining module scripts under the directory ~/kyoto/mining_module. Usually,
she/he will have to perform the following steps:

3.1 Document loading
    ----------------

The first step to perform is to load KAF documents into the database. This
task is accomplished with the 'doc_load.pl' script. If the documents are in
"~/kyoto/docs_en", she/he types the following:

% ./doc_load.pl --container-name docs_en --force ~/kyoto/docs_en/*

The script is called with two parameters. The first (--container-name)
specifies the name of the container where the documents will be stored (by
default this container name is 'kyoto' as defined by the kyoto.conf.pl
configuration file, line 19). The parameter --force specifies that the
script should create a new container in case it was not already there.

The document loading process may be slow specially when the KAF files are
big. The script first validates each document and then changes its KAF
format into an internal format (which we call KAF2). This final step is
performed by the xslt/KAf_to_Kaf2.xsl XSLT stylesheet, and can be very
time-consuming. At the time being the internal representation is just like
KAF, but all elements are grouped into sentences. Anyway, the user can skip
either step by using the 'doc_load.pl' script's command-line options
(--no-validation to skip the validation step, and --internal-format to store
the documents in the original KAF format).

3.2 Kybot loading
    -------------

The kybots are loaded into the database with the 'kybot_load.pl' script. If
the kybot profiles are stored in "~/kyoto/kybots_en" the user types the
following:

% ./kybot_load.pl --container-name kybots_en --force ~/kyoto/kybots_en

Again, two command-line options are specified. As in the case of the
doc_loader.pl script, the first (--container-name) specifies the name of the
container where the kybots will be stored (by default this container name is
'kybots as defined by the kyoto.conf.pl configuration file, line 25). The
parameter --force specifies that the script should create a new container in
case it was not already there.

3.3 Listing the documents/kybots in a collection
    --------------------------------------------

The user can list the documents/kybots of a particular collection at any
time. Just use the 'container_ls.pl' script:

% ./container_ls.pl --container-name docs_en
...
...


3.4 Execute some kybot over a document collection
    ---------------------------------------------

The 'kybot_run.pl' script is used to run kybots over the document. The usage is:

% ./kybot_run.pl --container-name docs_en --kybot-container-name kybots_en kprofile1

The above command executes the kybot whose name is 'kprofile1' over all
documents in the 'docs_en' container, and stores the new facts in the
document themselves.

The 'kybot_run.pl' script has some interesting command-line options. If we
want to see the results of a kybot profile (that is, the facts it would
produce) without actually changing the documents, use the '--dry-run'
switch. If we want to read the kybot profile from the disk instead of the
database, use '--profile-from-disk'.

3.5 Dump documents
    --------------

Once the kybots are executed, the user can obtain the resulting KAF document
with the 'doc_dump.pl' script. Its use is straightforward:

% ./doc_dump.pl --container-name docs_en --target-directory ~/kyoto/fact_doc_en doc1.kaf


4. Scripts and command-line options
   ********************************

All the scripts accept the '--help' command line option for displaying usage
information.

4.1 kyoto.conf.pl
    -------------

This files is not a script, but a central place where the default values of
several variables are defined. Edit the file and change the values accordingly.


4.2 Document/Kybot loading
    ----------------------

The script 'doc_load.pl' loads new documents into the database. Usage:

USAGE: ./doc_load.pl [--container-name cont_name] [--force] [--internal-format] [--no-validation] doc [doc2 doc3 ...]
        --container-name name of the container. If ommited, use default container defined in kyoto.conf.pl
        --force Create a new container if not there.
        --internal-format Store the document as-is, i.e., without aplying any transformation.
        --no-validation Don't validate the doc against the KAF dtd.


The script './kybot_load.pl' loads the kybots into the database. Usage:

USAGE: ./kybot_load.pl [ --container-name cont_name ] [--force] kybot [kybot2 kybot3 ...]
        --container-name name of the container. If ommited, use default container defined in kyoto.conf.pl
        --force Create a new container if not there.

4.3 List container
    --------------

The script './container_ls.pl' lists the contents of a database container. Usage:

USAGE: ./container_ls.pl [ --container-name cont_name ] [ --docs | --kybots ]
        --container-name name of the container. If ommited, use default container defined in kyoto.conf.pl
        --docs List documents
        --kybots List kybots

4.4 Kybot execution
    ---------------

The script './kybot_run.pl' executes a kybot profile over a document collection. Usage:

USAGE: ./kybot_run.pl [ --dry-run ] [ --profile-from-disk ] [ --container-name cont_name ] [ --kybot-container-name cont_name ] kybot_profile
        --container-name name of the document container. If ommited, use default container defined in kyoto.conf.pl
        --kybot-container-name name of the kybot container. If ommited, use default kybot container defined in kyoto.conf.pl
        --dry-run display results on the screen. Do not touch the documents.
        --profile-from-disk read the kybot profile from disk instead of the database. Implies --dry-run.

4.5 Document dump
    -------------

The script './doc_dump.pl' dumps documents stored in the database to disk. Usage:

USAGE: ./doc_dump.pl [ --container-name cont_name ] [ --internal-format ] [ --target-dir target_directory ] doc [doc2 doc3 ...]
        --container-name name of the container. If ommited, use default container defined in kyoto.conf.pl
        --internal-format Dump the document as-is, i.e., without aplying any transformation.
        --target-dir Directory for leaving the documents.

The script './kybot_dump.pl' dumps kybots stored in the database to disk. Usage:

USAGE: ./kybot_dump.pl [ --container-name cont_name ] [ --target-dir target_directory ] kybot [kybot2 kybot3 ...]
        --container-name name of the kybot container. If ommited, use default kybot container defined in kyoto.conf.pl
        --target-dir Directory for leaving the documents.
