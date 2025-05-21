use 5.032;
use warnings;

use Test::More tests => 56;
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

    single_test( 1, qq{abc;def;ghi\njkl;äöü;ëïù\n}, ';', '*', [[ 'abc', 'def', 'ghi' ], [ 'jkl','äöü', 'ëïù' ]], 2012, $rt_type);
    single_test( 2, qq{"abc;def";ghi\n},            ';', '*', [[ 'abc;def', 'ghi' ]],                            2012, $rt_type);
    single_test( 3, qq{abc;def";ghi\n},             ';', '*', [],                                                2034, $rt_type);
    single_test( 4, qq{a;"";b;"""";c\n},            ';', '*', [[ 'a', '', 'b', '"', 'c' ]],                      2012, $rt_type);
    single_test( 5, qq{m;n\n},                      ';', '*', [[ 'm', 'n' ]],                                    2012, $rt_type);
    single_test( 6, qq{m;n;\n},                     ';', '*', [[ 'm', 'n', '' ]],                                2012, $rt_type);
    single_test( 7, qq{o;p;;\n},                    ';', '*', [[ 'o', 'p', '', '' ]],                            2012, $rt_type);
    single_test( 8, qq{q;r;;;\n},                   ';', '*', [[ 'q', 'r', '', '', '' ]],                        2012, $rt_type);
    single_test( 9, qq{"d";;;"e";;;\n},             ';', '*', [[ 'd', '', '', 'e', '', '', '' ]],                2012, $rt_type);
    single_test(10, qq{"f";;;"g"\n},                ';', '*', [[ 'f', '', '', 'g' ]],                            2012, $rt_type);
    single_test(11, qq{"t\n\na\nu";;"\n\n\n"\n},    ';', '*', [[ "t\n\na\nu", '', "\n\n\n" ]],                   2012, $rt_type);
    single_test(12, qq{\n},                         ';', '*', [[ '' ]],                                          2012, $rt_type);
    single_test(13, qq{},                           ';', '*', [],                                                2012, $rt_type);
    single_test(14, qq{;},                          ';', '*', [[ '', '' ]],                                      2012, $rt_type);
}

sub single_test {
    my ($st_num, $st_data, $st_sep, $st_lcount, $st_exp_arr, $st_exp_rc, $st_type) = @_;

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

    my ($st_act_arr, $st_act_rc) = read_csv($st_obj, $st_data, $st_lcount);

    diag '';
    diag sprintf('Sep %-9s, Line %s',
      "'".($st_sep  =~ s{([\x{00}-\x{1f}])}{sprintf('\\x{%02x}', ord($1))}xmsrge)."'",
      "'".($st_data =~ s{([\x{00}-\x{1f}])}{sprintf('\\x{%02x}', ord($1))}xmsrge)."'")
    ;

    is_deeply $st_act_arr, $st_exp_arr, sprintf('%-4s -- arr_%03d => %s', $st_type, $st_num,
      Dumper($st_exp_arr) =~ s{\s+}' 'xmsgr =~ s{\A \s}''xmsr =~ s{\s \z}''xmsr =~ s{\A \$VAR\d+ \s* = \s*}''xmsr =~ s{; \z}''xmsr)
      or diag 'Actual: '.(
      Dumper($st_act_arr) =~ s{\s+}' 'xmsgr =~ s{\A \s}''xmsr =~ s{\s \z}''xmsr =~ s{\A \$VAR\d+ \s* = \s*}''xmsr =~ s{; \z}''xmsr)
    ;

    is $st_act_rc, $st_exp_rc, sprintf('%-4s -- rc__%03d => %d', $st_type, $st_num, $st_exp_rc);
}

sub read_csv {
    my ($rc_obj, $rc_data, $rc_lcount) = @_;

    my $struct = [];

    $rc_obj->{'_ERROR_DIAG'} = 0;

    open my $ifh, '<', \$rc_data or die "Error-0010: Can't open < '...' because $!";

    my $lno;

    while (my $row = $_[0]->getline($ifh)) { $lno++;
        push @$struct, [ @$row ];

        last unless $rc_lcount eq '*' or $rc_lcount > $lno;
    }

    close $ifh;

    return ($struct, $_[0]->error_diag);
}
