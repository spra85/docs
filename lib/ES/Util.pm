package ES::Util;

use strict;
use warnings;
use v5.10;

use File::Copy::Recursive qw(fcopy rcopy);
use Capture::Tiny qw(capture_merged tee_merged);

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(run $Opts build_chunked build_single);
our $Opts      = {};

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
            --xsl-file resources/website_chunked.xsl
            --icons
            ),
        '-a', 'icons=resources/asciidoc-8.6.8/images/icons/',
        '--destination-dir=' . $build,
        '--xsltproc-opts', '--stringparam chunk.section.depth 1',
        $index
    );

    my @warn = grep {/(WARNING|ERROR)/} split "\n", $output;
    die join "\n", @warn
        if @warn;

    my ($chunk_dir) = grep { -d and /\.chunked$/ } $build->children
        or die "Couldn't find chunk dir in <$build>";

    to_html5($chunk_dir);

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
            --icons
            ),
        '-a', 'icons=resources/asciidoc-8.6.8/images/icons/',
        '--xsltproc-opts',
        "--stringparam generate.toc '$toc'",
        '--destination-dir=' . $dest,
        $index
    );

    my @warn = grep {/(WARNING|ERROR)/} split "\n", $output;
    die join "\n", @warn
        if @warn;
    to_html5($dest);
}

#===================================
sub to_html5 {
#===================================
    my $dir = shift;
    for my $file ( $dir->children ) {
        next if $file->is_dir or $file->basename !~ /\.html$/;
        my $contents = $file->slurp( iomode => '<:encoding(UTF-8)' );
        $contents =~ s/^<!DOCTYPE[^>]+>/<!DOCTYPE html>/;
        $contents =~ s/\s+xmlns="[^"]*"//g;
        $file->spew( iomode => '>:utf8', $contents );
    }
}

#===================================
sub run (@) {
#===================================
    my @args = @_;
    my ( $out, $ok );
    if ( $Opts->{verbose} ) {
        say "Running: @args";
        ( $out, $ok ) = tee_merged { system(@args) == 0 };
    }
    else {
        ( $out, $ok ) = capture_merged { system(@args) == 0 };
    }

    die "Error executing: @args\n$out"
        unless $ok;

    return $out;
}

1
