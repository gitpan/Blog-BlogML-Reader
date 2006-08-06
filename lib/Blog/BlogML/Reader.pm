package Blog::BlogML::Reader;
# $Id: Reader.pm,v 1.5 2006/08/05 22:20:29 michael Exp $

our $VERSION = 1.01;

use 5.008006;
use strict;
use warnings;

use base 'XML::Parser::Expat';
use HTTP::Date;
use Carp;

sub new {
	my $class = shift;
	
	my $source = shift or carp q(new(): Missing required argument: $source.);
	
	my %filter = @_;
	$filter{after}  &&= ($filter{after} =~ /\D/)?  str2time($filter{after}):$filter{after};
	$filter{before} &&= ($filter{before} =~ /\D/)? str2time($filter{before}):$filter{before};
	
	my $self = new XML::Parser::Expat(
		Namespaces		=> 1,
		NoExpand		=> 1,
		ParseParamEnt	=> 0,
		ErrorContext	=> 2,
	);
	$self->setHandlers(
		Start	=> \&_on_start,
		Char	=> \&_on_char,
		End		=> \&_on_end,
	);
	
	$self->{blog} = {
		source	=> $source,
		meta	=> {},
		cats	=> {},
		posts	=> [],
		filter => \%filter,
	};
	$self->{current_context} = undef;
	$self->{this_post} = undef;
	$self->{this_cat} = undef;
	
	$self->{count}	= 0;
	$self->{from}	= (defined $filter{from})? $filter{from}:0;
	$self->{to}		= (defined $filter{to})? $filter{to}:undef;
	
	eval{ $self->parsefile($self->{blog}{source}) };
	carp $@ if $@;
	
	bless $self, $class;
}

my %context = (
	blog_root		=> '/blog',
	blog_title		=> '/blog/title',
	blog_subtitle	=> '/blog/sub-title',
	blog_author		=> '/blog/author',

	cat				=> '/blog/categories/category',
	cat_title		=> '/blog/categories/category/title',

	post			=> '/blog/posts/post',
	post_title		=> '/blog/posts/post/title',
	post_content	=> '/blog/posts/post/content',
	post_cat		=> '/blog/posts/post/categories/category',
);

sub _on_start {
	my ($self, $element, %att) = @_;
	$self->{current_context} = '/'.join('/', $self->context, $element);
	
	if ($self->{current_context} eq $context{post}
		and $att{approved} eq 'true') {
			
		$self->{count}++;
		if ($self->{count} < $self->{from}) {
			return;
		}
		
		if (defined $self->{to} and $self->{count} > $self->{to}) {
			$self->finish();
			return;
		}
		
		if ($self->{blog}{filter}{post}
			and $att{id} ne $self->{blog}{filter}{post}) {
			return;
		}
		$att{'date-created'} = str2time($att{'date-created'});
		if ($self->{blog}{filter}{before}
			and $att{'date-created'} > $self->{blog}{filter}{before}) {
			return;
		}
		if ($self->{blog}{filter}{after}
			and $att{'date-created'} < $self->{blog}{filter}{after}) {
			$self->finish();
			return;
		}
		
		$self->{this_post} = {
			id		=> $att{id},
			url		=> $att{'post-url'},
			time	=> $att{'date-created'},
			title	=> '',
			content	=> '',
			cats	=> [],
		};
	}
	elsif ($self->{current_context} eq $context{cat}
		   and $att{approved} eq 'true') {
		
		$self->{this_cat} = {
			id		=> $att{id},
			parent	=> $att{parentref},
			title	=> '',
		};
	}
	elsif ($self->{current_context} eq $context{blog_author}) {
		$self->{blog}{meta}{author} = $att{name};
		$self->{blog}{meta}{email} = $att{email};
	}
	elsif ($self->{current_context} eq $context{blog_root}) {
		$self->{blog}{meta}{url} = $att{'root-url'};
		$self->{blog}{meta}{time} = str2time($att{'date-created'});
	}
	elsif ($self->{current_context} eq $context{post_cat}
		and $self->{this_post}) {
		push @{$self->{this_post}{cats}}, $att{ref};
	}
}

sub _on_char {
	my ($self, $char) = @_;
	
	_trim($char);
	
	if ($self->{current_context} eq $context{post_title}
		and $self->{this_post}) {
		$self->{this_post}{title} .= (($self->{this_post}{title} and $char)? ' ':'').$char;
	}
	elsif ($self->{current_context} eq $context{post_content}
		   and $self->{this_post}) {
		$self->{this_post}{content} .= (($self->{this_post}{content} and $char)? "\n":'').$char;
	}
	elsif ($self->{current_context} eq $context{cat_title}
		   and $self->{this_cat}) {
		$self->{this_cat}{title} .= (($self->{this_cat}{title} and $char)? ' ':'').$char;
	}
	elsif ($self->{current_context} eq $context{blog_title}) {
		$self->{blog}{meta}{title} .= (($self->{blog}{meta}{title} and $char)? ' ':'').$char;
	}
	elsif ($self->{current_context} eq $context{blog_subtitle}) {
		$self->{blog}{meta}{subtitle} .= (($self->{blog}{meta}{subtitle} and $char)? ' ':'').$char;
	}
}

