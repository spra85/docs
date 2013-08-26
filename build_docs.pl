#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use YAML qw(LoadFile);
use Path::Class qw(dir file);
use File::Copy::Recursive qw(fcopy rcopy);
use Capture::Tiny qw(capture_merged tee_merged);
use Data::Dumper;
use Getopt::Long;
use v5.10;

our $Old_Pwd = dir()->absolute;
chdir($FindBin::Bin) or die $!;

our $Conf = LoadFile('conf.yaml');

init_env();

our %Opts = ();
GetOptions(
    \%Opts,    #
    'all', 'push',    #
    'single', 'doc=s', 'out=s', 'toc'
);

$Opts{doc}       ? build_local( $Opts{doc} )
    : $Opts{all} ? build_all()
    :              usage();

#===================================
sub build_local {
#===================================
    my $doc = shift;

    my $index = file($doc)->absolute($Old_Pwd);
    die "File <$doc> doesn't exist" unless -f $index;

    say "Building HTML from $doc";

    my $dir = dir( $Opts{out} || $Old_Pwd->subdir('html_docs') );
    my $html;
    if ( $Opts{single} ) {
        $dir->rmtree;
        $dir->mkpath;
        build_single( $index, $dir, $Opts{toc} );
        $html = 'index.html';
    }
    else {
        build_chunked( $index, $dir );
        $html = $index->basename;
        $html =~ s/\.[^.]+/.html/;
    }

    say "Done";
    say "See: " . $dir->file($html);
}

#===================================
sub build_all {
#===================================
    my $contents = $Conf->{contents}
        or die "Missing <contents> configuration section";

    my $build_dir = make_dir('build');

    update_repos();

    my $title = $Conf->{contents_title} || 'Guide';
    my $toc = build_entries( $build_dir, @$contents );
    write_toc( $title, $build_dir, 'index', $toc );

    push_changes($build_dir)
        if $Opts{push};
}

#===================================
sub build_entries {
#===================================
    my ( $build, @entries ) = @_;

    my @toc;
    while ( my $entry = shift @entries ) {

        my $title = $entry->{title}
            or die "Missing title for entry: " . Dumper($entry);

        if ( my $sections = $entry->{sections} ) {
            my $entries = build_entries( $build, @$sections );
            push @toc, { title => $title, sections => $entries };
            next;
        }

        say "Processing book: $title";

        eval {
            my $repo_name = $entry->{repo}
                or die "No <repo> specified";

            my $conf = $Conf->{repos}{$repo_name}
                or die "Unknown repo <$repo_name>";

            my $book = $entry->{book}
                or die "No <book> specified";

            my $index = $entry->{index}
                or die "No <index> specified";

            my $repo     = $conf->{dir};
            my $branches = $conf->{branches};
            my $current  = $conf->{current};
            $index = file( $repo, $index );

            local $ENV{GIT_WORK_TREE} = dir($repo)->stringify;
            local $ENV{GIT_DIR}       = $repo->subdir('.git')->stringify;

            my $book_dir = $build->subdir($book);
            $book_dir->mkpath;

            my @books = build_branches( $book_dir, $index, $branches );
            push @toc, finalize( $book, $title, \@books, $current );

        } or die "ERROR processing book <$title>: $@";
    }
    return \@toc;
}

#===================================
sub finalize {
#===================================
    my ( $book, $title, $books, $current, ) = @_;

    say " - Finalizing";

    my ($src) = grep { $_->{branch} eq $current } @$books;
    my $dest = $src->{dir}->parent->subdir('current');
    $dest->rmtree;

    $src->{url} =~ s{^[^/]+}{current};

    rcopy( $src->{dir}, $dest )
        or die "Couldn't copy <$src->{dir}> to <$dest>: $!";

    return { title => $title, url => $book . '/' . $src->{url} }
        if @$books == 1;

    write_toc( $title, $dest->parent, 'index', $books );

    return {
        title    => "$title -- $current",
        url      => $book . '/' . $src->{url},
        versions => $book . '/index.html'
    };

}

#===================================
sub build_branches {
#===================================
    my ( $build, $index, $branches ) = @_;

    my $src_path = $index->parent;
    my @books;

    for my $branch (@$branches) {
        say " - Branch: $branch";
        my $dir = $build->subdir($branch);
        my $changed = select_branch( $branch, $src_path, !-e $dir );

        if ($changed) {
            build_chunked( $index, $dir );
            mark_built($branch);
        }

        my $html = $index->basename;
        $html =~ s/\.[^.]+$/.html/;

        push @books,
            {
            title  => 'Version: ' . $branch,
            url    => $branch . '/' . $html,
            branch => $branch,
            dir    => $dir,
            };
    }
    return @books;
}

#===================================
sub build_chunked {
#===================================
    my ( $index, $dest ) = @_;

    fcopy( 'resources/styles.css', $index->parent )
        or die "Couldn't copy <styles.css> to <" . $index->parent . ">: $!";

    my $build  = $dest->parent;
    my $output = run( qw(
            a2x
            -v
            -d book
            -f chunked
            --xsl-file resources/website_chunked.xsl),
        '--destination-dir=' . $build,
        '--xsltproc-opts', '--stringparam chunk.section.depth 1',
        $index
    );

    my @warn = grep {/(WARNING|ERROR)/} split "\n", $output;
    die join "\n", @warn
        if @warn;

    my ($chunk_dir) = grep { -d and /\.chunked$/ } $build->children
        or die "Couldn't find chunk dir in <$build>";

    $dest->rmtree;
    rename $chunk_dir, $dest
        or die "Couldn't move <$chunk_dir> to <$dest>: $!";

}

