#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <ctype.h>
#include <sys/socket.h>

typedef int8_t      i8;
typedef uint8_t     u8;
typedef uint16_t    u16;
typedef uint32_t    u32;

typedef uint32_t in_addr_t;
typedef struct {
    in_addr_t   ip;
    u16     port;
} ipport_t;

#define FREEX(X)    freex((void *)&X)
void freex(void **buff) {
    if(!buff || !*buff) return;
    free(*buff);
    *buff = NULL;
}

typedef struct {
    unsigned char   encxkey[261];   // static key
    int             offset;         // everything decrypted till now (total)
    int             start;          // where starts the buffer (so how much big is the header), this is the only one you need to zero
} enctypex_data_t;


unsigned char  enc1key[261];

unsigned char *enctype1_decoder(unsigned char *id, unsigned char *data, int *datalen) {
    unsigned int    tbuff[326];
    int             i,
                    len,
                    tmplen;
    unsigned char   tbuff2[258];
    unsigned char   *datap;
    static const unsigned char enctype1_data[256] = /* pre-built */
        "\x01\xba\xfa\xb2\x51\x00\x54\x80\x75\x16\x8e\x8e\x02\x08\x36\xa5"
        "\x2d\x05\x0d\x16\x52\x07\xb4\x22\x8c\xe9\x09\xd6\xb9\x26\x00\x04"
        "\x06\x05\x00\x13\x18\xc4\x1e\x5b\x1d\x76\x74\xfc\x50\x51\x06\x16"
        "\x00\x51\x28\x00\x04\x0a\x29\x78\x51\x00\x01\x11\x52\x16\x06\x4a"
        "\x20\x84\x01\xa2\x1e\x16\x47\x16\x32\x51\x9a\xc4\x03\x2a\x73\xe1"
        "\x2d\x4f\x18\x4b\x93\x4c\x0f\x39\x0a\x00\x04\xc0\x12\x0c\x9a\x5e"
        "\x02\xb3\x18\xb8\x07\x0c\xcd\x21\x05\xc0\xa9\x41\x43\x04\x3c\x52"
        "\x75\xec\x98\x80\x1d\x08\x02\x1d\x58\x84\x01\x4e\x3b\x6a\x53\x7a"
        "\x55\x56\x57\x1e\x7f\xec\xb8\xad\x00\x70\x1f\x82\xd8\xfc\x97\x8b"
        "\xf0\x83\xfe\x0e\x76\x03\xbe\x39\x29\x77\x30\xe0\x2b\xff\xb7\x9e"
        "\x01\x04\xf8\x01\x0e\xe8\x53\xff\x94\x0c\xb2\x45\x9e\x0a\xc7\x06"
        "\x18\x01\x64\xb0\x03\x98\x01\xeb\x02\xb0\x01\xb4\x12\x49\x07\x1f"
        "\x5f\x5e\x5d\xa0\x4f\x5b\xa0\x5a\x59\x58\xcf\x52\x54\xd0\xb8\x34"
        "\x02\xfc\x0e\x42\x29\xb8\xda\x00\xba\xb1\xf0\x12\xfd\x23\xae\xb6"
        "\x45\xa9\xbb\x06\xb8\x88\x14\x24\xa9\x00\x14\xcb\x24\x12\xae\xcc"
        "\x57\x56\xee\xfd\x08\x30\xd9\xfd\x8b\x3e\x0a\x84\x46\xfa\x77\xb8";

    len = (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | (data[3]);
    if((len < 0) || (len > *datalen)) {
        *datalen = 0;
        return(data);
    }

    data[4] = (data[4] ^ 62) - 20;
    data[5] = (data[5] ^ 205) - 5;
    func8(data + 19, 16, enctype1_data);

    len -= data[4] + data[5] + 40;
    datap = data + data[5] + 40;

    tmplen = (len >> 2) - 5;
    if(tmplen >= 0) {
        func1(NULL, 0);
        func4(id, strlen(id));
        func6(datap, tmplen);
        memset(enc1key, 0, sizeof(enc1key));
    }

        /* added by me */
    for(i = 256; i < 326; i++) tbuff[i] = 0;

    tmplen = (len >> 1) - 17;
    if(tmplen >= 0) {
        encshare4(data + 36, 4, tbuff);
        encshare1(tbuff, datap, tmplen);
    }

    memset(tbuff2, 0, sizeof(tbuff2));
    func3(data + 19, 16, tbuff2);
    func2(datap, len, tbuff2);

    *datalen = len;
    return(datap);
}


void func1(unsigned char *id, int idlen) {
    if(id && idlen) func4(id, idlen);
}


void func2(unsigned char *data, int size, unsigned char *crypt) {
    unsigned char   n1,
                    n2,
                    t;

    n1 = crypt[256];
    n2 = crypt[257];
    while(size--) {
        t = crypt[++n1];
        n2 += t;
        crypt[n1] = crypt[n2];
        crypt[n2] = t;
        t += crypt[n1];
        *data++ ^= crypt[t];
    }
    crypt[256] = n1;
    crypt[257] = n2;
}


void func3(unsigned char *data, int len, unsigned char *buff) {
    int             i;
    unsigned char   pos = 0,
                    tmp,
                    rev = 0xff;

    for(i = 0; i < 256; i++) {
        buff[i] = rev--;
    }

    buff[256] = 0;
    buff[257] = 0;
    for(i = 0; i < 256; i++) {
        tmp = buff[i];
        pos += data[i % len] + tmp;
        buff[i] = buff[pos];
        buff[pos] = tmp;
    }
}


void func4(unsigned char *id, int idlen) {
	int             i,
                    n1 = 0,
                    n2 = 0;
    unsigned char   t1,
                    t2;

    if(idlen < 1) return;

    for(i = 0; i < 256; i++) enc1key[i] = i;

    for(i = 255; i >= 0; i--) {
        t1 = func5(i, id, idlen, &n1, &n2);
        t2 = enc1key[i];
        enc1key[i] = enc1key[t1];
        enc1key[t1] = t2;
    }

    enc1key[256] = enc1key[1];
    enc1key[257] = enc1key[3];
    enc1key[258] = enc1key[5];
    enc1key[259] = enc1key[7];
    enc1key[260] = enc1key[n1 & 0xff];
}


int func5(int cnt, unsigned char *id, int idlen, int *n1, int *n2) {
    int     i,
            tmp,
            mask = 1;

    if(!cnt) return(0);
    if(cnt > 1) {
        do {
            mask = (mask << 1) + 1;
        } while(mask < cnt);
    }

    i = 0;
    do {
        *n1 = enc1key[*n1 & 0xff] + id[*n2];
        (*n2)++;
        if(*n2 >= idlen) {
            *n2 = 0;
            *n1 += idlen;
        }
        tmp = *n1 & mask;
        if(++i > 11) tmp %= cnt;
    } while(tmp > cnt);

    return(tmp);
}


void func6(unsigned char *data, int len) {
    while(len--) {
        *data = func7(*data);
        data++;
    }
}


int func7(int len) {
    unsigned char   a,
                    b,
                    c;

    a = enc1key[256];
    b = enc1key[257];
    c = enc1key[a];
    enc1key[256] = a + 1;
    enc1key[257] = b + c;
    a = enc1key[260];
    b = enc1key[257];
    b = enc1key[b];
    c = enc1key[a];
    enc1key[a] = b;
    a = enc1key[259];
    b = enc1key[257];
    a = enc1key[a];
    enc1key[b] = a;
    a = enc1key[256];
    b = enc1key[259];
    a = enc1key[a];
    enc1key[b] = a;
    a = enc1key[256];
    enc1key[a] = c;
    b = enc1key[258];
    a = enc1key[c];
    c = enc1key[259];
    b = b + a;
    enc1key[258] = b;
    a = b;
    c = enc1key[c];
    b = enc1key[257];
    b = enc1key[b];
    a = enc1key[a];
    c += b;
    b = enc1key[260];
    b = enc1key[b];
    c += b;
    b = enc1key[c];
    c = enc1key[256];
    c = enc1key[c];
    a += c;
    c = enc1key[b];
    b = enc1key[a];
    a = len;
    c ^= b;
    enc1key[260] = a;
    c ^= a;
    enc1key[259] = c;
    return(c);
}


void func8(unsigned char *data, int len, const unsigned char *enctype1_data) {
    while(len--) {
        *data = enctype1_data[*data];
        data++;
    }
}


int enctype1_wrapper(unsigned char *key, unsigned char *data, int size) {
    unsigned char   *p;

    p = enctype1_decoder(key, data, &size);
    memmove(data, p, size);
    return(size);
}


unsigned char *enctype2_decoder(unsigned char *key, unsigned char *data, int *size) {
    unsigned int    dest[326];
    int             i;
    unsigned char   *datap;

    *data ^= 0xec;
    datap = data + 1;

    for(i = 0; key[i]; i++) datap[i] ^= key[i];

        /* added by me */
    for(i = 256; i < 326; i++) dest[i] = 0;

    encshare4(datap, *data, dest);

    datap += *data;
    *size -= (*data + 1);
    if(*size < 6) {
        *size = 0;
        return(data);
    }

    encshare1(dest, datap, *size);

    *size -= 6;
    return(datap);
}


int enctype2_wrapper(unsigned char *key, unsigned char *data, int size) {
    unsigned char   *p;

    p = enctype2_decoder(key, data, &size);
    memmove(data, p, size);
    return(size);
}


void encshare2(unsigned int *tbuff, unsigned int *tbuffp, int len) {
    unsigned int    t1,
                    t2,
                    t3,
                    t4,
                    t5,
                    *limit,
                    *p;

    t2 = tbuff[304];
    t1 = tbuff[305];
    t3 = tbuff[306];
    t5 = tbuff[307];
    limit = tbuffp + len;
    while(tbuffp < limit) {
        p = tbuff + t2 + 272;
        while(t5 < 65536) {
            t1 += t5;
            p++;
            t3 += t1;
            t1 += t3;
            p[-17] = t1;
            p[-1] = t3;
            t4 = (t3 << 24) | (t3 >> 8);
            p[15] = t5;
            t5 <<= 1;
            t2++;
            t1 ^= tbuff[t1 & 0xff];
            t4 ^= tbuff[t4 & 0xff];
            t3 = (t4 << 24) | (t4 >> 8);
            t4 = (t1 >> 24) | (t1 << 8);
            t4 ^= tbuff[t4 & 0xff];
            t3 ^= tbuff[t3 & 0xff];
            t1 = (t4 >> 24) | (t4 << 8);
        }
        t3 ^= t1;
        *tbuffp++ = t3;
        t2--;
        t1 = tbuff[t2 + 256];
        t5 = tbuff[t2 + 272];
        t1 = ~t1;
        t3 = (t1 << 24) | (t1 >> 8);
        t3 ^= tbuff[t3 & 0xff];
        t5 ^= tbuff[t5 & 0xff];
        t1 = (t3 << 24) | (t3 >> 8);
        t4 = (t5 >> 24) | (t5 << 8);
        t1 ^= tbuff[t1 & 0xff];
        t4 ^= tbuff[t4 & 0xff];
        t3 = (t4 >> 24) | (t4 << 8);
        t5 = (tbuff[t2 + 288] << 1) + 1;
    }
    tbuff[304] = t2;
    tbuff[305] = t1;
    tbuff[306] = t3;
    tbuff[307] = t5;
}


void encshare1(unsigned int *tbuff, unsigned char *datap, int len) {
    unsigned char   *p,
                    *s;

    p = s = (unsigned char *)(tbuff + 309);
    encshare2(tbuff, (unsigned int *)p, 16);

    while(len--) {
        if((p - s) == 63) {
            p = s;
            encshare2(tbuff, (unsigned int *)p, 16);
        }
        *datap ^= *p;
        datap++;
        p++;
    }
}


void encshare3(unsigned int *data, int n1, int n2) {
    unsigned int    t1,
                    t2,
                    t3,
                    t4;
    int             i;

    t2 = n1;
    t1 = 0;
    t4 = 1;
    data[304] = 0;
    for(i = 32768; i; i >>= 1) {
        t2 += t4;
        t1 += t2;
        t2 += t1;
        if(n2 & i) {
            t2 = ~t2;
            t4 = (t4 << 1) + 1;
            t3 = (t2 << 24) | (t2 >> 8);
            t3 ^= data[t3 & 0xff];
            t1 ^= data[t1 & 0xff];
            t2 = (t3 << 24) | (t3 >> 8);
            t3 = (t1 >> 24) | (t1 << 8);
            t2 ^= data[t2 & 0xff];
            t3 ^= data[t3 & 0xff];
            t1 = (t3 >> 24) | (t3 << 8);
        } else {
            data[data[304] + 256] = t2;
            data[data[304] + 272] = t1;
            data[data[304] + 288] = t4;
            data[304]++;
            t3 = (t1 << 24) | (t1 >> 8);
            t2 ^= data[t2 & 0xff];
            t3 ^= data[t3 & 0xff];
            t1 = (t3 << 24) | (t3 >> 8);
            t3 = (t2 >> 24) | (t2 << 8);
            t3 ^= data[t3 & 0xff];
            t1 ^= data[t1 & 0xff];
            t2 = (t3 >> 24) | (t3 << 8);
            t4 <<= 1;
        }
    }
    data[305] = t2;
    data[306] = t1;
    data[307] = t4;
    data[308] = n1;
}


void encshare4(unsigned char *src, int size, unsigned int *dest) {
    unsigned int    tmp;
    int             i;
    unsigned char   pos,
                    x,
                    y;

    for(i = 0; i < 256; i++) dest[i] = 0;

    for(y = 0; y < 4; y++) {
        for(i = 0; i < 256; i++) {
            dest[i] = (dest[i] << 8) + i;
        }

        for(pos = y, x = 0; x < 2; x++) {
            for(i = 0; i < 256; i++) {
                tmp = dest[i];
                pos += tmp + src[i % size];
                dest[i] = dest[pos];
                dest[pos] = tmp;
            }
        }
    }

    for(i = 0; i < 256; i++) dest[i] ^= i;

    encshare3(dest, 0, 0);
}


int enctypex_func5(unsigned char *encxkey, int cnt, unsigned char *id, int idlen, int *n1, int *n2) {
    int     i,
            tmp,
            mask = 1;

    if(!cnt) return(0);
    if(cnt > 1) {
        do {
            mask = (mask << 1) + 1;
        } while(mask < cnt);
    }

    i = 0;
    do {
        *n1 = encxkey[*n1 & 0xff] + id[*n2];
        (*n2)++;
        if(*n2 >= idlen) {
            *n2 = 0;
            *n1 += idlen;
        }
        tmp = *n1 & mask;
        if(++i > 11) tmp %= cnt;
    } while(tmp > cnt);

    return(tmp);
}


void enctypex_func4(unsigned char *encxkey, unsigned char *id, int idlen) {
	int             i,
                    n1 = 0,
                    n2 = 0;
    unsigned char   t1,
                    t2;

    if(idlen < 1) return;

    for(i = 0; i < 256; i++) encxkey[i] = i;

    for(i = 255; i >= 0; i--) {
        t1 = enctypex_func5(encxkey, i, id, idlen, &n1, &n2);
        t2 = encxkey[i];
        encxkey[i] = encxkey[t1];
        encxkey[t1] = t2;
    }

    encxkey[256] = encxkey[1];
    encxkey[257] = encxkey[3];
    encxkey[258] = encxkey[5];
    encxkey[259] = encxkey[7];
    encxkey[260] = encxkey[n1 & 0xff];
}


int enctypex_func7(unsigned char *encxkey, unsigned char d) {
    unsigned char   a,
                    b,
                    c;

    a = encxkey[256];
    b = encxkey[257];
    c = encxkey[a];
    encxkey[256] = a + 1;
    encxkey[257] = b + c;
    a = encxkey[260];
    b = encxkey[257];
    b = encxkey[b];
    c = encxkey[a];
    encxkey[a] = b;
    a = encxkey[259];
    b = encxkey[257];
    a = encxkey[a];
    encxkey[b] = a;
    a = encxkey[256];
    b = encxkey[259];
    a = encxkey[a];
    encxkey[b] = a;
    a = encxkey[256];
    encxkey[a] = c;
    b = encxkey[258];
    a = encxkey[c];
    c = encxkey[259];
    b += a;
    encxkey[258] = b;
    a = b;
    c = encxkey[c];
    b = encxkey[257];
    b = encxkey[b];
    a = encxkey[a];
    c += b;
    b = encxkey[260];
    b = encxkey[b];
    c += b;
    b = encxkey[c];
    c = encxkey[256];
    c = encxkey[c];
    a += c;
    c = encxkey[b];
    b = encxkey[a];
    encxkey[260] = d;
    c ^= b ^ d;
    encxkey[259] = c;
    return(c);
}


int enctypex_func7e(unsigned char *encxkey, unsigned char d) {
    unsigned char   a,
                    b,
                    c;

    a = encxkey[256];
    b = encxkey[257];
    c = encxkey[a];
    encxkey[256] = a + 1;
    encxkey[257] = b + c;
    a = encxkey[260];
    b = encxkey[257];
    b = encxkey[b];
    c = encxkey[a];
    encxkey[a] = b;
    a = encxkey[259];
    b = encxkey[257];
    a = encxkey[a];
    encxkey[b] = a;
    a = encxkey[256];
    b = encxkey[259];
    a = encxkey[a];
    encxkey[b] = a;
    a = encxkey[256];
    encxkey[a] = c;
    b = encxkey[258];
    a = encxkey[c];
    c = encxkey[259];
    b += a;
    encxkey[258] = b;
    a = b;
    c = encxkey[c];
    b = encxkey[257];
    b = encxkey[b];
    a = encxkey[a];
    c += b;
    b = encxkey[260];
    b = encxkey[b];
    c += b;
    b = encxkey[c];
    c = encxkey[256];
    c = encxkey[c];
    a += c;
    c = encxkey[b];
    b = encxkey[a];
    c ^= b ^ d;
    encxkey[260] = c;   // encrypt
    encxkey[259] = d;   // encrypt
    return(c);
}


int enctypex_func6(unsigned char *encxkey, unsigned char *data, int len) {
    int     i;

    for(i = 0; i < len; i++) {
        data[i] = enctypex_func7(encxkey, data[i]);
    }
    return(len);
}


int enctypex_func6e(unsigned char *encxkey, unsigned char *data, int len) {
    int     i;

    for(i = 0; i < len; i++) {
        data[i] = enctypex_func7e(encxkey, data[i]);
    }
    return(len);
}


void enctypex_funcx(unsigned char *encxkey, unsigned char *key, unsigned char *encxvalidate, unsigned char *data, int datalen) {
    int     i,
            keylen;

    keylen = strlen(key);
    for(i = 0; i < datalen; i++) {
        encxvalidate[(key[i % keylen] * i) & 7] ^= encxvalidate[i & 7] ^ data[i];
    }
    enctypex_func4(encxkey, encxvalidate, 8);
}


static int enctypex_data_cleaner_level = 2; // 0 = do nothing
                                            // 1 = colors
                                            // 2 = colors + strange chars
                                            // 3 = colors + strange chars + sql


int enctypex_data_cleaner(unsigned char *dst, unsigned char *src, int max) {
    static const unsigned char strange_chars[] = {
                    ' ','E',' ',',','f',',','.','t',' ','^','%','S','<','E',' ','Z',
                    ' ',' ','`','`','"','"','.','-','-','~','`','S','>','e',' ','Z',
                    'Y','Y','i','c','e','o','Y','I','S','`','c','a','<','-','-','E',
                    '-','`','+','2','3','`','u','P','-',',','1','`','>','%','%','%',
                    '?','A','A','A','A','A','A','A','C','E','E','E','E','I','I','I',
                    'I','D','N','O','O','O','O','O','x','0','U','U','U','U','Y','D',
                    'B','a','a','a','a','a','a','e','c','e','e','e','e','i','i','i',
                    'i','o','n','o','o','o','o','o','+','o','u','u','u','u','y','b',
                    'y' };
    unsigned char   c,
                    *p;

    if(!dst) return(0);
    if(dst != src) dst[0] = 0;  // the only change in 0.1.3a
    if(!src) return(0);

    if(max < 0) max = strlen(src);

    for(p = dst; (c = *src) && (max > 0); src++, max--) {
        if(c == '\\') {                     // avoids the backslash delimiter
            *p++ = '/';
            continue;
        }

        if(enctypex_data_cleaner_level >= 1) {
            if(c == '^') {                  // Quake 3 colors
                if(isdigit(src[1]) || islower(src[1])) { // ^0-^9, ^a-^z... a good compromise
                    src++;
                    max--;
                } else {
                    *p++ = c;
                }
                continue;
            }
            if(c == 0x1b) {                 // Unreal colors
                src += 3;
                max -= 3;
                continue;
            }
            if(c < ' ') {                   // other colors
                continue;
            }
        }

        if(enctypex_data_cleaner_level >= 2) {
            if(c >= 0x7f) c = strange_chars[c - 0x7f];
        }

        if(enctypex_data_cleaner_level >= 3) {
            switch(c) {                     // html/SQL injection (paranoid mode)
                case '\'':
                case '\"':
                case '&':
                case '^':
                case '?':
                case '{':
                case '}':
                case '(':
                case ')':
                case '[':
                case ']':
                case '-':
                case ';':
                case '~':
                case '|':
                case '$':
                case '!':
                case '<':
                case '>':
                case '*':
                case '%':
                case ',': c = '.';  break;
                default: break;
            }
        }

        if((c == '\r') || (c == '\n')) {    // no new line
            continue;
        }
        *p++ = c;
    }
    *p = 0;
    return(p - dst);
}


int enctypex_decoder_convert_to_ipport(unsigned char *data, int datalen, unsigned char *out, unsigned char *infobuff, int infobuff_size, int infobuff_offset) {
#define enctypex_infobuff_check(X) \
    if(infobuff) { \
        if((int)(infobuff_size - infobuff_len) <= (int)(X)) { \
            infobuff_size = 0; \
        } else

    typedef struct {
        unsigned char   type;
        unsigned char   *name;
    } par_t;

    int             i,
                    len,
                    pars    = 0,    // pars and vals are used for making the function
                    vals    = 0,    // thread-safe when infobuff is not used
                    infobuff_len = 0;
    unsigned char   tmpip[6],
                    port[2],
                    t,
                    *p,
                    *o,
                    *l;
    static const int    use_parval = 1; // par and val are required, so this bool is useless
    static unsigned char    // this function is not thread-safe if you use it for retrieving the extra data (infobuff)
                    parz    = 0,
                    valz    = 0,
                    **val   = NULL;
    static par_t    *par    = NULL; // par[255] and *val[255] was good too

    if(!data) return(0);
    if(datalen < 6) return(0);  // covers the 6 bytes of IP:port
    o = out;
    p = data;
    l = data + datalen;

    p += 4;         // your IP
    port[0] = *p++; // the most used port
    port[1] = *p++;
    if((port[0] == 0xff) && (port[1] == 0xff)) {
        return(-1); // error message from the server
    }

    if(infobuff && infobuff_offset) {   // restore the data
        p = data + infobuff_offset;
    } else {
        if(p < l) {
            pars = *p++;
            if(use_parval) {  // save the static data
                parz = pars;
                par  = realloc(par, sizeof(par_t) * parz);
            }
            for(i = 0; (i < pars) && (p < l); i++) {
                t = *p++;
                if(use_parval) {
                    par[i].type = t;
                    par[i].name = p;
                }
                p += strlen(p) + 1;
            }
        }
        if(p < l) {
            vals = *p++;
            if(use_parval) {  // save the static data
                valz = vals;
                val  = realloc(val, sizeof(unsigned char *) * valz);
            }
            for(i = 0; (i < vals) && (p < l); i++) {
                if(use_parval) val[i] = p;
                p += strlen(p) + 1;
            }
        }
    }

    if(use_parval) {
        pars = parz;
        vals = valz;
    }
    if(infobuff && (infobuff_size > 0)) {
        infobuff[0] = 0;
    }

    while(p < l) {
        t = *p++;
        if(!t && !memcmp(p, "\xff\xff\xff\xff", 4)) {
            if(!out) o = out - 1;   // so the return is not 0 and means that we have reached the end
            break;
        }
        len = 5;
        if(t & 0x02) len = 9;
        if(t & 0x08) len += 4;
        if(t & 0x10) len += 2;
        if(t & 0x20) len += 2;

        tmpip[0] = p[0];
        tmpip[1] = p[1];
        tmpip[2] = p[2];
        tmpip[3] = p[3];
        if((len < 6) || !(t & 0x10)) {
            tmpip[4] = port[0];
            tmpip[5] = port[1];
        } else {
            tmpip[4] = p[4];
            tmpip[5] = p[5];
        }

        if(out) {
            memcpy(o, tmpip, 6);
            o += 6;
        }
        enctypex_infobuff_check(22) {
            infobuff_len = sprintf(infobuff,
                "%u.%u.%u.%u:%hu ",
                tmpip[0], tmpip[1], tmpip[2], tmpip[3],
                (unsigned short)((tmpip[4] << 8) | tmpip[5]));
        }}

        p += len - 1;   // the value in len is no longer used from this point
        if(t & 0x40) {
            for(i = 0; (i < pars) && (p < l); i++) {
                enctypex_infobuff_check(1 + strlen(par[i].name) + 1) {
                    infobuff[infobuff_len++] = '\\';
                    infobuff_len += enctypex_data_cleaner(infobuff + infobuff_len, par[i].name, -1);
                    infobuff[infobuff_len++] = '\\';
                    infobuff[infobuff_len]   = 0;
                }}
                t = *p++;

                if(use_parval) {
                    if(!par[i].type) {  // string
                        if(t == 0xff) { // inline string
                            enctypex_infobuff_check(strlen(p)) {
                                infobuff_len += enctypex_data_cleaner(infobuff + infobuff_len, p, -1);
                            }}
                            p += strlen(p) + 1;
                        } else {        // fixed string
                            if(t < vals) {
                                enctypex_infobuff_check(strlen(val[t])) {
                                    infobuff_len += enctypex_data_cleaner(infobuff + infobuff_len, val[t], -1);
                                }}
                            }
                        }
                    } else {            // number (-128 to 127)
                        enctypex_infobuff_check(5) {
                            infobuff_len += sprintf(infobuff + infobuff_len, "%d", (signed char)t);
                        }}
                    }
                }
            }
        }
        if(infobuff) {  // do NOT touch par/val, I use realloc
            return(p - data);
        }
    }

    if((out == data) && ((o - out) > (p - data))) { // I need to remember this
        fprintf(stderr, "\nError: input and output buffer are the same and there is not enough space\n");
        exit(1);
    }
    if(infobuff) {      // do NOT touch par/val, I use realloc
        parz = 0;
        valz = 0;
        return(-1);
    }
    return(o - out);
}