sub _on_end {
	my ($self, $element) = @_;
	$self->{current_context} = '/'.join('/', $self->context, $element);
	
	if ($self->{current_context} eq $context{post}
		and $self->{this_post}) {
		if (defined $self->{blog}{filter}{cat}
			and !grep /$self->{blog}{filter}{cat}/, @{$self->{this_post}{cats}}) {
			return;
		}
		push @{$self->{blog}{posts}}, $self->{this_post};
		
		undef $self->{this_post};
	}
	elsif ($self->{current_context} eq $context{cat}
		   and $self->{this_cat}) {
		$self->{blog}{cats}{$self->{this_cat}->{id}} = $self->{this_cat};
		
		undef $self->{this_cat};
	}
}

sub posts {
	my ($self) = @_;
	return $self->{blog}{posts};
}

sub cats {
	my ($self) = @_;
	return $self->{blog}{cats};
}

sub meta {
	my ($self) = @_;
	return $self->{blog}{meta};
}

sub _trim {
	$_[0] =~ s/(^\s+|\s+$)//g;
}

1;

=pod

=head1 NAME

Blog::BlogML::Reader - Read data from a BlogML formatted XML document.

=head1 SYNOPSIS

  use Blog::BlogML::Reader;
  
  my $reader = new Blog::BlogML::Reader('some/file/blogml.xml');
  my @posts = @{$reader->{blog}{posts};

=head1 DEPENDENCIES

=over 

=item * XML::Parser::Expat

This module uses C<XML::Parser::Expat> to parse the XML in the BlogML source file. I chose an expat based parser primarily for its speed. Check the docs for XML::Parser::Expat for further dependencies.

=item * HTTP::Date

This module uses C<HTTP::Date> to transform date strings into sortable timestamps. Necessary when, for example, sorting blog posts and retrieving the most recent.

=back

=head1 EXPORT

None.

=head1 INTERFACE

=head2 filters

When creating a new reader, the default bahaviour is to parse and load the entire BlogML structure into memory. This can be inefficient if, for example, you have ten-thousand posts and only want the first one. For this reason it is possible (and recommended) that you give the parser some limits before letting it go. This is done by adding filters to the constructor.

=over 3

=item * to=>I<n>

Limits the parser to only the first I<n> post in the BlogML file.

  $reader = new Blog::BlogML::Reader('blogml.xml', to=>3);

=item * from=>I<n>

The parser will only start at the I<n>th item in the BlogML file. Note that this can optionally be used with C<to> in order to limit the parser to a range of posts.

  $reader = new Blog::BlogML::Reader('blogml.xml', from=>11, to=>20);

=item * before=>I<date>

Limits the parser to posts with a creation-date before I<date>.

  $reader = new Blog::BlogML::Reader('blogml.xml', before=>"2006-05-01T00:00:00");

=item * after=>I<date>

Limits the parser to posts with a creation-date after I<date>. Can optionally be used with C<before> to limit the parser to a range of dates.

  $reader = new Blog::BlogML::Reader('blogml.xml', after=>"2006-08-01T00:00:00");

=item * id=>I<n>

If you know the specific post you want, why parse the entire file? 

  $reader = new Blog::BlogML::Reader('blogml.xml', id=>123);

=item * cat=>I<n>

Limits the parser to only the posts that belong to the category with the given id.

  $reader = new Blog::BlogML::Reader('blogml.xml', cat=>'news');

=back

=head2 methods

=over 3

=item * meta()

Returns a hash ref of information about the blog.

  my $meta = $reader->meta();
  print $meta->{title};
  print $meta->{author}, $meta->{email};

=item * posts()

Returns an array ref of blog posts.

  my $posts = $reader->posts();
  print $posts->[0]{title};
  
  foreach my $post (@$posts) {
    print $post->{title};
    print $post->{content};
  }

=item * cats()

Returns a hash ref of blog categories, with the keys bsing the category id.

  my $cats = $reader->cats();
  print $cats->{'news'}{title};

=back

=head1 SEE ALSO

The website L<http://BlogML.com> has the latest documentation on the BlogML standard. Note that the reference document "example.xml" included with this module illustrates the expected format.

=head1 AUTHOR

Michael Mathews, E<lt>mmathews@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Michael Mathews

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself, either Perl version 5.8.6 or, at your option, any later version of Perl 5 you may have available.

=cut

__END__