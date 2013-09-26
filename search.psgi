#!/usr/bin/env perl

use strict;
use warnings;
use Encode qw(encode_utf8);
use Plack::Request;
use Plack::Builder;
use Plack::Response;
use ElasticSearch;

use FindBin;
use lib "$FindBin::RealBin/lib";
use ES::Util qw(run);

chdir($FindBin::RealBin);

our $host = 'localhost:9200';
our $es = ElasticSearch->new( servers => $host );

builder {
    mount '/elastic-search-website/' => \&old_doc_search;
    mount '/search/'                 => \&doc_search;
    mount '/status'                  => \&status;
};

#===================================
sub status {
#===================================
    my $req = Plack::Request->new( shift() );
    my $result
        = eval { run(qw(git show --shortstat _index)); }
        || $@
        || 'Unknown error';
    return [ 200, [ 'Content-Type' => 'text/plain' ], [$result] ];

}

#===================================
sub doc_search {
#===================================
    my $req      = Plack::Request->new( shift() );
    my $callback = $req->param('callback');
    my $q        = $req->param('q');

    my $result = $es->search(
        index  => 'docs',
        fields => [ 'title', 'abbr', 'url', 'path' ],
        query  => {
            multi_match => {
                query  => $q,
                fields => [
                    'title',         'title.shingles',
                    'title.ngrams',  'text',
                    'text.shingles', 'text.ngrams',
                    'book'
                ],
                minimum_should_match => '50%',
            }
        },
        size    => 10,
        as_json => 1
    );

    $result = $callback . '(' . $result . ')'
        if $callback;

    return [
        200,
        [ 'Content-Type' => 'application/json' ],
        [ encode_utf8($result) ]
    ];

}

#===================================
sub old_doc_search {
#===================================
    my $req      = Plack::Request->new( shift() );
    my $callback = $req->param('callback');
    my $q        = $req->param('q');

    my $result = $es->search(
        index  => 'es_docs',
        fields => [ 'title', 'category', 'url' ],
        query  => {
            multi_match => {
                query  => $q,
                fields => [
                    'title',   'title.shingles^2',
                    'content', 'content.shingles^10'
                ],
                minimum_should_match => '60%',
            }
        },
        size    => 10,
        as_json => 1
    );

    $result = $callback . '(' . $result . ')'
        if $callback;

    return [
        200,
        [ 'Content-Type' => 'application/json' ],
        [ encode_utf8($result) ]
    ];

}