#===================================
sub build_single {
#===================================
    my ( $index, $dest, $toc ) = @_;

    $toc = $toc ? 'book toc' : '';

    fcopy( 'resources/styles.css', $index->parent )
        or die "Couldn't copy <styles.css> to <" . $index->parent . ">: $!";

    my $output = run( qw(
            a2x
            -v
            -d book
            -f xhtml
            --xsl-file resources/website.xsl
            --xsltproc-opts),
        "--stringparam generate.toc '$toc'",
        '--destination-dir=' . $dest,
        $index
    );

    my @warn = grep {/(WARNING|ERROR)/} split "\n", $output;
    die join "\n", @warn
        if @warn;

}

#===================================
sub update_repos {
#===================================
    my $repos = $Conf->{repos}
        or die "Missing <repos> configuration section";

    my $dir = make_dir('repos');

    for my $name ( sort keys %$repos ) {

        say "Updating repository: $name";

        eval {
            my $conf = $repos->{$name};

            my $url = $conf->{url}
                or die "No <url> specified";

            die "No <branches> specified"
                unless ref $conf->{branches} eq 'ARRAY';

            die "No <current> branch specified"
                unless $conf->{current};

            die "Current <$conf->{current}> not listed in branches"
                unless grep { $_ eq $conf->{current} } @{ $conf->{branches} };

            my $repo = $conf->{dir} = $dir->subdir($name);

            local $ENV{GIT_DIR} = $repo->subdir('.git') . '';

            if ( $repo->stat ) {
                say " - Fetching";

                #                run( 'git', 'fetch' );
            }
            else {
                say " - Cloning from <$url>";
                run( 'git', 'clone', $url, $repo );
            }
            1;

        } or die "ERROR updating repository <$name>: $@";
    }
}

#===================================
sub select_branch {
#===================================
    my ( $branch, $path, $force ) = @_;

    my $current = sha_for( 'refs/heads/' . "_docs_$branch" );
    my $new     = sha_for( 'refs/remotes/origin/' . $branch )
        or die "Remote branch <origin/$branch> doesn't exist";

    return unless $force || has_changed( $path, $current, $new );

    run( 'git', 'checkout', '-B', '_build_docs', "origin/$branch" );
    return 1;
}

#===================================
sub mark_built {
#===================================
    my $branch = shift;
    run( 'git', 'checkout', '-B', "_docs_$branch",
        "refs/remotes/origin/$branch" );
    run( 'git', 'branch', '-D', '_build_docs' );
}

#===================================
sub push_changes {
#===================================
    my $build_dir = shift;

    run( 'git', 'add', '-A', $build_dir );

    if ( run( 'git', 'status', '-s', '--', $build_dir ) ) {
        say "Commiting changes";
        run( 'git', 'commit', '-m', 'Updated docs' );

        say "Rebasing changes";
        run( 'git', 'pull', '--rebase' );

        say "Pushing changes";
        run( 'git', 'push', 'origin', 'HEAD' );

        say "Changes pushed";
    }
    else {
        say "No changes to commit";
    }
}

#===================================
sub sha_for {
#===================================
    my $rev = shift;
    return eval { run( 'git', 'rev-parse', $rev ) } || '';
}

#===================================
sub has_changed {
#===================================
    my ( $path, $start, $end ) = @_;
    return 1 unless $start;
    return if $start eq $end;
    return !!run( 'git', 'diff', '--shortstat', $start, $end, '--', $path );
}

#===================================
sub write_toc {
#===================================
    my ( $title, $build, $name, $toc ) = @_;

    say "Writing TOC: $name.html";
    my $adoc = join "\n", "= $title", '', _toc( 1, @$toc );
    my $index = $build->file("$name.asciidoc");
    $index->spew( iomode => '>:utf8', $adoc );
    build_single( $index, $build );
    $index->remove;
}

#===================================
sub _toc {
#===================================
    my $indent = shift;
    my @adoc   = '';
    while ( my $entry = shift @_ ) {
        my $prefix = '  ' . ( '*' x $indent ) . ' ';

        if ( my $sections = $entry->{sections} ) {
            push @adoc, $prefix . $entry->{title};
            push @adoc, _toc( $indent + 1, @$sections );
        }
        else {
            my $versions
                = $entry->{versions}
                ? " link:$entry->{versions}" . "[(other versions)]"
                : '';
            push @adoc,
                  $prefix
                . "link:$entry->{url}"
                . "[$entry->{title}]"
                . $versions;
        }
    }
    return @adoc;
}

#===================================
sub run {
#===================================
    my @args = @_;

    my ( $out, $ok ) = capture_merged { system(@args) == 0 };

    die "Error executing: @args\n$out"
        unless $ok;

    return $out;
}

#===================================
sub make_dir {
#===================================
    my $key  = shift;
    my $path = $Conf->{paths}{$key}
        or die "Missing <paths.$key> in config";
    my $dir = dir($path);
    $dir->mkpath;
    return $dir;
}

#===================================
sub init_env {
#===================================
    chdir($FindBin::Bin) or die $!;

    $ENV{SGML_CATALOG_FILES} = $ENV{XML_CATALOG_FILES} = join ' ',
        file('resources/docbook-xsl-1.78.1/catalog.xml'),
        file('resources/docbook-xml-4.5/catalog.xml');

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

        $0 --doc path/to/index.asciidoc [--out dest/dir/ --single --toc]

        Opts:
          --single          Generate a single HTML page.
          --toc             Include a TOC at the beginning of the page.
          --out dest/dir/   Defaults to ./html_docs.

        WARNING: Anything in the `out` dir will be deleted!

    Build docs from all repos in conf.yaml:

        $0 --all [--push]

        Opts:
          --push            Commit the updated docs and push to origin

USAGE
}