int enctypex_decoder_rand_validate(unsigned char *validate) {
    int     i,
            rnd;

    rnd = ~time(NULL);
    for(i = 0; i < 8; i++) {
        do {
            rnd = ((rnd * 0x343FD) + 0x269EC3) & 0x7f;
        } while((rnd < 0x21) || (rnd >= 0x7f));
        validate[i] = rnd;
    }
    validate[i] = 0;
    return(i);
}


unsigned char *enctypex_init(unsigned char *encxkey, unsigned char *key, unsigned char *validate, unsigned char *data, int *datalen, enctypex_data_t *enctypex_data) {
    int             a,
                    b;
    unsigned char   encxvalidate[8];

    if(*datalen < 1) return(NULL);
    a = (data[0] ^ 0xec) + 2;
    if(*datalen < a) return(NULL);
    b = data[a - 1] ^ 0xea;
    if(*datalen < (a + b)) return(NULL);
    memcpy(encxvalidate, validate, 8);
    enctypex_funcx(encxkey, key, encxvalidate, data + a, b);
    a += b;
    if(!enctypex_data) {
        data     += a;
        *datalen -= a;  // datalen is untouched in stream mode!!!
    } else {
        enctypex_data->offset = a;
        enctypex_data->start  = a;
    }
    return(data);
}


