use 5.032;
use warnings;

=head1 AUTHOR

Klaus Eichner <klaus03@gmail.com>, 26-JULY-2025

=head1 COPYLEFT

This is free software, you can copy, distribute, and modify it under the
terms of the Free Art License https://artlibre.org/licence/lal/en/

Dieses Werk ist frei, Sie sind berechtigt, es in Einhaltung der
Bestimmungen der Lizenz Freie Kunst https://artlibre.org/licence/lal/de1-3/ zu
kopieren, zu verbreiten und zu aendern.

Cette oeuvre est libre, vous pouvez la copier, la diffuser et la modifier
selon les termes de la Licence Art Libre https://artlibre.org/

=cut

use Test::More tests => 20;
use Text::CSV_XS;
use Csv::Rust;
use Data::Dumper;
$Data::Dumper::Useqq = 1;

run_tests('XS');
diag '-' x 100;

run_tests('RUST');
diag '-' x 100;

sub run_tests {
    my ($rt_type) = @_;

    write_csv  ( 1, ';', $rt_type, [[ "aaa", "bbb",  "ccc" ]], qq{aaa;bbb;ccc\n});
    write_csv  ( 2, ';', $rt_type, [[ "aaa", "b\nb", "ccc" ]], qq{aaa;"b\nb";ccc\n});
    write_csv  ( 3, ';', $rt_type, [[ "a,a", "b\"b", "c;c" ]], qq{a,a;"b""b";"c;c"\n});
    write_csv  ( 4, ',', $rt_type, [[ "aaa", "bbb",  "ccc" ]], qq{aaa,bbb,ccc\n});
    write_csv  ( 5, ',', $rt_type, [[ "aaa", "b\nb", "ccc" ]], qq{aaa,"b\nb",ccc\n});
    write_csv  ( 6, ',', $rt_type, [[ "a,a", "b\"b", "c;c" ]], qq{"a,a","b""b",c;c\n});

    round_trip ( 7, ';', $rt_type, [[ "a,a", "b\"b", "c;c" ]]);
    round_trip ( 8, ',', $rt_type, [[ "a,a", "b\"b", "c;c" ]]);
    round_trip ( 9, ',', $rt_type, [[ "" ], [ "\n\n", "\n" ]]);
    round_trip (10, ';', $rt_type, [[ "ab\x{01}cd" ]]);
}

sub write_csv {
    my ($st_num, $st_sep, $st_type, $st_arr, $st_txt) = @_;

    my $st_obj;

    if ($st_type eq 'XS') {
        $st_obj = Text::CSV_XS->new({ decode_utf8 => 0, sep_char => $st_sep, binary => 1, eol => $/ })
    }
    elsif ($st_type eq 'RUST') {
        $st_obj = Csv::Rust->new({ decode_utf8 => 0, sep_char => $st_sep, binary => 1, eol => $/ })
    }
    else {
        die "Assertion failure -- Found Type = '$st_type', but expected ('XS' or 'RUST')";
    }

    my $text = '';

    open my $ofh, '>', \$text or die "Error-0005: Can't open > '...' because $!";
    $st_obj->print($ofh, $_) for $st_arr->@*;
    close $ofh;

    diag '';
    diag sprintf('Sep %-9s, Line %s',
      "'".($st_sep  =~ s{([\x{00}-\x{1f}])}{sprintf('\\x{%02x}', ord($1))}xmsrge)."'",
      Dumper($st_arr) =~ s{\s+}' 'xmsgr =~ s{\A \s}''xmsr =~ s{\s \z}''xmsr =~ s{\A \$VAR\d+ \s* = \s*}''xmsr =~ s{; \z}''xmsr)
    ;

    is $text, $st_txt, sprintf('%-4s -- arr_%03d -- Write-Csv  => %s', $st_type, $st_num,
      "'".($text =~ s{([\x{00}-\x{1f}])}{sprintf('\\x{%02x}', ord($1))}xmsrge)."'")
    ;
}

sub round_trip {
    my ($st_num, $st_sep, $st_type, $st_arr) = @_;

    my $st_obj;

    if ($st_type eq 'XS') {
        $st_obj = Text::CSV_XS->new({ decode_utf8 => 0, sep_char => $st_sep, binary => 1, eol => $/ })
    }
    elsif ($st_type eq 'RUST') {
        $st_obj = Csv::Rust->new({ decode_utf8 => 0, sep_char => $st_sep, binary => 1, eol => $/ })
    }
    else {
        die "Assertion failure -- Found Type = '$st_type', but expected ('XS' or 'RUST')";
    }

    my $text = '';

    open my $ofh, '>', \$text or die "Error-0005: Can't open > '...' because $!";
    $st_obj->print($ofh, $_) for $st_arr->@*;
    close $ofh;

    my $data = [];
    open my $ifh, '<', \$text or die "Error-0007: Can't open < '...' because $!";
    while (my $row = $st_obj->getline($ifh)) {
        push @$data, [ @$row ];
    }
    close $ifh;

    diag '';
    diag sprintf('Sep %-9s, Line %s',
      "'".($st_sep  =~ s{([\x{00}-\x{1f}])}{sprintf('\\x{%02x}', ord($1))}xmsrge)."'",
      Dumper($st_arr) =~ s{\s+}' 'xmsgr =~ s{\A \s}''xmsr =~ s{\s \z}''xmsr =~ s{\A \$VAR\d+ \s* = \s*}''xmsr =~ s{; \z}''xmsr)
    ;

    diag sprintf('Text %s', "'".($text =~ s{([\x{00}-\x{1f}])}{sprintf('\\x{%02x}', ord($1))}xmsrge)."'");

    is_deeply $data, $st_arr, sprintf('%-4s -- arr_%03d -- Round-Trip', $st_type, $st_num);
}
