%{
#include "ass6_12CS30006_translator.h"
#include "y.tab.h"
%}

DIG [0-9]
NON_ZERO_DIG [1-9]
DIG_SEQ {DIG}+
SIGN [-+]
IDENTIFIER_NONDIG [_a-zA-Z]
ID {IDENTIFIER_NONDIG}({IDENTIFIER_NONDIG}|{DIG})*
INT_CONST {NON_ZERO_DIG}({NON_ZERO_DIG}|{DIG})*|[0]+

EXP_PART ([eE]({SIGN}?){DIG_SEQ})
FRAC_CONST (({DIG_SEQ}?)[\\.]{DIG_SEQ})|({DIG_SEQ}[\\.])
FLOAT_CONST ({FRAC_CONST}{EXP_PART}?)|({DIG_SEQ}{EXP_PART})

ENUMERATION_CONST {IDENTIFIER_NONDIG}({IDENTIFIER_NONDIG}|{DIG})*

ESC_SEQ [\\][\'\"?\\abfnrtv0]

C_CHAR [^\'\\\n]|{ESC_SEQ}
C_CHAR_SEQ {C_CHAR}+
CHAR_CONST [\']{C_CHAR_SEQ}[\']

CONST {INT_CONST}|{FLOAT_CONST}|{ENUMERATION_CONST}|{CHAR_CONST}

S_CHAR [^\"\\\n]|{ESC_SEQ}
S_CHAR_SEQ {S_CHAR}+
STR_LITER [\"]{S_CHAR_SEQ}[\"]

S_COMMENT [/][/][^\n]*

%x MULTI_COMMENT

%%

"auto"          { return AUTO; }   
"enum"          { return ENUM; }
"restrict"      { return RESTRICT; }
"unsigned"      { return UNSIGNED; }
"break"         { return BREAK; }
"extern"        { return EXTERN; }
"return"        { return RETURN; }
"void"          { return VOID; }
"case"          { return CASE; }
"float"         { return FLOAT; }
"short"         { return SHORT; }
"volatile"      { return VOLATILE; }
"char"          { return CHAR; }
"for"           { return FOR; }
"signed"        { return SIGNED; }
"while"         { return WHILE; }
"const"         { return CONST; }
"goto"          { return GOTO; }
"sizeof"        { return SIZEOF; }
"_Bool"         { return _BOOL; }
"continue"      { return CONTINUE; }
"if"            { return IF; }
"static"        { return STATIC; }
"_Complex"      { return _COMPLEX; }  
"default"       { return DEFAULT; } 
"inline"        { return INLINE; } 
"struct"        { return STRUCT; }
"_Imaginary"    { return _IMAGINARY; }    
"do"            { return DO; }
"int"           { return INT; }
"switch"        { return SWITCH; }
"double"        { return DOUBLE; } 
"long"          { return LONG; }
"typedef"       { return TYPEDEF; } 
"else"          { return ELSE; }
"register"      { return REGISTER; }   
"union"         { return UNION; }


"..."           { return ELLIPSIS; }
">>="           { return RIGHT_ASSIGN; }
"<<="           { return LEFT_ASSIGN; }
"+="            { return ADD_ASSIGN; }
"-="            { return SUB_ASSIGN; }
"*="            { return MUL_ASSIGN; }
"/="            { return DIV_ASSIGN; }
"%="            { return MOD_ASSIGN; }
"&="            { return AND_ASSIGN; }
"^="            { return XOR_ASSIGN; }
"|="            { return OR_ASSIGN; }
">>"            { return RIGHT_OP; }
"<<"            { return LEFT_OP; }
"++"            { return INC_OP; }
"--"            { return DEC_OP; }
"->"            { return PTR_OP; }
"&&"            { return AND_OP; }
"||"            { return OR_OP; }
"<="            { return LE_OP; }
">="            { return GE_OP; }
"=="            { return EQ_OP; }
"!="            { return NE_OP; }
";"             { return yytext[0]; }
"{"             { return yytext[0]; }
"}"             { return yytext[0]; }
","             { return yytext[0]; }
":"             { return yytext[0]; }
"="             { return yytext[0]; }
"("             { return yytext[0]; }
")"             { return yytext[0]; }
"["             { return yytext[0]; }
"]"             { return yytext[0]; }
"."             { return yytext[0]; }
"&"             { return yytext[0]; }
"!"             { return yytext[0]; }
"~"             { return yytext[0]; }
"-"             { return yytext[0]; }
"+"             { return yytext[0]; }
"*"             { return yytext[0]; }
"/"             { return yytext[0]; }
"%"             { return yytext[0]; }
"<"             { return yytext[0]; }
">"             { return yytext[0]; }
"^"             { return yytext[0]; }
"|"             { return yytext[0]; }
"?"             { return yytext[0]; }
"#"             { return yytext[0]; }

"/*"            {  /* printf("<MULTI LINE COMMENT START>"); */ BEGIN(MULTI_COMMENT);}
"*/"            {  /* fprintf(stderr, "ERROR : Found end of comment without starting."); */ }

<MULTI_COMMENT>"*/"       { BEGIN(INITIAL); }
<MULTI_COMMENT>(.|[\n])   { }

[ \t]  
[\n]            { }
{S_COMMENT}     { }
{ID}            { yylval.id.strVal = new string(yytext); return identifier;}
{STR_LITER}     { yylval.strVal = new string(yytext); return string_literal;}
{INT_CONST}     { yylval.intVal = atoi(yytext); return int_constant;}
{FLOAT_CONST}   { yylval.doubleVal = atof(yytext); return float_constant;}
{CHAR_CONST}    { if(yytext[2] == '0') 
                        yylval.charVal = '\0';
                  else if(yytext[2] == 'n')
                        yylval.charVal = '\n';
                  else yylval.charVal = yytext[1]; 
                  return char_constant;
                }
%%
