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
    static char  appd_text(pTHX_ char**, size_t*, char*);
HEAD_END:

SV*
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

        // Alright, XS-land can feel like you're juggling knives blindfolded:
        // ******************************************************************

        AV* av = newAV();
        av_push(av, newSViv((int)my_lst.eno));
        av_push(av, newRV_inc((SV*)my_AV));  // if you mean to take ownership of it
        RETVAL = newRV_noinc((SV*)av);       // THIS is what Perl expects

        rel_mlst(my_lst);

    OUTPUT:
        RETVAL

SV*
line_csv(char pt_sep, AV* fields)
    CODE:
        if (pt_sep < 1 || pt_sep > 127) {
            croak("ABORT-0030: line_csv(sep = %d) is not in range ASCII 1 .. 127", pt_sep);
        }

        size_t sl_len = av_len(fields) + 1;
        sli_t* sl_arr = (sli_t*)malloc(sizeof(sli_t) * sl_len);

        if (sl_arr == NULL) {
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

        size_t rs_cap = TCAP;
        char*  rs_str = malloc(rs_cap + 1); // +1 for the null-terminator

        if (rs_str == NULL) {
            croak("ABORT-0040: line_csv() -- Can't malloc(%d)", rs_cap + 1);
        }

        strcpy(rs_str, "");

        for (size_t i = 0; i < sl_len; i++) {
            SV* scalar = sl_arr[i].dat;

            char my_buffer[RLEN];
            ginf_t my_info = get_info(aTHX_ scalar, (char*)&my_buffer);
            mtxt_t my_txt  = get_mtxt(my_info.mlen, my_info.mstr, pt_sep, (i + 1 == sl_len ? 1 : 0));

            if (!appd_text(aTHX_ &rs_str, &rs_cap, my_txt.dat)) {
                free(rs_str);
                free(sl_arr);
                rel_mtxt(my_txt);

                croak("ABORT-0060: line_csv() -- Can't malloc(%d)", rs_cap + 1);
            }

            rel_mtxt(my_txt);
        }

        RETVAL = newSVpv(rs_str, strlen(rs_str));

        if (sl_utf8) {
            SvUTF8_on(RETVAL);
        }

        free(rs_str);
        free(sl_arr);

    OUTPUT:
        RETVAL

HEAD_BEGIN:
    static char var_utf8(pTHX_ SV* gu_scalar) {
        if (!gu_scalar)         { return 0; }
        if (SvROK  (gu_scalar)) { return 0; } // It's a reference of some kind
        if (!SvPOK (gu_scalar)) { return 0; }
        if (!SvUTF8(gu_scalar)) { return 0; }

        return 1;
    }

    static ginf_t get_info(pTHX_ SV* gi_scalar, char* gi_buffer) {
        ginf_t gi_result = { '-', 0, 0, "", 0 };

        if (!gi_scalar) {
            return gi_result;
        }

        if (SvROK(gi_scalar)) { // It's a reference of some kind
            gi_result.uses_ref = 1;

            svtype gt_deref = SvTYPE(SvRV(gi_scalar)); // dereference

            if      (gt_deref == SVt_PVAV) { gi_result.type = 'A'; } // It's an array reference
            else if (gt_deref == SVt_PVHV) { gi_result.type = 'H'; } // It's a  hash  reference
            else if (gt_deref == SVt_PVCV) { gi_result.type = 'C'; } // It's a  code  reference
            else                           { gi_result.type = 'G'; } // other         reference (glob, regex, etc.)

            gi_result.mstr = make_text(gi_buffer, "#Ref(_)", gi_result.type);
            gi_result.mlen = strlen(gi_result.mstr);
        }
        else {
            if      (SvIOK(gi_scalar)) { gi_result.type = 'I'; } // Integer value
            else if (SvNOK(gi_scalar)) { gi_result.type = 'D'; } // Double value
            else if (SvPOK(gi_scalar)) { gi_result.type = 'S'; } // String value
            else if (!SvOK(gi_scalar)) { gi_result.type = 'U'; } // undef
            else                       { gi_result.type = 'Z'; } // unknown...

            if (gi_result.type == 'S' && SvUTF8(gi_scalar)) {
                gi_result.uses_utf8 = 1;
            }

            if (gi_result.type == 'U' || gi_result.type == 'Z') {
                gi_result.mstr = make_text(gi_buffer, "#Nul(_)", gi_result.type);
                gi_result.mlen = strlen(gi_result.mstr);
            }
            else {
                gi_result.mstr = gi_result.uses_utf8 ? SvPVutf8_nolen(gi_scalar) : SvPV_nolen(gi_scalar);
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

    static char appd_text(pTHX_ char** at_sbj_ptr, size_t* at_sbj_cap, char* at_add_str) {
        size_t my_sbj_len = strlen(*at_sbj_ptr);
        size_t my_add_len = strlen(at_add_str);

        if (*at_sbj_cap < my_sbj_len + my_add_len) {
            *at_sbj_cap = my_sbj_len + my_add_len + TCAP;

            char* tm_str = malloc(aTHX_ (*at_sbj_cap + 1)); if (tm_str == NULL) { return 0; }
            memcpy(tm_str, *at_sbj_ptr, my_sbj_len + 1);
            free(aTHX_ *at_sbj_ptr);

            *at_sbj_ptr = tm_str;
        }

        memcpy(*at_sbj_ptr + my_sbj_len, at_add_str, my_add_len + 1);
        return 1;
    }
HEAD_END:
