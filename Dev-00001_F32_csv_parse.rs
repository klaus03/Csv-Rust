const STR_CRLF: u8 = 10;
const STR_QUOT: u8 = 34;

const ECD_EOF:    u16 = 2012; // EOF - End of data in parsing input stream
const ECD_QUONA:  u16 = 2023; // EIQ - QUO character not allowed
const ECD_QNTERM: u16 = 2027; // EIQ - Quoted field not terminated
const ECD_LQUOTE: u16 = 2034; // EIF - Loose unescaped quote

#[derive(Clone, Copy)]
#[repr(C)]
pub struct MyTxt {
    len: i32,
    dat: *mut u8,
}

#[repr(C)]
pub struct MyLst {
    eno: u16,
    len: i32,
    dat: *mut MyTxt,
}

#[derive(Debug)]
enum Stat {
    Ready,
    Empty,
    GoNormal,
    GoQuote,
    SkipQuote,
    EndQuote,
    Stop,
    Croak(u8),
}

#[no_mangle]
pub extern "C" fn get_mtxt(len: i32, line: *const u8, sep: u8, fin: u8) -> MyTxt {
    if line.is_null() {
        return make_mtxt(vec![0u8]);
    }

    let slice = unsafe { get_u8_slice(true, len, line) };

    let mut ps_quote: bool = false;
    let mut ps_alloc: usize = 0;

    for ch_ref in slice {
        if *ch_ref == sep {
            ps_quote = true;
            ps_alloc += 1;
        }
        else if *ch_ref == STR_QUOT {
            ps_quote = true;
            ps_alloc += 2;
        }
        else if *ch_ref <= 32 {
            ps_quote = true;
            ps_alloc += 1;
        }
        else {
            ps_alloc += 1;
        }
    }

    if fin == 0 {
        ps_alloc += 1;
    }

    let mut word: Vec<u8> = Vec::with_capacity(ps_alloc + 4);

    if ps_quote {
        word.push(STR_QUOT);
    }

    for ch_ref in slice {
        if *ch_ref == STR_QUOT {
            word.push(STR_QUOT);
            word.push(STR_QUOT);
        }
        else {
            word.push(*ch_ref);
        }
    }

    if ps_quote {
        word.push(STR_QUOT);
    }

    if fin == 0 {
        word.push(sep);
    }

    word.push(0);

    make_mtxt(word)
}

#[no_mangle]
pub extern "C" fn get_mlst(len: i32, line: *const u8, sep: u8) -> MyLst {
    if line.is_null() {
        return make_mlst(7001, vec![make_mtxt(vec![0u8])]);
    }
    
    let slice = unsafe { get_u8_slice(true, len, line) };

    let mut ps_status = Stat::Ready;
    let mut ps_left: usize = 0;
    let mut ps_bounds: Vec<(usize, usize)> = Vec::new();

    'outer:
    for i in 0 .. slice.len() {
        let ch_cur = slice[i];
        let op_nxt = if i + 1 < slice.len() { Some(slice[i + 1]) } else { None };

        // println!("# Deb-0010: i = {}, Stat = {:?}, cur = {}, nxt = {:?}", i, ps_status, ch_cur, op_nxt);

        ps_status = match ps_status {
            Stat::Croak(_)  => break 'outer,
            Stat::SkipQuote => Stat::GoQuote,
            Stat::Stop      => Stat::Croak(1),
            Stat::EndQuote  => {
                match ch_cur {
                    STR_CRLF => Stat::Stop,
                    _        => Stat::Ready,
                }
            },
            Stat::Empty => {
                ps_bounds.push((i, i));
                Stat::Empty
            },
            Stat::Ready => {
                if ch_cur == sep {
                    ps_bounds.push((i, i));

                    match op_nxt {
                        Some(STR_CRLF) => Stat::Empty,
                        None           => Stat::Croak(5),
                        _              => Stat::Ready,
                    }
                }
                else {
                    match ch_cur {
                        STR_QUOT => { ps_left = i + 1;        Stat::GoQuote  },
                        STR_CRLF => { ps_bounds.push((i, i)); Stat::Stop     },
                        _        => { ps_left = i;            Stat::GoNormal },
                    }
                }
            },
            Stat::GoNormal => {
                if ch_cur == sep {
                    ps_bounds.push((ps_left, i));
                    Stat::Ready
                }
                else {
                    match ch_cur {
                        STR_QUOT => Stat::Croak(2),
                        STR_CRLF => { ps_bounds.push((ps_left, i)); Stat::Stop },
                        _        => Stat::GoNormal,
                    }
                }
            },
            Stat::GoQuote => {
                match ch_cur {
                    STR_QUOT => {
                        match op_nxt {
                            Some(ch_nxt) => {
                                if ch_nxt == STR_QUOT {
                                    Stat::SkipQuote
                                }
                                else if ch_nxt == sep || ch_nxt == STR_CRLF {
                                    ps_bounds.push((ps_left, i));
                                    Stat::EndQuote
                                }
                                else {
                                    Stat::Croak(3)
                                }
                            },
                            None => Stat::Stop,
                        }
                    },
                    _ => Stat::GoQuote,
                }
            },
        };
    }

    if let Stat::GoNormal = ps_status {
        ps_bounds.push((ps_left, slice.len()));
    }

    let stno: u16 = match ps_status {
        Stat::Stop       => 0,
        Stat::GoNormal   => 0,
        Stat::Empty      => 0,
        Stat::Ready      => ECD_EOF,
        Stat::GoQuote    => ECD_QNTERM,
        Stat::SkipQuote  => 8001,
        Stat::EndQuote   => 8002,
        Stat::Croak(2)   => ECD_LQUOTE,
        Stat::Croak(3)   => ECD_QUONA,
        Stat::Croak(cno) => 9000 + (cno as u16),
    };

    if stno != 0 {
        return make_mlst(stno, vec![make_mtxt(vec![0u8])]);
    }

    // http://hermanradtke.com/2015/06/22/effectively-using-iterators-in-rust.html
    // ***************************************************************************
    //
    // Use iter()      => If you just need to look at the data
    // Use iter_mut()  => If you need to edit/mutate the data
    // Use into_iter() => If you need to give it a new owner

    make_mlst(0, ps_bounds.iter()
      .map(|x| make_mtxt(make_word(slice, x)))
      .collect::<Vec<MyTxt>>())
}

