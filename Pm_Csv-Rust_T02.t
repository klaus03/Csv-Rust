use 5.032;
use warnings;

use Test::More tests => 24;
use Test::Output;

use Text::CSV_XS;
use Csv::Rust;
use Acme::DirName qw(ad_local);
use File::Slurp;

my $Env_TFile1 = $ENV{'TEMP'}.'\\Crust1.txt';

ds_parse('T01' => qq{Bat;man;"Robin\nH""ere";"I;go";;;;agëïöain\n},     qq{0000: ([u]'Bat', [u]'man', [u]'Robin\\x{0a}H"ere', [u]'I;go', [u]'', [u]'', [u]'', [u]'agëïöain')}     );
ds_parse('T02' => qq{Bat;man;"Robin\nH""ere";"I;go";;;;ag\x{3c8}ain\n}, qq{0000: ([u]'Bat', [u]'man', [u]'Robin\\x{0a}H"ere', [u]'I;go', [u]'', [u]'', [u]'', [u]'ag\\x{3c8}ain')});
ds_parse('T03' => qq{Bat;m\ta n;"Robin\nH""ere";"I;go";;;;again\n},     qq{0000: ([u]'Bat', [u]'m\\x{09}a n', [u]'Robin\\x{0a}H"ere', [u]'I;go', [u]'', [u]'', [u]'', [u]'again')});
ds_parse('T04' => qq{Bat;m\ta n;"Robin\nH""ere";"I;go";;;;ag"in\n},     qq{2034: ()}                                                                                              );
ds_parse('T05' => qq{"ab},                                              qq{2027: ()}                                                                                              );
ds_parse('T06' => qq{ },                                                qq{0000: ([u]' ')}                                                                                        );
ds_parse('T07' => qq{},                                                 qq{2012: ()}                                                                                              );

ds_print('T08' => [ qq{ab c}, qq{def}, qq{g;hi} ],                                 qq{<"ab c";def;"g;hi"\\x{0d}\\x{0a}>}                               );
ds_print('T09' => [ qq{xy\tc}, qq{v\nvv}, qq{uuu} ],                               qq{<"xy\\x{09}c";"v\\x{0d}\\x{0a}vv";uuu\\x{0d}\\x{0a}>}            );
ds_print('T10' => [ qq{jk\nl}, qq{m"""""n}, do { my $s = qq{äëïöü};        $s } ], qq{<"jk\\x{0d}\\x{0a}l";"m""""""""""n";äëïöü\\x{0d}\\x{0a}>}        );
ds_print('T11' => [ qq{jk\nl}, qq{m"""""n}, do { my $s = qq{äëïöü\x{3c8}}; $s } ], qq{<"jk\\x{0d}\\x{0a}l";"m""""""""""n";äëïöü\\x{3c8}\\x{0d}\\x{0a}>});
ds_print('T12' => [ qq{opq}, qq{r\x{3c8}st}, qq{ö\x{3c8}ü} ],                      qq{<opq;r\\x{3c8}st;ö\\x{3c8}ü\\x{0d}\\x{0a}>}                      );

sub ds_parse {
    say '# ----------------------------------------------------------------------------------';
    say "# Parse_0_Inp = [", (utf8::is_utf8($_[1]) ? 'u' : '-'), "]'", ($_[1] =~ s{([^\x{20}-\x{ff}])}{sprintf('\\x{%02x}', ord($1))}xmsgre), "'";
    say '#';

    write_file($Env_TFile1, { binmode => ':utf8' }, $_[1]);

    my $csv_xs_semi = Text::CSV_XS ->new({ decode_utf8 => 0, sep_char => ';', binary => 1, eol => $/ });
    my $csv_rs_semi = Csv::Rust    ->new({ decode_utf8 => 0, sep_char => ';', binary => 1, eol => $/ });

    my $ifh;

    open $ifh, '<:utf8', $Env_TFile1 or die "Error-0005: Can't open <:utf8 '$Env_TFile1' because $!";
    my $P1_Csv = $csv_rs_semi->getline($ifh);
    close $ifh;

    my $P1_Stat = $csv_rs_semi->error_diag + 0;

    open $ifh, '<:utf8', $Env_TFile1 or die "Error-0010: Can't open <:utf8 '$Env_TFile1' because $!";
    my $P2_Csv = $csv_xs_semi->getline($ifh);
    close $ifh;

    my $P2_Stat = $csv_xs_semi->error_diag + 0;

    my $P1_Line = join(', ', map { pline($_) } @$P1_Csv);
    my $P2_Line = join(', ', map { pline($_) } @$P2_Csv);

    my $P1_Text = sprintf('%04d', $P1_Stat).": (". $P1_Line.")";
    my $P2_Text = sprintf('%04d', $P2_Stat).": (". $P2_Line.")";

    say "# Parse_1_Out = ", $P1_Text;
    say "# Parse_2_Out = ", $P2_Text;
    say '';

    is $P1_Text, $_[2], 'Test '.$_[0].'-a';
    is $P2_Text, $_[2], 'Test '.$_[0].'-b';

    say '';
}

sub ds_print {
    say '# ----------------------------------------------------------------------------------';
    say "# Print_0_Inp = <", join(', ',
      map { "[".(utf8::is_utf8($_) ? 'u' : '-')."]'".(s{([^\x{20}-\x{ff}])}{sprintf('\\x{%02x}', ord($1))}xmsgre)."'" } $_[1]->@* ), ">";
    say '#';

    my $csv_xs_semi = Text::CSV_XS ->new({ decode_utf8 => 0, sep_char => ';', binary => 1, eol => $/ });
    my $csv_rs_semi = Csv::Rust    ->new({ decode_utf8 => 0, sep_char => ';', binary => 1, eol => $/ });

    my ($ifh, $ofh);

    my @D1 = $_[1]->@*;

    open $ofh, '>:utf8', $Env_TFile1 or die "Error-0020: Can't open >:utf8 '$Env_TFile1' because $!";
    $csv_rs_semi->print($ofh, [ @D1 ]);
    close $ofh;

    my $P1_Str = read_file($Env_TFile1, { binmode => ':utf8' });

    my @E1 = $_[1]->@*;

    open $ofh, '>:utf8', $Env_TFile1 or die "Error-0025: Can't open >:utf8 '$Env_TFile1' because $!";
    $csv_xs_semi->print($ofh, [ @E1 ]);
    close $ofh;

    my $P2_Str = read_file($Env_TFile1, { binmode => ':utf8' });

    my $P1_Text = "<".($P1_Str =~ s{([^\x{20}-\x{ff}])}{sprintf('\\x{%02x}', ord($1))}xmsgre).">";
    my $P2_Text = "<".($P2_Str =~ s{([^\x{20}-\x{ff}])}{sprintf('\\x{%02x}', ord($1))}xmsgre).">";

    say "# Print_1_Out = ", $P1_Text;
    say "# Print_2_Out = ", $P2_Text;
    say '';

    is $P1_Text, $_[2], 'Test '.$_[0].'-a';
    is $P2_Text, $_[2], 'Test '.$_[0].'-b';

    say '';
}

sub pline {
    defined($_[0]) ?
    "[".(utf8::is_utf8($_[0]) ? 'u' : '-')."]'".
    ($_[0] =~ s{([^\x{20}-\x{ff}])}{sprintf('\\x{%02x}', ord($1))}xmsgre)."'" :
    '';
}