unsigned char *enctypex_decoder(unsigned char *key, unsigned char *validate, unsigned char *data, int *datalen, enctypex_data_t *enctypex_data) {
    unsigned char   encxkeyb[261],
                    *encxkey;

    encxkey = enctypex_data ? enctypex_data->encxkey : encxkeyb;

    if(!enctypex_data || (enctypex_data && !enctypex_data->start)) {
        data = enctypex_init(encxkey, key, validate, data, datalen, enctypex_data);
        if(!data) return(NULL);
    }
    if(!enctypex_data) {
        enctypex_func6(encxkey, data, *datalen);
        return(data);
    } else if(enctypex_data && enctypex_data->start) {
        enctypex_data->offset += enctypex_func6(encxkey, data + enctypex_data->offset, *datalen - enctypex_data->offset);
        return(data + enctypex_data->start);
    }
    return(NULL);
}


unsigned char *enctypex_encoder(unsigned char *key, unsigned char *validate, unsigned char *data, int *datalen, enctypex_data_t *enctypex_data) {
    unsigned char   encxkeyb[261],
                    *encxkey;

    encxkey = enctypex_data ? enctypex_data->encxkey : encxkeyb;

    if(!enctypex_data || (enctypex_data && !enctypex_data->start)) {
        data = enctypex_init(encxkey, key, validate, data, datalen, enctypex_data);
        if(!data) return(NULL);
    }
    if(!enctypex_data) {
        enctypex_func6e(encxkey, data, *datalen);
        return(data);
    } else if(enctypex_data && enctypex_data->start) {
        enctypex_data->offset += enctypex_func6e(encxkey, data + enctypex_data->offset, *datalen - enctypex_data->offset);
        return(data + enctypex_data->start);
    }
    return(NULL);
}


