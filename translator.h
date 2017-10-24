#ifndef __TRANSLATOR_H
#define __TRANSLATOR_H

#include <iostream>
#include <vector>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <assert.h>
#include <map>

using namespace std;

#define SIZE_OF_INT     4
#define SIZE_OF_DOUBLE  8
#define SIZE_OF_CHAR    1
#define SIZE_OF_VOID    0
#define SIZE_OF_PTR     4
#define SIZE_OF_BOOL    1
#define SIZE_OF_FUNC    0

// enum for basic types
typedef enum {
    t_BOOL = 0,
    t_CHAR,
    t_INT,
    t_DOUBLE,
    t_ARR,
    t_FUNC,
    t_VOID,
    t_PTR
} basicType;

// structure for storing all possible types
struct type_t {
    basicType bType;
    // size of this type
    int size;
    // next in case of pointer and arrays
    type_t * next;
    void print();
    type_t();
    type_t(basicType b);
    type_t(const type_t & t);
    int getSize();
};

bool areEqual(type_t * t1, type_t * t2);

struct symTable;

// union for storing the initial value of symbol entries
union initialVal {
    int intVal;
    double doubleVal;
    char charVal;
};

// structure for en entry of symbol table
struct symEntry {
    // name of the variable or function
    string name;            
    // type
    type_t * type;
    // initial value if initialised
    initialVal init;
    // scope - local, temp, global
    string scope;
    // if this was initialised
    bool wasInitialised;
    // size
    int size;
    // offset w.r.t its symbol table
    int offset;
    // nested table (in case of functions)
    symTable * nestedTable;
    symEntry(string s = "local");

    void print();
};

// count of temporary variables generated
extern int tempCount;

// structure for Symbol Table
struct symTable {
    // offset value
    int offset;
    // name of the table
    string name;
    // list of entries of the table
    int sizeLocal;

    int sizeParam;
    
    vector <symEntry *> entries;
    symEntry * lookUp(string name);
    symEntry * genTemp(type_t * type);

    void update(symEntry * s, type_t * t, int sz);

    void update(symEntry * s, initialVal init);

    symTable();

    symTable(string s);

    void print();

    bool isPresent(string s);
};

extern symTable * globalSymTab;
extern symTable * currentSymTab;
extern map <string, int> uniqueLabels;
extern vector <string> strLabels;

// enum for supported opcode types
typedef enum {
    OP_PLUS = 1,
    OP_MINUS,
    OP_MULT,
    OP_DIV,
    OP_MOD,
    OP_UMINUS,
    OP_COPY,
    OP_LT,
    OP_LTE,
    OP_GT,
    OP_GTE,
    OP_EQ,
    OP_NEQ,
    OP_T,
    OP_F,
    OP_INT2DBL,
    OP_DBL2INT,
    OP_INT2CHAR,
    OP_CHAR2INT,
    OP_L_VAL_AT,
    OP_R_VAL_AT,
    OP_L_INDEX,
    OP_R_INDEX,
    OP_ADDR,
    OP_PARAM,
    OP_GOTO_O,
    OP_CALL,
    OP_RETURN_VAL,
    OP_RETURN,
    OP_SHL,
    OP_SHR,
    OP_BW_NOT,
    OP_BW_AND,
    OP_BW_XOR,
    OP_BW_OR,
    OP_FUNC_START,
    OP_FUNC_END
} opcodeType;

// Entry of a quad
struct quadEntry {
    opcodeType op;
    string result, arg1, arg2;
    int labelIdx;

    quadEntry(opcodeType o, string s1 = "", string s2 = "", string s3 = "");

    quadEntry(opcodeType o, string s1, char c);

    quadEntry(opcodeType o, string s1, int n);

    quadEntry(opcodeType o, string s1, double d);

    void setTarget(int addr);

    void print(FILE * out);

    void genTargetCode(FILE * fp);
};

// structure for list of quad to be generated
struct quadList {
    // index of next quad to be generated
    int nextInstr;
    // width of current type
    int width;
    // pointer of current type
    type_t * type;
    // List of quads
    vector <quadEntry> quad_v;
    void emit(quadEntry q);
    void print();
};

extern quadList quad;

// node for a list, stores the index of quad
struct node {
    // index of the quad
    int qIdx;
    // pointer of the next node
    node * next;

    node(int idx);

    node();

};

// List of nodes, used for truelist, false list, nextlist etc
struct List {
    // index of the quad
    int qIdx;
    // head of the list (first node)
    node * head;
    // tail of the list (last node)
    node * tail;

    List(int idx);

    List();

    void clear();

    void print();

};

List * mergeList(List * l1, List * l2);

string i2s(int n);

// attribute for expression type non terminals
struct exp_t {
    // true list
    List * trueList;
    // false list
    List * falseList;
    // pointer to entry in symbol table
    symEntry * loc;
    // pointer to entry of base array in symbol table
    symEntry * array;
    // pointer of type
    type_t * type;
    // flag to store if this is of array type
    bool isArrayType;
    // flag to store if this is of pointer type
    bool isPtrType;

    bool isString;

    int strLabel;
};

// attribute for declaration type non terminals
struct dec_t {
    type_t * type;
    int width;
};

// attribute for identifier
struct idf_t {
    // name
    string * strVal;
    // pointer to entry in symbol table
    symEntry * loc;
};

void conv2Bool(exp_t * e);

void convBool2Int(exp_t * e);

void backPatch(List * & p, int addr);

bool typeCheck(exp_t * e1, exp_t * e2, bool isAssignment = false);

bool checkParams(exp_t e, vector <exp_t * > * v);

#endif