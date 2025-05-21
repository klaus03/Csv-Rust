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

Klaus Eichner <klaus03@gmail.com>

Shamelessly stolen from XSLoader which was originally
written by Ilya Zakharevich

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2024 by Klaus Eichner

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the terms of the artistic license 2.0,
see http://www.opensource.org/licenses/artistic-license-2.0.php

=cut
