#include "myl.h"

#define BUF 128
#define PRECISION 6
#define EPS (1e-9)
#define EOF -1

// prints a string of characters ending with '\0' and returns the number of characters printed
int prints(char * str) {

    // count the length of the string
    int len = 0;
    while(str[len] != '\0') ++len;

    __asm__ __volatile__ (
        "movl $4, %%eax \n\t"
        "movl $1, %%ebx \n\t"
        "int $128 \n\t"
        :
        :"c"(str), "d"(len)
    ); // 4 : write, 1 : stdout
    return len;
}

// prints an integer and returns the number of characters printed
int printi(int m) {
    // local buffer and temporary variable for swapping
    char buf[BUF], tmp;
    int pos = 0, i, neg;
    long long n = m;
    // check if the number is negative
    neg = n < 0 ? 1 : 0;
    if(n < 0) n = -n;
    if(n == 0) buf[pos++] = '0';
    while(n > 0) {
        buf[pos++] = '0' + (n % 10);
        n /= 10;
    }

    if(neg > 0) buf[pos++] = '-';
    // now we need to reverse the buffer array
    for(i = 0; i < pos / 2; ++i) {
        tmp = buf[i];
        buf[i] = buf[pos - 1 - i];
        buf[pos - 1 - i] = tmp;
    }

    __asm__ __volatile__ (
        "movl $4, %%eax \n\t"
        "movl $1, %%ebx \n\t"
        "int $128 \n\t"
        :
        :"c"(buf), "d"(pos)
    );

    return pos;
}

// prints a floating point number and returns the number of characters printed
int printd(float fl) {
    char buf[BUF];
    int pos = 0, dig, i;
    float inf = 1.0 / 0.0;

    if(fl != fl) {
        return prints("nan");
    }
    if(fl == inf) {
        return prints("inf");
    }
    
    double pw10 = 1.0, f = fl;
    if(f < 0) {
        buf[pos++] = '-';
        f = -f;
    }

    // find the place value of leftmost digit
    while(1) {
        if(pw10 * 10 > f) break;
        pw10 *= 10;
        if(pw10 > 1e39) break;
    }

    // print digits before decimal one by one, and removing them
    while(pw10 >= 1 - EPS) {
        dig = (int)((f / pw10) + EPS);
        buf[pos++] = '0' + dig;
        f -= dig * pw10;
        pw10 /= 10;
    }
    buf[pos++] = '.';
    for(i = 0; i < PRECISION; ++i) {
        dig = (int)((f / pw10) + EPS);
        buf[pos++] = '0' + dig;
        f -= dig * pw10;
        pw10 /= 10;
    }

    __asm__ __volatile__ (
        "movl $4, %%eax \n\t"
        "movl $1, %%ebx \n\t"
        "int $128 \n\t"
        :
        :"c"(buf), "d"(pos)
    );
    return pos;
}

// read a character from stdin
void readChar(char *chPtr) {
    __asm__ __volatile__ (
        "movl $3, %%eax \n\t"
        "movl $0, %%ebx \n\t"
        "int $128 \n\t"
        :
        :"c"(chPtr), "d"(1)
    );
}

// reads an integer (signed) and returns it, parameter is for error
int readi(int *eP) {
    char ch, *chPtr;
    chPtr = &ch;
    int n = 0, neg = 0;

    // ignore all white spaces
    while(1) {
        readChar(chPtr);
        if(ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') continue;
        else {
            if(ch == '-') {
                neg = 1;
                readChar(chPtr);
            }
            break;
        }
    }

    // read digit characters
    while(1) {
        if(ch < '0' || ch > '9') {
            // Its an error, so consume everything till white space
            while(1) {
                if(ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' || ch == EOF) {
                    break;
                }
                readChar(chPtr);
            }
            *eP = ERR;
            return neg > 0 ? -n : n;
        }
        n = n * 10 + (ch - '0');
        readChar(chPtr);
       if(ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' || ch == EOF) break;
    }
    *eP = OK;
    return neg > 0 ? -n : n;
}

// reads a floating point number in the parameter, and returns error
int readf(float *fP) {
    char ch, *chPtr;
    chPtr = &ch;
    int neg = 0;
    double mul = 1, f =0.0;

    // ignore all whitespaces
    while(1) {
        readChar(chPtr);
        if(ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') continue;
        else {
            if(ch == '-') {
                neg = 1;
                readChar(chPtr);
            }
            break;
        }
    }

    if(ch != '.') {
        // read digits before decimal
        while(1) {
            if(ch < '0' || ch > '9') {
                // Its an error, so consume everything till white space
                while(1) {
                    if(ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' || ch == EOF) {
                        break;
                    }
                    readChar(chPtr);
                }
                return ERR;
            }
            f = f * 10.0 + (ch - '0');
            *fP = f;
            readChar(chPtr);
            if(ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' || ch == EOF) {
                if(neg > 0) *fP = -1 * (*fP);
                return OK;
            } else if(ch == '.') {
                if(ch == '.') {
                    readChar(chPtr);
                }
                break;
            }
        }
    } else {
        readChar(chPtr);
    }

    // read digits after decimal
    while(1) {
        // if its a whitespace, its success
        if(ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' || ch == EOF) {
            if(neg > 0) *fP = -1 * (*fP);
            return OK;
        }

        // non-digit non-whitespace character, error
        if(ch < '0' || ch > '9') {
            // Its an error, so consume everything till white space
            while(1) {
                if(ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' || ch == EOF) {
                    break;
                }
                readChar(chPtr);
            }
            return ERR;
        }
        mul /= 10;
        f = f + mul * (EPS + (ch - '0'));
        *fP = f;
        readChar(chPtr);        
    }

    if(neg > 0) *fP = -1 * (*fP);
    return OK;
}