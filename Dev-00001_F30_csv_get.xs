// *********************************************************************************
// Csv::Rust - A *.csv parser written in Rust
// AUTHOR    - Klaus Eichner <klaus03@gmail.com>
// DATE      - 26-JULY-2025
//
// COPYLEFT
//
// This is free software, you can copy, distribute, and modify it under the
// terms of the Free Art License https://artlibre.org/licence/lal/en/
//
// Dieses Werk ist frei, Sie sind berechtigt, es in Einhaltung der
// Bestimmungen der Lizenz Freie Kunst https://artlibre.org/licence/lal/de1-3/ zu
// kopieren, zu verbreiten und zu aendern.
//
// Cette oeuvre est libre, vous pouvez la copier, la diffuser et la modifier
// selon les termes de la Licence Art Libre https://artlibre.org/
// *********************************************************************************

HEAD_BEGIN:
    typedef struct {
        int   len;
        char* dat;
    } mtxt_t;

    typedef struct {
        short unsigned int eno;
        int                len;
        mtxt_t*            dat;
    } mlst_t;

    typedef struct {
        SV* dat;
    } sli_t;

    #define TCAP 512

    extern mtxt_t get_mtxt(int, char*, char, char);
    extern mlst_t get_mlst(int, char*, char);

    extern void  rel_mtxt(mtxt_t);
    extern void  rel_mlst(mlst_t);
HEAD_END:

AV*
split_csv(char pt_sep, SV* scalar)
    CODE:
        if (pt_sep < 1 || pt_sep > 127) {
            croak("ABORT-0010: split_csv(sep = %d) is not in range ASCII 1 .. 127", pt_sep);
        }

        char  pt_type;
        char* pt_str;
        int   pt_len;

        if (scalar && SvOK(scalar)) {
            if (SvUTF8(scalar)) {
                pt_type = 'U';

                pt_str = SvPVutf8_nolen(scalar); // see also sv_utf8_upgrade(sv)
            }
            else {
                pt_type = 'I';

                pt_str = SvPV_nolen(scalar);
            }

            // https://perldoc.perl.org/perlguts
            // You can get [...] the current length of the string stored in an SV with the following macros:
            // STRLEN name_length = SvCUR(cv); /* in bytes */

            pt_len = SvCUR(scalar);
        }
        else {
            pt_type = 'N';
            pt_str  = "";
            pt_len  = 0;
        }

        AV* cli = newAV();

        mlst_t my_lst = get_mlst(pt_len, pt_str, pt_sep);

        for (size_t i = 0; i < my_lst.len; i++) {
            mtxt_t my_txt = my_lst.dat[i];

            SV* nsv = newSVpv(my_txt.dat, my_txt.len);

            if (pt_type == 'U') {
                SvUTF8_on(nsv);
            }

            av_push(cli, nsv);
        }

        RETVAL = newAV();
        sv_2mortal((SV*)RETVAL);
 
        av_push(RETVAL, newSViv((int)my_lst.eno));
        av_push(RETVAL, newRV_inc((SV*)cli));

        rel_mlst(my_lst);

    OUTPUT:
        RETVAL