unsigned char *enctypex_msname(unsigned char *gamename, unsigned char *retname) {
    static unsigned char    msname[256];
    unsigned    i,
                c,
                server_num;

    if(!gamename) return(NULL);

    server_num = 0;
    for(i = 0; gamename[i]; i++) {
        c = tolower(gamename[i]);
        server_num = c - (server_num * 0x63306ce7);
    }
    server_num %= 20;

    if(retname) {
        snprintf(retname, 256, "%s.ms%d.gamespy.com", gamename, server_num);
        return(retname);
    }
    snprintf(msname, sizeof(msname), "%s.ms%d.gamespy.com", gamename, server_num);
    return(msname);
}


int enctypex_wrapper(unsigned char *key, unsigned char *validate, unsigned char *data, int size) {
    int             i;
    unsigned char   *p;

    if(!key || !validate || !data || (size < 0)) return(0);

    p = enctypex_decoder(key, validate, data, &size, NULL);
    if(!p) return(-1);
    for(i = 0; i < size; i++) {
        data[i] = p[i];
    }
    return(size);
}


int enctypex_quick_encrypt(unsigned char *key, unsigned char *validate, unsigned char *data, int size) {
    int             i,
                    rnd,
                    tmpsize,
                    keylen,
                    vallen;
    unsigned char   tmp[23];

    if(!key || !validate || !data || (size < 0)) return(0);

    keylen = strlen(key);   // only for giving a certain randomness, so useless
    vallen = strlen(validate);
    rnd = ~time(NULL);
    for(i = 0; i < sizeof(tmp); i++) {
        rnd = (rnd * 0x343FD) + 0x269EC3;
        tmp[i] = rnd ^ key[i % keylen] ^ validate[i % vallen];
    }
    tmp[0] = 0xeb;  // 7
    tmp[1] = 0x00;
    tmp[2] = 0x00;
    tmp[8] = 0xe4;  // 14

    for(i = size - 1; i >= 0; i--) {
        data[sizeof(tmp) + i] = data[i];
    }
    memcpy(data, tmp, sizeof(tmp));
    size += sizeof(tmp);

    tmpsize = size;
    enctypex_encoder(key, validate, data, &tmpsize, NULL);
    return(size);
}


int tcpxspr(int sd, u8 *gamestr, u8 *msgamestr, u8 *validate, u8 *filter, u8 *info, int type) {  // enctypex
    int     len;
    u8      *buff,
            *p;

    len = 2 + 7 + strlen(gamestr) + 1 + strlen(msgamestr) + 1 + strlen(validate) + strlen(filter) + 1 + strlen(info) + 1 + 4;
    buff = malloc(len);

    p = buff;
    p += 2;
    *p++ = 0;
    *p++ = 1;
    *p++ = 3;
    *p++ = 0;   // 32 bit
    *p++ = 0;
    *p++ = 0;
    *p++ = 0;
    p += sprintf(p, "%s", gamestr) + 1;     // the one you are requesting
    p += sprintf(p, "%s", msgamestr) + 1;   // used for the decryption algorithm
    p += sprintf(p, "%s%s", validate, filter) + 1;
    p += sprintf(p, "%s", info) + 1;
    *p++ = 0;
    *p++ = 0;
    *p++ = 0;
    *p++ = type;

    len = p - buff;
    buff[0] = len >> 8;
    buff[1] = len;

    len = send(sd, buff, len, 0);
    FREEX(buff);
    return(len);
}
