package ES::Book;

use strict;
use warnings;
use v5.10;
use Data::Dumper qw(Dumper);
use ES::Util qw(run $Opts build_chunked);
use Path::Class();
use ES::Repo();
use File::Copy::Recursive qw(fcopy rcopy);
use ES::Toc();

#===================================
sub new {
#===================================
    my ( $class, %args ) = @_;

    my $title = $args{title}
        or die "No <title> specified: " . Dumper( \%args );

    my $dir = $args{dir}
        or die "No <dir> specified for book <$title>";

    my $repo = ES::Repo->get_repo( $args{repo} );

    my $prefix = $args{prefix}
        or die "No <prefix> specified for book <$title>";

    my $index = $args{index}
        or die "No <index> specfied for book <$title>";

    my $branches = $args{branches} || $repo->branches;
    my $current  = $args{current}  || $repo->current;

    die "<branches> must be an array in book <$title>"
        unless ref $branches eq 'ARRAY';

    die "Current branch <$current> is not in <branches> in book <$title>"
        unless grep { $current eq $_ } @$branches;

    bless {
        title    => $title,
        dir      => $dir->subdir($prefix),
        repo     => $repo,
        prefix   => $prefix,
        index    => Path::Class::file($index),
        branches => $branches,
        current  => $current
    }, $class;
}

#===================================
sub build {
#===================================
    my $self = shift;

    say "Book: " . $self->title;

    my $repo     = $self->repo;
    my $branches = $self->branches;
    my $current  = $self->current;
    my $index    = $self->index;
    my $src_path = $index->parent;
    my $toc      = ES::Toc->new( $self->title );
    my $dir      = $self->dir;
    $dir->mkpath;

    for my $branch (@$branches) {

        say " - Branch: $branch";

        my $branch_dir = $dir->subdir($branch);

        my $changed = !-e $branch_dir
            || $repo->has_changed( $src_path, $branch );

        if ($changed) {
            say "   - Building";
            $repo->checkout( $src_path, $branch );
            build_chunked( $repo->dir->file($index), $branch_dir );
            $repo->mark_done( $src_path, $branch );
        }
        else {
            say "   - Reusing existing";
        }

        my $url = $branch . '/index.html';

        if ( $branch eq $current ) {
            say "   - Copying to current";
            my $current_dir = $dir->subdir('current');
            $current_dir->rmtree;
            rcopy( $branch_dir, $current_dir )
                or die "Couldn't copy <$branch_dir> to <$current_dir>: $!";
            $url = 'current/index.html';
        }
        $toc->add_entry(
            {   title => 'Version: ' . $branch,
                url   => $url
            }
        );

    }

    my $versions;
    if ( @$branches > 1 ) {
        $versions = $self->prefix . '/index.html';
        $toc->write($dir);
    }

    return {
        title    => $self->title .($versions ? " -- $current" : '') ,
        url      => $self->prefix . '/current/index.html',
        versions => $versions,
    };
}

#===================================
sub title { shift->{title}}
sub dir { shift->{dir}}
sub repo { shift->{repo}}
sub prefix { shift->{prefix}}
sub index { shift->{index}}
sub branches { shift->{branches}}
sub current { shift->{current}}
#===================================

1;
