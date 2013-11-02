#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;

use FindBin;
use lib "$FindBin::RealBin/lib";
use ES::Util qw(run $Opts build_chunked build_single sha_for);
use Getopt::Long;
use YAML qw(LoadFile);
use Path::Class qw(dir file);
use Browser::Open qw(open_browser);

use ES::Repo();
use ES::Book();
use ES::Toc();
use ES::LinkCheck();

our $Old_Pwd = dir()->absolute;
init_env();

our $Conf = LoadFile('conf.yaml');

GetOptions(
    $Opts,    #
    'all', 'push',    #
    'single',  'doc=s', 'out=s', 'toc', 'open', 'chunk=i',
    'lenient', 'verbose'
);

$Opts->{doc}       ? build_local( $Opts->{doc} )
    : $Opts->{all} ? build_all()
    :                usage();

#===================================
sub build_local {
#===================================
    my $doc = shift;

    my $index = file($doc)->absolute($Old_Pwd);
    die "File <$doc> doesn't exist" unless -f $index;

    say "Building HTML from $doc";

    my $dir = dir( $Opts->{out} || 'html_docs' )->absolute($Old_Pwd);
    my $html;
    if ( $Opts->{single} ) {
        $dir->rmtree;
        $dir->mkpath;
        build_single( $index, $dir, %$Opts );
        $html = $index->basename;
        $html =~ s/\.[^.]+$/.html/;
    }
    else {
        build_chunked( $index, $dir, %$Opts );
        $html = 'index.html';
    }

    $html = $dir->file($html);

    say "Done";
    if ( $Opts->{open} ) {
        say "Opening: $html";
        open_browser($html);
    }
    else {
        say "See: $html";
    }
}

#===================================
sub build_all {
#===================================
    init_repos();

    my $build_dir = $Conf->{paths}{build}
        or die "Missing <paths.build> in config";

    $build_dir = dir($build_dir);
    $build_dir->mkpath;

    my $contents = $Conf->{contents}
        or die "Missing <contents> configuration section";

    my $toc = ES::Toc->new( $Conf->{contents_title} || 'Guide' );
    build_entries( $build_dir, $toc, @$contents );

    say "Writing main TOC";
    $toc->write($build_dir);

    my $links = ES::LinkCheck->new($build_dir);

    for ( @{ $Conf->{extra_links} } ) {
        my $repo = ES::Repo->get_repo( $_->{repo} );
        my $file = $repo->dir->file( $_->{file} );
        say "Checking links in: $file";
        $links->check_file($file);
    }

    if ( $links->check ) {
        say $links->report;
    }
    else {
        die $links->report;
    }

    push_changes($build_dir)
        if $Opts->{push};
}

#===================================
sub build_entries {
#===================================
    my ( $build, $toc, @entries ) = @_;

    while ( my $entry = shift @entries ) {
        my $title = $entry->{title}
            or die "Missing title for entry: " . Dumper($entry);

        if ( my $sections = $entry->{sections} ) {
            my $section_toc = ES::Toc->new($title);
            $toc->add_entry($section_toc);
            build_entries( $build, $section_toc, @$sections );
            next;
        }
        my $book = ES::Book->new( dir => $build, %$entry );
        $toc->add_entry( $book->build );
    }
    return $toc;
}

#===================================
sub init_repos {
#===================================
    say "Updating repositories";

    my $repos_dir = $Conf->{paths}{repos}
        or die "Missing <paths.repos> in config";

    $repos_dir = dir($repos_dir);
    $repos_dir->mkpath;

    my $conf = $Conf->{repos}
        or die "Missing <repos> in config";

    for my $name ( sort keys %$conf ) {
        my $repo = ES::Repo->new(
            name => $name,
            dir  => $repos_dir,
            %{ $conf->{$name} }
        );
        $repo->update_from_remote();
    }
}

#===================================
sub push_changes {
#===================================
    my $build_dir = shift;

    run qw( git add -A), $build_dir;

    if ( run qw(git status -s -- ), $build_dir ) {
        say "Commiting changes";
        run qw(git commit -m), 'Updated docs';

        say "Rebasing changes";
        run qw(git pull --rebase );
    }

    my $remote_sha = eval {
        my $remote = run qw(git rev-parse --symbolic-full-name @{u});
        chomp $remote;
        return sha_for($remote);
    } || '';

    if ( sha_for('HEAD') ne $remote_sha ) {
        say "Pushing changes";
        run qw(git push origin HEAD );
    }
    else {
        say "No changes to push";
    }
}

#===================================
sub init_env {
#===================================
    chdir($FindBin::RealBin) or die $!;

    $ENV{SGML_CATALOG_FILES} = $ENV{XML_CATALOG_FILES} = join ' ',
        file('resources/docbook-xsl-1.78.1/catalog.xml')->absolute,
        file('resources/docbook-xml-4.5/catalog.xml')->absolute;

    $ENV{PATH}
        = dir('resources/asciidoc-8.6.8/')->absolute . ':' . $ENV{PATH};

    eval { run( 'xsltproc', '--version' ) }
        or die "Please install <xsltproc>";
}

#===================================
sub usage {
#===================================
    say <<USAGE;

    Build local docs:

        $0 --doc path/to/index.asciidoc [opts]

        Opts:
          --single          Generate a single HTML page, instead of
                            a chunking into a file per chapter
          --toc             Include a TOC at the beginning of the page.
          --out dest/dir/   Defaults to ./html_docs.
          --chunk 1         Also chunk sections into separate files
          --open            Open the docs in a browser once built.
          --lenient         Ignore linking errors
          --verbose

        WARNING: Anything in the `out` dir will be deleted!

    Build docs from all repos in conf.yaml:

        $0 --all [opts]

        Opts:
          --push            Commit the updated docs and push to origin
          --verbose

USAGE
}