SV*
line_csv(char pt_sep, AV* fields)
    CODE:
        if (pt_sep < 1 || pt_sep > 127) {
            croak("ABORT-0030: line_csv(sep = %d) is not in range ASCII 1 .. 127", pt_sep);
        }

        size_t rs_cap = TCAP;
        size_t rs_len = 0;
        char*  rs_str = malloc(rs_cap + 1); // +1 for the null-terminator

        if (rs_str == NULL) {
            croak("ABORT-0040: line_csv() -- Can't malloc(%d)", rs_cap + 1);
        }

        strcpy(rs_str, "");

        size_t alen = av_len(fields) + 1;

        sli_t* SLI = (sli_t*)malloc(sizeof(sli_t) * alen);

        if (SLI == NULL) {
            free(rs_str);
            croak("ABORT-0050: line_csv() -- Can't malloc(%d) -- sizeof(sli_t) = %d", alen, sizeof(sli_t));
        }

        int gl_iso = 0;
        int gl_utf = 0;
        int gl_non = 0;

        for (size_t i = 0; i < alen; i++) {
            SV** mfetch = av_fetch(fields, i, 0);
            SV*  scalar = mfetch ? *mfetch : NULL;

            if (scalar && SvOK(scalar)) {
                SLI[i].dat = scalar;

                if (SvUTF8(scalar)) {
                    gl_utf++;
                }
                else {
                    gl_iso++;
                }
            }
            else {
                SLI[i].dat = NULL;

                gl_non++;
            }
        }

        for (size_t i = 0; i < alen; i++) {
            SV* scalar = SLI[i].dat;

            char  pt_real;
            char  pt_type;
            char* pt_str;
            int   pt_len;

            if (scalar) {
                if (SvROK(scalar)) { // It's a reference of some kind
                    svtype st = SvTYPE(SvRV(scalar)); // dereference

                    if (st == SVt_PVAV) {
                        pt_real = 'A'; // It's an array reference
                        pt_str  = "#Array";
                    }
                    else if (st == SVt_PVHV) {
                        pt_real = 'H'; // It's a hash reference
                        pt_str  = "#Hash";
                    }
                    else if (st == SVt_PVCV) {
                        pt_real = 'C'; // It's a code reference
                        pt_str  = "#Code";
                    }
                    else {
                        pt_real = 'G'; // Some other kind of reference (glob, regex, etc.)
                        pt_str  = "#Glob";
                    }

                    pt_type = 'I';
                    pt_len  = strlen(pt_str);
                }
                else {
                    if (SvIOK(scalar)) {
                        pt_real = 'I'; // Integer value
                    }
                    else if (SvNOK(scalar)) {
                        pt_real = 'D'; // Double value
                    }
                    else if (SvPOK(scalar)) {
                        pt_real = 'S'; // String value
                    }
                    else if (!SvOK(scalar)) {
                        pt_real = 'U'; // undef
                    }
                    else {
                        pt_real = 'Z'; // unknown...
                    }

                    if (SvUTF8(scalar)) {
                        pt_type = 'U';
                    }
                    else {
                        pt_type = 'I';
                    }

                    if (gl_utf) {
                        pt_str = SvPVutf8_nolen(scalar); // see also sv_utf8_upgrade(sv)
                    }
                    else {
                        pt_str = SvPV_nolen(scalar);
                    }

                    pt_len = SvCUR(scalar);
                }
            }
            else {
                pt_real = 'N';
                pt_type = 'N';
                pt_str  = "#NA";
                pt_len  = strlen(pt_str);
            }

            //~ printf("D090: i = %d -- get_mtxt(pt_len=%d, pt_real='%c', pt_str='%s', pt_sep='%c', alen=%d);\n", i, pt_len, pt_real, pt_str, pt_sep, alen);

            mtxt_t my_txt = get_mtxt(pt_len, pt_str, pt_sep, (i + 1 == alen ? 1 : 0));

            char*  nw_str = my_txt.dat;
            size_t nw_len = my_txt.len;

            if (rs_len + nw_len > rs_cap) {
                char* ol_str = rs_str;

                rs_cap = rs_len + nw_len + TCAP;
                rs_str = malloc(rs_cap + 1); // +1 for the null-terminator

                if (rs_str == NULL) {
                    free(ol_str);
                    free(SLI);
                    croak("ABORT-0060: line_csv() -- Can't malloc(%d)", rs_cap + 1);
                }

                memcpy(rs_str, ol_str, rs_len);
                free(ol_str);
            }

            memcpy(rs_str + rs_len, nw_str, nw_len + 1); // +1 to copy the null-terminator
            rs_len += nw_len;

            rel_mtxt(my_txt);
        }

        SV* nsv = newSVpv(rs_str, rs_len);

        if (gl_utf) {
            SvUTF8_on(nsv);
        }

        RETVAL = nsv;

        free(rs_str);
        free(SLI);

    OUTPUT:
        RETVAL
