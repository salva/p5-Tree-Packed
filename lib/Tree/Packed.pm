package Tree::Packed;

our $VERSION = '0.01';

use strict;
use warnings;
use Carp;
use 5.010;

# ($parent, $left, $right, @extra) = unpack $tree->{node_packer}, substr($tree->{nodes}, $node_offset, $node_size);


my %default = (data_packer => '', extra_packer => '');

sub _pack_len {
    my $packer = shift;
    no warnings 'uninitialized';
    length pack $packer => ();
}

sub new {
    my ($class, %opt) = @_;
    my %tree = ( nodes => '' , free => 0);
    $tree{$_} = delete($opt{$_}) // $default{$_} for keys %default;

    if ($opts{data_packer} eq '*') {
        $opts{data_packer} = '';
        $tree{data} = [];
    }

    $tree{node_packer} = 'lll' . $tree{data_packer} . $tree{extra_packer};
    $tree->{node_size } = _pack_len($tree{node_packer });
    $tree->{data_size } = _pack_len($tree{data_packer });
    $tree->{extra_size} = _pack_len($tree{extra_packer});

    $tree->{extra_offset} =                       - $tree->{extra_size};
    $tree->{data_offset } = $tree->{extra_offset} - $tree->{data_size };

    if (my $reserve = delete $opt{reserve}) {
        $tree{nodes} = 'x' x $tree{node_size};
        $tree{nodes} x= $reserve;
        $_ = '';
    }

    my $tree = \%tree;
    bless $tree, $class;
}

sub allocate_node {
    my $tree = shift;
    my $node_size = $tree->{node_size};
    if ($tree->{free}) {
        my $node = $tree->{free};
        my $offset = ($node - 1) * $node_size;
        $tree->{free} = unpack(l => substr($tree->{nodes}, $offset + 8, 4));
        substr($tree->{nodes}, $offset, $node_size, "\x00" x $node_size);
        return $node;
    }

    $tree->{nodes} .= "\x00" x $node_size;
    return length($tree->{nodes}) / $tree->{node_size};
}

sub free_node {
    my ($tree, $node) = @_;
    substr($tree->{nodes}, ($node - 1) * $tree->{node_size}, 12, pack(lll => 0, 0, $tree->{free}));
    $tree->{free} = $node;
}

sub parent {
    my ($tree, $node) = @_;
    unpack(l => substr($tree->{nodes}, ($node - 1) * $tree->{node_size}, 4));
}

sub left {
    my ($tree, $node, $child) = @_;
    if (@_ > 2) {
        my $ns = $tree->{node_size};
        my $old = unpack(l => substr($tree->{nodes}, ($node - 1) * $ns + 4, 4, pack(l => $child)));
        substr($tree->{nodes}, ($child  - 1) * $ns, 4, pack(l => $parent)) if $child > 0;
        substr($tree->{nodes}, ($old    - 1) * $ns, 4, "\x00\x00\x00\x00") if $old   > 0;
        return $old;
    }
    unpack(l => substr($tree->{nodes}, ($node - 1) * $ns + 4, 4, pack(l => $child))));
}

sub right {
    my ($tree, $node, $child) = @_;
    if (@_ > 2) {
        my $ns = $tree->{node_size};
        my $old = unpack(l => substr($tree->{nodes}, ($node - 1) * $ns + 8, 4, pack(l => $child)));
        substr($tree->{nodes}, ($child  - 1) * $ns, 4, pack(l => $parent)) if $child > 0;
        substr($tree->{nodes}, ($old    - 1) * $ns, 4, "\x00\x00\x00\x00") if $old   > 0;
        return $old;
    }
    unpack(l => substr($tree->{nodes}, ($node - 1) * $ns + 8, 4, pack(l => $child))));
}


sub data {
    my $tree = shift;
    my $node = shift;
    if (my $data = $tree->{data}) {
        if (@_) {
            $data->[$node - 1] = shift;
            return;
        }
        $data->[$node - 1];
    }
    else {
        my $offset = $node * $tree->{node_size} + $tree->{data_offset};
        if (@_) {
            substr($tree->{nodes}, $offset, $tree->{data_size},
                   pack($tree->{data_packer} => @_));
            return;
        }
        unpack($tree->{data_packer} => substr($tree->{nodes}, $offset, $tree->{data_size}));
    }
}

sub extra {
    my $tree = shift;
    my $node = shift;
    my $offset = $node * $tree->{node_size} + $tree->{extra_offset};
    if (@_) {
        substr($tree->{nodes}, $offset, $tree->{extra_size},
               pack($tree->{extra_packer} => @_));
        return;
    }
    unpack($tree->{extra_packer} => substr($tree->{nodes}, $offset, $tree->{extra_size}));
}

sub leftist {
    my ($tree, $node) = @_;
    my $ns = $tree->{node_size};
    while (1) {
        $next = unpack(l => substr($tree->{nodes}, ($last - 1) * $ns + 4, 4));
        $next > 0 or return $node;
        $node = $next;
    }
}

sub rightist {
    my ($tree, $node) = @_;
    my $ns = $tree->{node_size};
    while (1) {
        $next = unpack(l => substr($tree->{nodes}, ($last - 1) * $ns + 8, 4));
        $next > 0 or return $node;
        $node = $next;
    }
}

sub free_subtree {
    my ($tree, $node) = @_;
    if ($node > 0) {
        $old_free = $tree->{free};
        $tree->{free} = $node;
        my $rightist = $tree->rightist($node);
        my $data = $tree->{data};
        while ($node > 0) {
            $data->[$node - 1] = undef if $data;
            my $left = $tree->left($node);
            if ($left > 0) {
                $tree->right($rightist, $left);
                $rightist = $tree->rightist($left);
            }
            $node = $tree->right($node);
        }
        $tree->right($rightist, $old_free);
    }
}

1;

__END__

=head1 NAME

Tree::Packed - Base module for tree data structures stored as packed strings

=head1 SYNOPSIS

  use Tree::Packed;
  my $tree = Tree::Packed->new;


=head1 DESCRIPTION

Stub documentation for Tree::Packed, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Salvador Fandino, E<lt>salva@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Salvador Fandino

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
