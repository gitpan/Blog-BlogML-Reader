# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Blog-BlogML-Reader.t'
# $Id: Blog-BlogML-Reader.t,v 1.1 2006/06/23 23:07:39 michael Exp $
use strict;
use warnings;
use Test::More tests=>23;
BEGIN { use_ok('Blog::BlogML::Reader', qw(:all)) };

ok(defined $Blog::BlogML::Reader::VERSION, "version is defined [$Blog::BlogML::Reader::VERSION]");

my $blogml_source = './example.xml';
ok(parse_blog($blogml_source), "example file parses without error [$blogml_source]");

my $meta = meta();
ok(defined $meta, "meta defined [$meta]");

parse_blog($blogml_source);
ok(meta() eq $meta, "parsing file with same pathname twice returns same object [".meta()."]");

my @meta_keys = keys %$meta;
ok(@meta_keys == 6, "meta keys has six entries [".join(", ", @meta_keys)."]");
ok($meta->{title} eq "Animal News", "meta title correct [".$meta->{title}."]");
ok($meta->{subtitle} eq "The wild side of the news.", "meta sub_title correct [".$meta->{subtitle}."]");
ok($meta->{author_name} eq "Tex McNabbit", "meta author_name correct [".$meta->{author_name}."]");
ok($meta->{author_email} eq 'tex@wcs.org', "meta author_name correct [".$meta->{author_email}."]");
ok($meta->{root_url} eq 'http://blog.wcs.org/', "meta root_url correct [".$meta->{root_url}."]");

my $posts = find_latest(3);
ok((scalar(@$posts) == 3), 'find_latest posts with three returns 3: ['.scalar(@$posts).']');

$posts = find_latest();
ok((scalar(@$posts) == 4), 'find_latest posts with unspecified returns 4: ['.scalar(@$posts).']');

my $latest = $posts->[0];
ok(($latest->{id} == 121), 'first latest post id is correct: ['.$latest->{id}.']');
ok(($latest->{title} eq "Cat saves baby's life"), 'first latest post title is correct: ['.$latest->{title}.']');

my $last = $posts->[-1];
ok(($last->{id} == 93), 'last latest post id is correct: ['.$last->{id}.']');
ok(($last->{title} eq "\"Veggie Dog Diet\" Fights Weight Gain"), 'last latest post title is correct: ['.$last->{title}.']');

my $post = post(122);
ok(($post->{title} eq 'Florida Island Residents Besieged by Iguanas'), 'specified post (122) title correct: ['.$post->{title}.']');
use Data::Dumper;
#print Dumper $post;
ok(($post->{catrefs}[0]{id} == 200), 'post 122 has correct category ['.$post->{catrefs}[0]{id}.']');

$post = post(121);
ok((@{$post->{catrefs}} == 3), 'post 121 has 3 categorys ['.scalar(@{$post->{catrefs}}).']');

my $cat = $meta->{cats}{201};
ok(($cat->{title} eq "Snakes"), 'cat 201 title is correct: ['.$cat->{title}.']');
ok(($cat->{parentref} == 200), 'cat 201 parentref is correct: ['.$cat->{parentref}.']');

$posts = find_by_cat(100);
ok((scalar(@$posts) == 2), 'find_by_cat posts with 100 returns 2: ['.scalar(@$posts).']');

__END__