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

    typedef struct {
        char  type;
        char  uses_ref;
        char  uses_utf8;
        char* mstr;
        int   mlen;
    } ginf_t;

    #define TCAP 512
    #define RLEN 20

    extern mtxt_t get_mtxt(int, char*, char, char);
    extern mlst_t get_mlst(int, char*, char);

    extern void rel_mtxt(mtxt_t);
    extern void rel_mlst(mlst_t);

    static char* make_text(char*, char*, char mt_char);
HEAD_END:

AV*
split_csv(char pt_sep, SV* scalar)
    CODE:
        if (pt_sep < 1 || pt_sep > 127) {
            croak("ABORT-0010: split_csv(sep = %d) is not in range ASCII 1 .. 127", pt_sep);
        }

        char my_buffer[RLEN];

        ginf_t my_info = get_info(aTHX_ scalar, (char*)&my_buffer);
        mlst_t my_lst  = get_mlst(my_info.mlen, my_info.mstr, pt_sep);

        AV* my_AV = newAV();

        for (size_t i = 0; i < my_lst.len; i++) {
            mtxt_t my_txt = my_lst.dat[i];
            SV*    my_SV  = newSVpv(my_txt.dat, my_txt.len);

            if (my_info.uses_utf8) {
                SvUTF8_on(my_SV);
            }

            av_push(my_AV, my_SV);
        }

        RETVAL = newAV(); sv_2mortal((SV*)RETVAL);
 
        av_push(RETVAL, newSViv((int)my_lst.eno));
        av_push(RETVAL, newRV_inc((SV*)my_AV));

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

        size_t sl_len = av_len(fields) + 1;
        sli_t* sl_arr = (sli_t*)malloc(sizeof(sli_t) * sl_len);

        if (sl_arr == NULL) {
            free(rs_str);
            croak("ABORT-0050: line_csv() -- Can't malloc(%d) -- sizeof(sli_t) = %d", sl_len, sizeof(sli_t));
        }

        int sl_utf8 = 0;

        for (size_t i = 0; i < sl_len; i++) {
            SV** mfetch = av_fetch(fields, i, 0);
            SV*  scalar = mfetch ? *mfetch : NULL;

            sl_arr[i].dat = scalar;

            if (var_utf8(aTHX_ scalar)) {
                sl_utf8++;
            }
        }

        for (size_t i = 0; i < sl_len; i++) {
            SV* scalar = sl_arr[i].dat;

            char my_buffer[RLEN];

            ginf_t my_info = get_info(aTHX_ scalar, (char*)&my_buffer);
            mtxt_t my_txt  = get_mtxt(my_info.mlen, my_info.mstr, pt_sep, (i + 1 == sl_len ? 1 : 0));

            char*  nw_str = my_txt.dat;
            size_t nw_len = my_txt.len;

            if (rs_len + nw_len > rs_cap) {
                char* ol_str = rs_str;

                rs_cap = rs_len + nw_len + TCAP;
                rs_str = malloc(rs_cap + 1); // +1 for the null-terminator

                if (rs_str == NULL) {
                    free(ol_str);
                    free(sl_arr);
                    rel_mtxt(my_txt);

                    croak("ABORT-0060: line_csv() -- Can't malloc(%d)", rs_cap + 1);
                }

                memcpy(rs_str, ol_str, rs_len);
                free(ol_str);
            }

            memcpy(rs_str + rs_len, nw_str, nw_len + 1); // +1 to copy the null-terminator
            rs_len += nw_len;

            rel_mtxt(my_txt);
        }

        RETVAL = newSVpv(rs_str, rs_len);

        if (sl_utf8) {
            SvUTF8_on(RETVAL);
        }

        free(rs_str);
        free(sl_arr);

    OUTPUT:
        RETVAL

HEAD_BEGIN:
    static char var_utf8(pTHX_ SV* gu_scalar) {
        if (!gu_scalar) {
            return 0;
        }

        if (SvROK(gu_scalar)) { // It's a reference of some kind
            return 0;
        }

        if (SvPOK(gu_scalar) && SvUTF8(gu_scalar)) {
            return 1;
        }

        return 0;
    }

    static ginf_t get_info(pTHX_ SV* gi_scalar, char* gi_buffer) {
        ginf_t gi_result = { '-', 0, 0, "", 0 };

        if (!gi_scalar) {
            return gi_result;
        }

        if (SvROK(gi_scalar)) { // It's a reference of some kind
            gi_result.uses_ref = 1;

            svtype gt_deref = SvTYPE(SvRV(gi_scalar)); // dereference

            if (gt_deref == SVt_PVAV) { // It's an array reference
                gi_result.type = 'A';
            }
            else if (gt_deref == SVt_PVHV) { // It's a hash reference
                gi_result.type = 'H';
            }
            else if (gt_deref == SVt_PVCV) { // It's a code reference
                gi_result.type = 'C';
            }
            else { // Some other kind of reference (glob, regex, etc.)
                gi_result.type = 'G';
            }

            gi_result.mstr = make_text(gi_buffer, "#Ref(_)", gi_result.type);
            gi_result.mlen = strlen(gi_result.mstr);
        }
        else {
            char no_svpv = 0;

            if (SvIOK(gi_scalar)) { // Integer value
                gi_result.type = 'I';
            }
            else if (SvNOK(gi_scalar)) { // Double value
                gi_result.type = 'D';
            }
            else if (SvPOK(gi_scalar)) { // String value
                gi_result.type = 'S';

                if (SvUTF8(gi_scalar)) {
                    gi_result.uses_utf8 = 1;
                }
            }
            else if (!SvOK(gi_scalar)) { // undef
                gi_result.type = 'U';
                no_svpv = 1;
            }
            else { // unknown...
                gi_result.type = 'Z';
                no_svpv = 1;
            }

            if (no_svpv) {
                gi_result.mstr = make_text(gi_buffer, "#Nul(_)", gi_result.type);
                gi_result.mlen = strlen(gi_result.mstr);
            }
            else {
                if (gi_result.uses_utf8) {
                    gi_result.mstr = SvPVutf8_nolen(gi_scalar); // see also sv_utf8_upgrade(sv)
                }
                else {
                    gi_result.mstr = SvPV_nolen(gi_scalar);
                }

                // https://perldoc.perl.org/perlguts
                // You can get [...] the current length of the string stored in an SV with the following macros:
                // STRLEN name_length = SvCUR(cv); /* in bytes */

                gi_result.mlen = SvCUR(gi_scalar);
            }
        }

        return gi_result;
    }

    static char* make_text(char* mt_buffer, char* mt_template, char mt_char) {
        int mt_len = strlen(mt_template);

        for (int i = 0; i < RLEN; i++) {
            if (i < mt_len) {
                mt_buffer[i] = mt_template[i] == '_' ? mt_char : mt_template[i];
            }
            else {
                mt_buffer[i] = '\0';
            }
        }

        mt_buffer[RLEN - 1] = '\0'; // Just to be on the safe side : Add a final NULL

        return mt_buffer;
    }
HEAD_END:
