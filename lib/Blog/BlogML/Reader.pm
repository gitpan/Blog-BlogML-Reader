package Blog::BlogML::Reader;
#$Id: Reader.pm,v 1.13 2006/06/23 23:01:44 michael Exp $

use 5.008004;
use strict;
use warnings;
our $VERSION = 0.01;

our @ISA			= qw(Exporter);
our @EXPORT_OK		= qw(parse_blog find_latest find_by_cat meta cat post);
our %EXPORT_TAGS	= ('all' => \@EXPORT_OK);

use XML::Parser::Expat;
use HTTP::Date;
use Carp;

# define paths to things we are interested in keeping
my $blog_root		= '/blog';
my $blog_title		= "$blog_root/title";
my $blog_subtitle	= "$blog_root/sub-title";
my $blog_author		= "$blog_root/author";

my $cat				= "$blog_root/categories/category";
my $cat_title		= "$cat/title";

my $post			= "$blog_root/posts/post";
my $post_title		= "$post/title";
my $content			= "$post/content";
my $post_cat		= "$post/categories/category";

my %blog = ();
my $path = '/';
my $incat;
my $inpost;
my $this_post;
my $this_cat;
    
my $parser = new XML::Parser::Expat(
	Namespaces		=> 1,
	NoExpand		=> 1,
	ParseParamEnt	=> 0,
	ErrorContext	=> 2
);
$parser->setHandlers(
	'Start'	=> \&_on_start,
	'Char'	=> \&_on_char,
	'End'	=> \&_on_end,
);

my $now = time; # future posts are ignored


sub parse_blog {
	my ($blogml_pathname) = @_;
	$blogml_pathname or die 'Missing required argument: blogml_pathname.'; 
	
	if (%blog and ($blog{source} eq $blogml_pathname)) {
		return %blog;
	}
	else {
		%blog = (
			source	=> $blogml_pathname,
			meta	=> {},
			cats	=> {},
			posts	=> {},
		);
		eval{ $parser->parsefile($blogml_pathname) };
		(carp $@ and return 0) if $@;
	}
	return 1;
}

sub _on_start { # grab attributes of the tag here
	my ($p, $element, %att) = @_;
	$path = '/'.join('/', &XML::Parser::Expat::context, $element);
	
	if ($path eq $blog_author) {
		$blog{meta}{author_name} = $att{'name'};
		$blog{meta}{author_email} = $att{'email'};
	}
	elsif ($path eq $post) {
		unless (defined $att{'approved'} and $att{'approved'} eq 'false') {
			my $id = $att{'id'};
			my $url = $att{'post-url'};
			my $time = str2time($att{'date-created'});
			if ($time <= $now) {
				$this_post = {id=>$id, time=>$time, url=>$url, catrefs=>[]};
			}
		}
	}
	elsif ($path eq $cat) {
		unless (defined $att{'approved'} and $att{'approved'} eq 'false') {
			my $id = $att{'id'};
			my $time = str2time($att{'date-created'});
			my $parentref = $att{'parentref'};
			$this_cat = {id=>$id, time=>$time, parentref=>$parentref};
		}
	}
	elsif ($path eq $post_cat) {
		if ($this_post) {
			my $ref = $att{'ref'};
			push @{$this_post->{catrefs}}, $blog{meta}{cats}{$ref};
		}
	}
	elsif ($path eq $blog_root) {
		my $root_url = $att{'root-url'};
		$blog{meta}{root_url} .= $root_url;;
	}
}

sub _on_char { # grab character data here
	my ($p, $char) = @_;

	return unless ($char =~ /\S/);
	
	if ($this_post) {
		($path eq $post_title) and $this_post->{title} .= $char;
		($path eq $content) and $this_post->{content} .= "$char\n";
	}
	elsif ($this_cat) {
		($path eq $cat_title) and $this_cat->{title} .= $char;
	}
	elsif ($path eq $blog_title) {
		$blog{meta}{title} .= $char;
	}
	elsif ($path eq $blog_subtitle) {
		$blog{meta}{subtitle} .= $char;
	}
}

sub _on_end {
	my ($p, $element) = @_;
	
	$path = '/'.join('/', &XML::Parser::Expat::context, $element);

	if ($path eq $post and $this_post) {
		my $id = $this_post->{id};
		$blog{posts}{$id} = $this_post;
		undef $this_post;
	}
	elsif ($path eq $cat and $this_cat) {
		my $id = $this_cat->{id};
		$blog{meta}{cats}{$id} = $this_cat;
		undef $this_cat;
	}
}

