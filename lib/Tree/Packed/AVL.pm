use Tree::Packed::AVL;

use strict;
use warnings;
use Carp;

require Tree::Packed;
our @ISA = qw(Tree::Packed::AVL);

my %defaults = (data_packer => '*');

sub new {
    my $class = shift;
    my %opts = (%defaults, @_);
    my $cmp = delete $opts{cmp} or croak
    $opts{extra_packer} = 'c';
    my $self = $class->SUPER::new(%opts);
    $self->{cmp} = $cmp;
    $self->{top} = undef;
    $self;
}

sub _dir { shift->extra(@_) };

sub top {
    my $tree = shift;
    $tree->{top};
}

sub insert {
    my ($tree, $data) = @_;
    my $node = $tree->allocate_node;
    $self->{data}[$node - 1] = $data;
    $tree->_insert($node);
}

sub traverse {
    my ($tree, $sub, $node) = @_;
    $node ||= $tree->{top};
    my @over;
    while (1) {
        if ($node) {
            push @over, $node;
            $node = $tree->left($node);
        }
        else {
            $node = pop @over;
            $sub->($tree->{data}[$node - 1], $node);
            $node = $tree->right($node);
        }
    }
}

sub lookup {
    my ($tree, $data, $node) = @_;
    my $cmp = $self->{cmp};
    $node ||= $tree->{top};
    while ($node) {
        my $o = $cmp->($data, $tree->data($node));
        return $node unless $o;
        $node = ($o < 0 ? $tree->left($node) : $tree->right($node));
    }
    ();
}

1;
