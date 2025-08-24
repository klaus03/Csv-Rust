use 5.032;
use warnings;

# *********************************************************************************
# Csv::Rust - A *.csv parser written in Rust
# AUTHOR    - Klaus Eichner <klaus03@gmail.com>
# DATE      - 26-JULY-2025
#
# COPYLEFT
#
# This is free software, you can copy, distribute, and modify it under the
# terms of the Free Art License https://artlibre.org/licence/lal/en/
#
# Dieses Werk ist frei, Sie sind berechtigt, es in Einhaltung der
# Bestimmungen der Lizenz Freie Kunst https://artlibre.org/licence/lal/de1-3/ zu
# kopieren, zu verbreiten und zu aendern.
#
# Cette oeuvre est libre, vous pouvez la copier, la diffuser et la modifier
# selon les termes de la Licence Art Libre https://artlibre.org/
# *********************************************************************************

package Csv::Rust;
our $VERSION = '0.02';

require Acme::XSLoad;
Acme::XSLoad::load_dll('MyProg::Csv', 'csv_get.dll');

=head1 NAME

Csv::Rust - A *.csv parser written in Rust

=head1 SYNOPSIS

    use Csv::Rust;

=head1 AUTHOR

Klaus Eichner <klaus03@gmail.com>, 26-JULY-2025

=cut

sub new {
    bless { diag => 0, sep => $_[1]{'sep_char'} };
}

sub getline {
    my $sep = $_[0]{'sep'};
    my $fh  = $_[1];

    my $GL_Str = '';
    my $GL_Qc  = 0;

    while (defined(my $line = <$fh>)) { chomp($line);
        $GL_Str .= $line."\n";

        if (length($GL_Str) > 5_000) {
            die "Maximum buffer length exceeded (", length($GL_Str), ") > 5_000";
        }

        $GL_Qc += $line =~ tr/"//; last unless $GL_Qc % 2;
    }

    if ($GL_Str eq '') {
        $_[0]{'diag'} = 2012;

        return;
    }

    my $result = MyProg::Csv::split_csv($sep, $GL_Str);

    $_[0]{'diag'} = $result->[0];

    return unless $result->[0] == 0;
    return $result->[1];
}

sub error_diag {
    return $_[0]{'diag'};
}

sub eof {
    return $_[0]{'diag'} == 2012;
}

sub print {
    my $sep = $_[0]{'sep'};
    my $fh  = $_[1];
    my $csv = $_[2];

    say {$fh} MyProg::Csv::line_csv($sep, $csv);
}

1;