sub find_latest {
	my ($limit) = @_;
	
	my @latest = sort {$b->{time} <=> $a->{time}} values %{$blog{posts}};	

	return ($limit and ($limit <= $#latest))? [@latest[0..$limit-1]] : \@latest;
}

sub find_by_cat {
	my ($cat_id) = @_;
	
	my @found = ();
	my @posts = @{find_latest()};
	
	POST: foreach my $post (@posts) {
		foreach my $catref (@{$post->{catrefs}}) {
			if ($cat_id == $catref->{id}) {
				push(@found, $post);
				next POST;
			}
		}
	}
	return \@found;
}

sub meta {
	my ($meta_key) = @_;
	
	if (defined $meta_key and $meta_key ne '') {
		return $blog{meta}{$meta_key};
	}
	else {
		return $blog{meta};
	}
}

sub post {
	my ($post_id) = @_;
	
	if (defined $post_id and $post_id ne '') {
		return $blog{posts}{$post_id};
	}
	else {
		return $blog{posts};
	}
}

1;

__END__

=head1 NAME

Blog::BlogML::Reader - Read data from a BlogML formatted XML document.

=head1 SYNOPSIS

	use Blog::BlogML::Reader;
	Blog::BlogML::Reader::parse_blog("this_blog.xml");
	
	# OR
	
	use Blog::BlogML::Reader qw(:all);
	parse_blog("that_blog.xml");
	my $posts = find_latest(10);
	
=head1 DESCRIPTION

BlogML is a standard for XML to define and store an entire blog. This module 
allows you to easily read most data in a given BlogML file.

=head2 DEPENDENCIES

=over 

=item * XML::Parser::Expat

This module uses C<XML::Parser::Expat> to parse the XML in the BlogML source file. I chose an expat based parser primarily for its speed. Check the docs for XML::Parser::Expat for further dependencies.

=item * HTTP::Date

This module uses C<HTTP::Date> to transform date strings into sortable timestamps. Neccessary when, for example, sorting blog posts and retrieving the most recent.

=back

=head2 EXPORT

None by default.

=head1 INTERFACE

Any or all of the following subroutines can be imported into the using script's namespace (or you may use the full package name to access them if you prefer). Specifying ":all" on the use line will include all of them into your script's namespace. Note that, for efficiency reasons, this module does not use an object-oriented interface, so the items listed below are not methods of any instance, just simple subroutines.

=over 3

=item * parse_blog("/path/to/blog.xml");

Call this first. This will build a data structure in memory, which can then be more conveniently accessed through the remaining subroutines. Calling this more than once is useless as the XML file will only be parsed once. The single argument is required, and must specify the filepath to a readable XML file that complies with the BlogML format.

=item * meta($meta_key);

If your BlogML document includes information about the blog it can be accessed via the hashref returned by this subroutine. If you only want a specific field you can specify it as an optional argument.

	my $meta = meta();
	print $meta->{title};
	print $meta->{subtitle};
	print $meta->{author_name};
	print $meta->{author_email};
	print $meta->{root_url};
	print $meta->{cats}{personal}{parent-ref};
	
	# OR
	
	my $title = meta('title');
	my $cats = meta('cats');
	print $cats->{news}{date-created};
	

=item * find_latest($limit);

This returns an array reference of posts from the blog, sorted most recent first. You may optionally pass along a limit (integer) to specify the maximum number of posts you want.

	my $latest_posts = find_latest(10);
	foreach my $post (@$latest_posts) {
		print $post->{title};
	}

=item * find_by_cat($cat_id);

Given a required category ID, this will return an array reference to every post that is associated with that category.

	my $reviews = find_by_cat('review');
	foreach my $post (@$reviews) {
		print $post->{title};
	}
	
=item * post($post_id);

If you already know the ID of the post you want, use this subroutine, which returns a hash reference to only that post;

	my $post = post(309);
	print $post->{title}, $post->{content};

=back

=head1 EXAMPLE
	
	use Blog::BlogML::Reader qw(:all);
	use Date::Format;
	parse_blog("/blogs/my_blog.xml");
	
	# get the latest posts
	my $posts = find_latest(12);
	
	foreach my $post (@$posts) {
		print "<h1>", $post->{title}, "</h1>";
		# You can use Date::Format to make a nicely formatted date string
		print "posted on: ", time2str("%o of %B %Y", $post->{time}), "<br>";
		print "<div>", $post->{content}, "</div>";
		
		# the categories associated with this post
		my $cat_listing = join(", ",  map{$_->{title}} @{$post->{catrefs}});
		$cat_listing and print "Filed under: $cat_listing";
	}

=head1 SEE ALSO

The website L<http://BlogML.com> has the latest documentation on the BlogML standard. Note that the reference document "example.xml" included with this module illustrates the expected format.

=head1 AUTHOR

Michael Mathews, E<lt>mmathews@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Michael Mathews

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.6 or,
at your option, any later version of Perl 5 you may have available.

=cut