fn make_mtxt(z_txt_input: Vec<u8>) -> MyTxt {
    let mut z_txt_slice = z_txt_input.into_boxed_slice();

    let z_txt_len = if z_txt_slice.len() > 0 { (z_txt_slice.len() as i32) - 1 } else { 0 };
    let z_txt_dat = z_txt_slice.as_mut_ptr();

    std::mem::forget(z_txt_slice);

    MyTxt { len: z_txt_len, dat: z_txt_dat }
}

fn make_mlst(errno: u16, z_lst_input: Vec<MyTxt>) -> MyLst {
    let mut z_lst_slice = z_lst_input.into_boxed_slice();

    let z_lst_len = z_lst_slice.len() as i32;
    let z_lst_dat = z_lst_slice.as_mut_ptr();

    std::mem::forget(z_lst_slice);

    MyLst { eno: errno, len: z_lst_len, dat: z_lst_dat }
}

#[no_mangle]
extern "C" fn rel_mtxt(z_txt_param: MyTxt) {
    let z_txt_raw = unsafe { std::slice::from_raw_parts_mut(z_txt_param.dat, z_txt_param.len as usize) };
    let z_txt_raw = z_txt_raw.as_mut_ptr();

    let _ = unsafe { Box::from_raw(z_txt_raw) };
}

#[no_mangle]
extern "C" fn rel_mlst(z_lst_param: MyLst) {
    let z_lst_raw = unsafe { std::slice::from_raw_parts_mut(z_lst_param.dat, z_lst_param.len as usize) };
    let z_lst_raw = z_lst_raw.as_mut_ptr();

    let sz = isize::try_from(z_lst_param.len).unwrap_or(-1);
    
    for i in 0 .. sz {
        let z_txt_param = unsafe { *z_lst_raw.offset(i) };

        let z_txt_raw = unsafe { std::slice::from_raw_parts_mut(z_txt_param.dat, z_txt_param.len as usize) };
        let z_txt_raw = z_txt_raw.as_mut_ptr();

        let _ = unsafe { Box::from_raw(z_txt_raw) };
    }

    let _ = unsafe { Box::from_raw(z_lst_raw) };
}

fn make_word(mw_slice: &[u8], mw_bounds: &(usize, usize)) -> Vec<u8> {
    let mw_left  = mw_bounds.0;
    let mw_right = mw_bounds.1;

    let mut mw_vec: Vec<u8> = Vec::with_capacity((mw_right - mw_left) + 2);
    let mut mw_active: bool = true;

    for i in mw_left .. mw_right {
        let ch_cur = mw_slice[i];

        mw_active = if mw_active {
            mw_vec.push(ch_cur);

            if ch_cur == STR_QUOT { false } else { true }
        }
        else {
            if ch_cur != STR_QUOT { mw_vec.push(ch_cur); }

            true
        }
    }

    mw_vec.push(0);

    mw_vec
}

unsafe fn get_u8_slice<'a>(fixed: bool, len: i32, cu: *const u8) -> &'a [u8] {
    // see also
    // https://users.rust-lang.org/t/how-to-address-raw-pointer-as-array/10164
    // https://doc.rust-lang.org/std/primitive.pointer.html#method.offset
    // https://users.rust-lang.org/t/how-to-use-a-struct-as-a-u8-buffer/106237

    if cu.is_null() {
        return &[];
    }

    let mlen: usize = if fixed {
        usize::try_from(len).unwrap_or(0)
    }
    else {
        let mut count = 0;

        let p = &cu;

        while unsafe { *p.offset(count) } != 0 {
            count += 1;
        }

        usize::try_from(count).unwrap_or(0)
    };

    unsafe { std::slice::from_raw_parts(cu, mlen) }
}
