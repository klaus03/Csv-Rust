use 5.032;
use warnings;
no warnings qw(once);

package Acme::XSLoad;

if (defined(&DynaLoader::boot_DynaLoader) and !defined(&DynaLoader::dl_error)) {
    DynaLoader::boot_DynaLoader('DynaLoader');
}

my $Env_User = $ENV{'USERNAME'} // '';

sub load_dll {
    unless (@_ == 2) {
        die "Expected exactly 2 arguments to load_dll -- (", join(', ', map { "'$_'" } @_), ")";
    };

    my $path = "C:\\Users\\$Env_User\\Documents\\Ext\\Rust";

    my $module = $_[0];
    my $file   = $path.'\\'.$_[1];

    my $boots    = "$module\::bootstrap";
    my $bootname = "boot_$module"; $bootname =~ s/\W/_/g;

    @DynaLoader::dl_require_symbols = ($bootname);

    my $boot_symbol_ref;

    # Here we are loading the *.dll file:
    # Be advised that some rust *.dll's can have a potential dependency on other *.dll's that
    # live in the directory C:\Users\<name>\.rustup\toolchains\stable-x86_64-pc-windows-gnu\bin\
    # That is particularely true if the rust *.dll has been compiled with "rustc -C prefer-dynamic".
    #
    # There are 4 *.dll's in that directory:
    #
    #   1.) libgcc_s_seh-1.dll                       141_824 bytes
    #   2.) libwinpthread-1.dll                       53_760 bytes
    #   3.) rustc_driver-bf80254675d53dbd.dll    271_605_611 bytes
    #   4.) std-05f2cf19e11e0135.dll              15_162_247 bytes
    #
    # These 4 *.dll's should be copied into a new, separate directory, for example
    # C:\Users\<name>\Documents\Ext\FileRust\ and this new directory should be added to the %PATH%.
    #
    # Here is a commandline tool that lets you inspect the dependecies of a particular *.dll
    # Source: https://github.com/lucasg/Dependencies/releases
    #
    # Be advised that, for one single *.dll, the program runs for several minutes and the
    # output typically is several megabytes in size and more than 10_000 lines of text.
    #
    # C:\> Dependencies.exe -chain csv_get.dll >dump.txt
    # C:\> perl -nE "next unless /NOT_FOUND/; s/\A[\s\|\x{c3}]*//; next if /\Aext-ms-/ or /\Aapi-ms-/; print" <dump.txt
    #
    # Here is a sample ouput :
    #
    # UpdateAPI.dll (NOT_FOUND) :
    # PdmUtilities.dll (NOT_FOUND) :
    # HvsiFileTrust.dll (NOT_FOUND) :
    # HvsiFileTrust.dll (NOT_FOUND) :
    # HvsiFileTrust.dll (NOT_FOUND) :

    my $libref = DynaLoader::dl_load_file($file, 0)
      or die "Can't load '$file' for module $module: ", DynaLoader::dl_error();

    push(@DynaLoader::dl_librefs, $libref);  # record loaded object

    $boot_symbol_ref = DynaLoader::dl_find_symbol($libref, $bootname)
      or die "Can't find '$bootname' symbol in $file";

    push(@DynaLoader::dl_modules, $module); # record loaded module

    boot:
    my $xs = DynaLoader::dl_install_xsub($boots, $boot_symbol_ref, $file);

    push(@DynaLoader::dl_shared_objects, $file); # record files loaded

    return &$xs($module);
}

1;

__END__

=head1 NAME

Acme::XSLoad - Shamelessly stolen from XSLoader which was originally
written by Ilya Zakharevich

=head1 SYNOPSIS

    use Acme::XSLoad;

=head1 AUTHOR

Klaus Eichner <klaus03@gmail.com>, 26-JULY-2025

Shamelessly stolen from XSLoader which was originally
written by Ilya Zakharevich

=head1 COPYLEFT

This is free software, you can copy, distribute, and modify it under the
terms of the Free Art License https://artlibre.org/licence/lal/en/

Dieses Werk ist frei, Sie sind berechtigt, es in Einhaltung der
Bestimmungen der Lizenz Freie Kunst https://artlibre.org/licence/lal/de1-3/ zu
kopieren, zu verbreiten und zu aendern.

Cette oeuvre est libre, vous pouvez la copier, la diffuser et la modifier
selon les termes de la Licence Art Libre https://artlibre.org/

=cut
