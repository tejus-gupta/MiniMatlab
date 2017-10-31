%{ /* C Declarations and Definitions */
#include "ass6_12CS30006_translator.h"
extern int yylex();
void yyerror(const char *);
//comment something something changed
%}

%union {
    int intVal;
    double doubleVal;
    char charVal;
    int instr;
    string * strVal;
    exp_t exp;
    dec_t dec;
    idf_t id;
    symEntry * loc;
    List * nextList;
    vector <exp_t *> * args;
}

%token <name>       keyword
%token <id>         identifier
%token <name>       punctuator
%token <strVal>     string_literal
%token <intVal>     int_constant
%token <doubleVal>  float_constant
%token <charVal>    char_constant
%token AUTO ENUM RESTRICT UNSIGNED BREAK EXTERN RETURN VOID CASE FLOAT SHORT VOLATILE CHAR FOR 
%token SIGNED WHILE CONST GOTO SIZEOF _BOOL CONTINUE IF STATIC _COMPLEX DEFAULT INLINE 
%token STRUCT _IMAGINARY DO INT SWITCH DOUBLE LONG TYPEDEF ELSE REGISTER UNION 
%token ELLIPSIS RIGHT_ASSIGN LEFT_ASSIGN ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN 
%token DIV_ASSIGN MOD_ASSIGN AND_ASSIGN XOR_ASSIGN OR_ASSIGN RIGHT_OP LEFT_OP 
%token INC_OP DEC_OP PTR_OP AND_OP OR_OP LE_OP GE_OP EQ_OP NE_OP

%type <exp>   primary_expression postfix_expression unary_expression expression cast_expression
              additive_expression relational_expression equality_expression shift_expression
              logical_AND_expression inclusive_OR_expression exclusive_OR_expression logical_OR_expression
              conditional_expression multiplicative_expression AND_expression initializer assignment_expression
              constant_expression expression_statement expression_opt declarator direct_declarator
              assignment_expression_opt init_declarator init_declarator_list init_declarator_list_opt
%type <nextList> statement selection_statement iteration_statement jump_statement compound_statement
                  block_item block_item_list block_item_list_opt
%type <nextList> N
%type <instr> M
%type <charVal> unary_operator
%type <dec> declaration_specifiers declaration_specifiers_opt declaration_list declaration_list_opt
            specifier_qualifier_list specifier_qualifier_list_opt type_name  
            type_specifier pointer
%type <args> argument_expression_list argument_expression_list_opt
%type <name> enumeration_constant


%left '+' '-'
%left '*' '/'
%nonassoc UNARY

%start translation_unit
%%

translation_unit:
        external_declaration
        {

        }
      | translation_unit external_declaration
        {

        }
      ;

M    :
       /* epsilon */ 
       {
          // It stores the index of next quad to be generated
          // Used in control statements
          $$ = quad.nextInstr;
       }   
       ;

N    :
      /* epsilon */
      {
          // It inserts a goto statement and stores the list of the index of goto
          $$ = new List(quad.nextInstr);
          quad.emit(quadEntry(OP_GOTO_O, ""));
      }
      ;

primary_expression:
          identifier
          { 
              // Check if this is a global function
              if(!globalSymTab->isPresent(*($1.strVal))) 
                  $$.loc = currentSymTab->lookUp(*($1.strVal));
              else $$.loc = globalSymTab->lookUp(*($1.strVal));

              // Initialise array and type
              $$.array = $$.loc;
              $$.type = $$.loc->type;
              $$.trueList = NULL;
              $$.falseList = NULL;
              $$.strLabel = -1;
          }
        | int_constant
          {
              // Generate a temporary variable of int type
              $$.loc = currentSymTab->genTemp(new type_t(t_INT));
              $$.type = $$.loc->type;
              $$.trueList = NULL;
              $$.falseList = NULL;
              initialVal init; init.intVal = $1;
              // update the initial value of the temp variable generated
              currentSymTab->update($$.loc, init);
              // emit a quad assigning the value
              quad.emit(quadEntry(OP_COPY, $$.loc->name, $1));
              $$.strLabel = -1;
          }
        | float_constant
          {
              // Generate a temporary variable of float type
              $$.loc = currentSymTab->genTemp(new type_t(t_DOUBLE));
              $$.type = $$.loc->type;
              $$.trueList = NULL;
              $$.falseList = NULL;
              // update the initial value of the temp variable generated
              initialVal init; init.doubleVal = $1;
              currentSymTab->update($$.loc, init);
              // emit a quad assigning the value
              quad.emit(quadEntry(OP_COPY, $$.loc->name, $1));
              $$.strLabel = -1;
          }
        | char_constant
          {
              // Generate a temporary variable of char type
              $$.loc = currentSymTab->genTemp(new type_t(t_CHAR));
              $$.type = $$.loc->type;
              $$.trueList = NULL;
              $$.falseList = NULL;
              initialVal init; init.charVal = int($1);
              // update the initial value of the temp variable generated
              currentSymTab->update($$.loc, init);
              // emit a quad assigning the value
              quad.emit(quadEntry(OP_COPY, $$.loc->name, int($1)));
              $$.strLabel = -1;
          }
        | string_literal
          {
              // This is not supported
              $$.type = new type_t(t_PTR);
              $$.type->next = new type_t(t_CHAR);
              $$.isString = true;
              if(uniqueLabels.count(*($1))) {
                $$.strLabel = uniqueLabels[*($1)];
              } else {
                $$.strLabel = strLabels.size();
                uniqueLabels[*($1)] = strLabels.size();
                strLabels.push_back(*($1));
              }
          }
        | '(' expression ')'
          {
              // Copy the attribute
              $$ = $2;
          }
        ;

postfix_expression:
          primary_expression
          {
              // Copy the attribute
              $$ = $1;
              $$.isArrayType = false;
          }
        | postfix_expression '['expression']'
          {

              $$ = $1;
              if(!($$.isArrayType)) {
                  // If this was not array type, we need to create a temporary variable to store offset
                  $$.isArrayType = true;
                  $$.loc = currentSymTab->genTemp(new type_t(t_INT));
                  // Initialize the temporary variable with value 0
                  quad.emit(quadEntry(OP_MULT, $$.loc->name, $3.loc->name, i2s($1.type->next->getSize())));
              } else {
                  if($1.type->next == NULL) {
                      yyerror("error: subscripted value is neither array nor pointer nor vector");
                      exit(1);
                  }

                  // Update the offset value
                  symEntry * tmp = currentSymTab->genTemp(new type_t(t_INT));
                  quad.emit(quadEntry(OP_MULT, tmp->name, $3.loc->name, i2s($1.type->next->getSize())));
                  quad.emit(quadEntry(OP_PLUS, $$.loc->name, $$.loc->name, tmp->name));
              }

              

              // now the type of $$ is the type of its element
              $$.type = $1.type->next;

          }
        | postfix_expression '(' argument_expression_list_opt ')'
          {    
              // check if this is a valid function
              // check the types of the parameters
              $$ = $1;
              if($1.loc->nestedTable == NULL || !checkParams($1, $3)) {
                  char err[100];
                  sprintf(err, "Error in calling %s. Parameters type do not match.\n", $1.loc->name.c_str());
                  yyerror(err);
                  exit(1);
              } else {
                  // output all the parameters in the quad
                  for(int i = (int)$3->size() - 1; i >= 0; --i) {
                      if((*$3)[i]->isString) {
                        string label = ".LC" + i2s((*$3)[i]->strLabel);
                        quad.emit(quadEntry(OP_PARAM, label));
                      } else {
                        
                        quad.emit(quadEntry(OP_PARAM, (*$3)[i]->loc->name));
                      }
                  }
                  char buf[10];
                  sprintf(buf, "%d", (int)$3->size());
                  $$.loc = currentSymTab->genTemp($1.loc->nestedTable->entries[0]->type);
                  $$.type = $$.loc->type;
                  $$.trueList = NULL;
                  $$.falseList = NULL;
                  $$.isArrayType = false;
                  // call the function
                  quad.emit(quadEntry(OP_CALL, $$.loc->name, $1.loc->name, buf));
              }
          }
        | postfix_expression '.' identifier
          {
              // Not supported
          }
        | postfix_expression PTR_OP identifier
          {
              // Not supported
          }
        | postfix_expression INC_OP
          {
              // Generate a temporary variable
              $$ = $1;
              $$.loc = currentSymTab->genTemp($1.type);
              $$.type = $$.loc->type;

              if($1.isArrayType) {
                  // if it is array type we need to dereference the array first and then increment
                  quad.emit(quadEntry(OP_R_INDEX, $$.loc->name, $1.array->name, $1.loc->name));
                  symEntry * tmp = currentSymTab->genTemp($1.type);
                  quad.emit(quadEntry(OP_PLUS, tmp->name, $$.loc->name, "1"));
                  quad.emit(quadEntry(OP_L_INDEX, $1.array->name, $1.loc->name, tmp->name));
              } else {
                  quad.emit(quadEntry(OP_COPY, $$.loc->name, $1.loc->name));
                  quad.emit(quadEntry(OP_PLUS, $1.loc->name, $1.loc->name, "1"));
              }
              $$.isArrayType = false;
          }
        | postfix_expression DEC_OP
          {
              // Generate a temporary variable
              $$ = $1;
              $$.loc = currentSymTab->genTemp($1.type);
              $$.type = $$.loc->type;

              if($1.isArrayType) {
                  // if it is array type we need to dereference the array first and then increment
                  quad.emit(quadEntry(OP_R_INDEX, $$.loc->name, $1.array->name, $1.loc->name));
                  symEntry * tmp = currentSymTab->genTemp($1.type);
                  quad.emit(quadEntry(OP_MINUS, tmp->name, $$.loc->name, "1"));
                  quad.emit(quadEntry(OP_L_INDEX, $1.array->name, $1.loc->name, tmp->name));
              } else {
                  quad.emit(quadEntry(OP_COPY, $$.loc->name, $1.loc->name));
                  quad.emit(quadEntry(OP_MINUS, $1.loc->name, $1.loc->name, "1"));
              }
              $$.isArrayType = false;
          }
        | '(' type_name ')' '{' initializer_list '}'
          {

          }
        | '(' type_name ')' '{' initializer_list ',' '}'
          {

          }
        ;

argument_expression_list_opt:
        /* epsilon */
          {
              // initalise parameter list
              $$ = new vector <exp_t * >();
          }
        | argument_expression_list
          {
              $$ = $1;
          }
        ;

argument_expression_list:
          assignment_expression
          {   
              // initialise parameter list
              $$ = new vector <exp_t * >();
              $$->push_back(new exp_t($1));
          }
        | argument_expression_list ',' assignment_expression
          {
              // merge parameter list
              $$ = $1;
              $$->push_back(new exp_t($3));
          }
        ;

unary_expression:
          postfix_expression
          {
              $$ = $1;
          }
        | INC_OP unary_expression
          {
              // Generate temporary variable
              $$ = $2;
              $$.loc = currentSymTab->genTemp($2.type);
              $$.type = $$.loc->type;

              if($2.isArrayType) {
                  // we need to dereference the array
                  quad.emit(quadEntry(OP_R_INDEX, $$.loc->name, $2.array->name, $2.loc->name));
                  quad.emit(quadEntry(OP_PLUS, $$.loc->name, $$.loc->name, "1"));
                  quad.emit(quadEntry(OP_L_INDEX, $2.array->name, $2.loc->name, $$.loc->name));
              } else {
                  quad.emit(quadEntry(OP_PLUS, $2.loc->name, $2.loc->name, "1"));
                  quad.emit(quadEntry(OP_COPY, $$.loc->name, $2.loc->name));
              }
              $$.isArrayType = false;
          }
        | DEC_OP unary_expression
          {
              // Generate a temporary variable
              $$ = $2;
              $$.loc = currentSymTab->genTemp($2.type);
              $$.type = $$.loc->type;

              if($2.isArrayType) {
                  // we need to dereference the array
                  symEntry * tmp = currentSymTab->genTemp($2.type);
                  quad.emit(quadEntry(OP_R_INDEX, $$.loc->name, $2.array->name, $2.loc->name));
                  quad.emit(quadEntry(OP_MINUS, tmp->name, $$.loc->name, "1"));
                  quad.emit(quadEntry(OP_L_INDEX, $2.array->name, $2.loc->name, tmp->name));
                  $$.loc = tmp;
              } else {
                  quad.emit(quadEntry(OP_MINUS, $2.loc->name, $2.loc->name, "1"));
                  quad.emit(quadEntry(OP_COPY, $$.loc->name, $2.loc->name));
              }
              $$.isArrayType = false;
          }
        | unary_operator cast_expression %prec UNARY
          {
              // TODO
              
              $$.trueList = NULL;
              $$.falseList = NULL;

              switch($1) {
                  case '&':
                    {
                      // address of operator
                      type_t * ptr = new type_t(t_PTR);
                      ptr->next = $2.type;
                      $$.loc = currentSymTab->genTemp(ptr);
                      $$.type = $$.loc->type;
                      if(!$2.isArrayType) quad.emit(quadEntry(OP_ADDR, $$.loc->name, $2.loc->name));
                      else quad.emit(quadEntry(OP_PLUS, $$.loc->name, $2.array->name, $2.loc->name));
                    }
                    break;
                  case '*':
                    {
                      // value of operator
                      if($2.type->next == NULL) {
                        yyerror("Non pointer type.");
                        exit(1);
                      }
                      $$ = $2;
                      $$.type = $2.type->next;
                      $$.isPtrType = true;
                    }
                    break;
                  case '+':
                    if($2.isArrayType) {
                        $2.isArrayType = false;
                        symEntry * tmp = currentSymTab->genTemp($2.type);
                        quad.emit(quadEntry(OP_R_INDEX, tmp->name, $2.array->name, $2.loc->name));
                        $2.loc = tmp;
                    } else if($2.isPtrType) {
                        $2.isPtrType = false;
                        symEntry * tmp = currentSymTab->genTemp($2.type);
                        quad.emit(quadEntry(OP_R_VAL_AT, tmp->name, $2.array->name, $2.loc->name));
                        $2.loc = tmp;
                    }
                    $$ = $2;
                    break;
                  case '-':
                    // unary minus
                    if($2.isArrayType) {
                        $2.isArrayType = false;
                        symEntry * tmp = currentSymTab->genTemp($2.type);
                        quad.emit(quadEntry(OP_R_INDEX, tmp->name, $2.array->name, $2.loc->name));
                        $2.loc = tmp;
                    } else if($2.isPtrType) {
                        $2.isPtrType = false;
                        symEntry * tmp = currentSymTab->genTemp($2.type);
                        quad.emit(quadEntry(OP_R_VAL_AT, tmp->name, $2.array->name, $2.loc->name));
                        $2.loc = tmp;
                    }
                    $$.loc = currentSymTab->genTemp($2.type);
                    $$.type = $$.loc->type;
                    quad.emit(quadEntry(OP_UMINUS, $$.loc->name, $2.loc->name));
                    break;
                  case '~':
                    // bitwise not
                    if($2.isArrayType) {
                        $2.isArrayType = false;
                        symEntry * tmp = currentSymTab->genTemp($2.type);
                        quad.emit(quadEntry(OP_R_INDEX, tmp->name, $2.array->name, $2.loc->name));
                        $2.loc = tmp;
                    } else if($2.isPtrType) {
                        $2.isPtrType = false;
                        symEntry * tmp = currentSymTab->genTemp($2.type);
                        quad.emit(quadEntry(OP_R_VAL_AT, tmp->name, $2.array->name, $2.loc->name));
                        $2.loc = tmp;
                    }
                    if($2.type->bType == t_INT || $2.type->bType == t_CHAR || $2.type->bType == t_BOOL) {
                        exp_t e; e.type = new type_t(t_INT);
                        $$.loc = currentSymTab->genTemp(e.type);
                        $$.type = $$.loc->type;
                        typeCheck(&e, &($2), true);
                        quad.emit(quadEntry(OP_BW_NOT, $$.loc->name, $2.loc->name));
                    } else yyerror("Incompatible type for ~");
                    break;

              }
          }
        | SIZEOF unary_expression 
          {

          }
        | SIZEOF '(' type_name ')'
          {

          }
        ;

unary_operator:
          '&'
          {
              $$ = '&';
          }
        | '*'
          {
              $$ = '*';
          }       
        | '+'
          {
              $$ = '+';
          }
        | '-'
          {
              $$ = '-';
          }
        | '~'
          {
              $$ = '~';
          }
        | '!'
          {
              $$ = '!';
          }
        ;

cast_expression:
          unary_expression
          {
              $$ = $1;
          }
        | '(' type_name ')' cast_expression
          {

          }
        ;

multiplicative_expression:
          cast_expression
          {

              $$ = $1;
              if($1.isArrayType) {
                  $1.isArrayType = false;
                  $$.loc = currentSymTab->genTemp($1.type);
                  quad.emit(quadEntry(OP_R_INDEX, $$.loc->name, $1.array->name, $1.loc->name));
              } else if($1.isPtrType) {
                  $1.isPtrType = false;
                  $$.loc = currentSymTab->genTemp($1.type);
                  quad.emit(quadEntry(OP_R_VAL_AT, $$.loc->name, $1.array->name, $1.loc->name));
              }
          }
        | multiplicative_expression '*' cast_expression 
          {
              if($3.isArrayType) {
                  $3.isArrayType = false;
                  symEntry * tmp = currentSymTab->genTemp($3.type);
                  quad.emit(quadEntry(OP_R_INDEX, tmp->name, $3.array->name, $3.loc->name));
                  $3.loc = tmp;
              } else if($3.isPtrType) {
                  $3.isPtrType = false;
                  symEntry * tmp = currentSymTab->genTemp($3.type);
                  quad.emit(quadEntry(OP_R_VAL_AT, tmp->name, $3.array->name, $3.loc->name));
                  $3.loc = tmp;
              }
              $$ = $1;
              typeCheck(&($1), &($3));
              $$.loc = currentSymTab->genTemp($3.type);
              $$.type = $$.loc->type;
              quad.emit(quadEntry(OP_MULT, $$.loc->name, $1.loc->name, $3.loc->name));
          }
        | multiplicative_expression '/' cast_expression
          {
              if($3.isArrayType) {
                  $3.isArrayType = false;
                  symEntry * tmp = currentSymTab->genTemp($3.type);
                  quad.emit(quadEntry(OP_R_INDEX, tmp->name, $3.array->name, $3.loc->name));
                  $3.loc = tmp;
              } else if($3.isPtrType) {
                  $3.isPtrType = false;
                  symEntry * tmp = currentSymTab->genTemp($3.type);
                  quad.emit(quadEntry(OP_R_VAL_AT, tmp->name, $3.array->name, $3.loc->name));
                  $3.loc = tmp;
              }
              $$ = $1;
              typeCheck(&($1), &($3));
              $$.loc = currentSymTab->genTemp($3.type);
              $$.type = $$.loc->type;
              quad.emit(quadEntry(OP_DIV, $$.loc->name, $1.loc->name, $3.loc->name));
          }
        | multiplicative_expression '%' cast_expression
          {
              if($3.isArrayType) {
                  $3.isArrayType = false;
                  symEntry * tmp = currentSymTab->genTemp($3.type);
                  quad.emit(quadEntry(OP_R_INDEX, tmp->name, $3.array->name, $3.loc->name));
                  $3.loc = tmp;
              } else if($3.isPtrType) {
                  $3.isPtrType = false;
                  symEntry * tmp = currentSymTab->genTemp($3.type);
                  quad.emit(quadEntry(OP_R_VAL_AT, tmp->name, $3.array->name, $3.loc->name));
                  $3.loc = tmp;
              }
              $$ = $1;
              typeCheck(&($1), &($3));
              $$.loc = currentSymTab->genTemp($3.type);
              $$.type = $$.loc->type;
              quad.emit(quadEntry(OP_MOD, $$.loc->name, $1.loc->name, $3.loc->name));
          }
        ;

additive_expression:
          multiplicative_expression
          {
              $$ = $1;
          }
        | additive_expression '+' multiplicative_expression
          {
              $$ = $1;
              typeCheck(&($1), &($3));
              $$.loc = currentSymTab->genTemp($3.type);
              $$.type = $$.loc->type;
              quad.emit(quadEntry(OP_PLUS, $$.loc->name, $1.loc->name, $3.loc->name));
          }
        | additive_expression '-' multiplicative_expression
          {
              $$ = $1;
              typeCheck(&($1), &($3));
              $$.loc = currentSymTab->genTemp($3.type);
              $$.type = $$.loc->type;
              quad.emit(quadEntry(OP_MINUS, $$.loc->name, $1.loc->name, $3.loc->name));
          }
        ;

shift_expression:
          additive_expression
          {
              $$ = $1;
          }
        | shift_expression LEFT_OP additive_expression
          {
              exp_t e; e.type = new type_t(t_INT);
              if($1.type->bType == t_DOUBLE || !typeCheck(&e, &($1), true)) {
                  yyerror("Invalid type for operator <<\n");
                  exit(1);
              }
              if($3.type->bType == t_DOUBLE || !typeCheck(&e, &($3), true)) {
                  yyerror("Invalid type for operator <<\n");
                  exit(1);
              }
              $$ = $1;
              $$.loc = currentSymTab->genTemp(e.type);
              $$.type = $$.loc->type;
              quad.emit(quadEntry(OP_SHL, $$.loc->name, $1.loc->name, $3.loc->name));
          }
        | shift_expression RIGHT_OP additive_expression
          {
              exp_t e; e.type = new type_t(t_INT);
              if($1.type->bType == t_DOUBLE || !typeCheck(&e, &($1), true)) {
                  yyerror("Invalid type for operator >>\n");
                  exit(1);
              }
              if($3.type->bType == t_DOUBLE || !typeCheck(&e, &($3), true)) {
                  yyerror("Invalid type for operator >>\n");
                  exit(1);
              }
              $$ = $1;
              $$.loc = currentSymTab->genTemp(e.type);
              $$.type = $$.loc->type;
              quad.emit(quadEntry(OP_SHR, $$.loc->name, $1.loc->name, $3.loc->name));
          }
        ;

relational_expression:
          shift_expression
          {
              $$ = $1;
          }
        | relational_expression '<' shift_expression
          {
              typeCheck(&($1), &($3));
              $$.type = new type_t(t_BOOL);
              $$.trueList = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_LT, "", $1.loc->name, $3.loc->name));
              $$.falseList = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_GOTO_O, ""));
          }
        | relational_expression '>' shift_expression
          {
              typeCheck(&($1), &($3));
              $$.type = new type_t(t_BOOL);
              $$.trueList = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_GT, "", $1.loc->name, $3.loc->name));
              $$.falseList = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_GOTO_O, ""));   
          }
        | relational_expression LE_OP shift_expression
          {
              typeCheck(&($1), &($3));
              $$.type = new type_t(t_BOOL);
              $$.trueList = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_LTE, "", $1.loc->name, $3. loc->name));
              $$.falseList = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_GOTO_O, ""));
          }
        | relational_expression GE_OP shift_expression
          {
              typeCheck(&($1), &($3));
              $$.type = new type_t(t_BOOL);
              $$.trueList = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_GTE, "", $1.loc->name, $3.loc->name));
              $$.falseList = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_GOTO_O, ""));
          }
        ;

equality_expression:
          relational_expression
          {
              $$ = $1;
          }
        | equality_expression EQ_OP relational_expression
          {
              typeCheck(&($1), &($3));
              $$.type = new type_t(t_BOOL);
              $$.trueList = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_EQ, "", $1.loc->name, $3.loc->name));
              $$.falseList = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_GOTO_O, ""));
          }
        | equality_expression NE_OP relational_expression
          {
              typeCheck(&($1), &($3));
              $$.type = new type_t(t_BOOL);
              $$.trueList = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_NEQ, "", $1.loc->name, $3.loc->name));
              $$.falseList = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_GOTO_O, ""));
          }
        ;

AND_expression:
          equality_expression
          {
              $$ = $1;
          }
        | AND_expression '&' equality_expression
          {
              exp_t e; e.type = new type_t(t_INT);
              if($1.type->bType == t_DOUBLE || !typeCheck(&e, &($1), true)) {
                  yyerror("Invalid type for operator &\n");
                  exit(1);
              }
              if($3.type->bType == t_DOUBLE || !typeCheck(&e, &($3), true)) {
                  yyerror("Invalid type for operator &\n");
                  exit(1);
              }
              $$ = $1;
              $$.loc = currentSymTab->genTemp(e.type);
              $$.type = $$.loc->type;
              quad.emit(quadEntry(OP_BW_AND, $$.loc->name, $1.loc->name, $3.loc->name));
          }
        ;

exclusive_OR_expression:
          AND_expression
          {
              $$ = $1;
          }
        | exclusive_OR_expression '^' AND_expression
          {
              exp_t e; e.type = new type_t(t_INT);
              if($1.type->bType == t_DOUBLE || !typeCheck(&e, &($1), true)) {
                  yyerror("Invalid type for operator ^\n");
                  exit(1);
              }
              if($3.type->bType == t_DOUBLE || !typeCheck(&e, &($3), true)) {
                  yyerror("Invalid type for operator ^\n");
                  exit(1);
              }
              $$ = $1;
              $$.loc = currentSymTab->genTemp(e.type);
              $$.type = $$.loc->type;
              quad.emit(quadEntry(OP_BW_XOR, $$.loc->name, $1.loc->name, $3.loc->name));
          }
        ;

inclusive_OR_expression:
          exclusive_OR_expression
          {
              $$ = $1;
          }
        | inclusive_OR_expression '|' exclusive_OR_expression
          {
              exp_t e; e.type = new type_t(t_INT);
              if($1.type->bType == t_DOUBLE || !typeCheck(&e, &($1), true)) {
                  yyerror("Invalid type for operator |\n");
                  exit(1);
              }
              if($3.type->bType == t_DOUBLE || !typeCheck(&e, &($3), true)) {
                  yyerror("Invalid type for operator |\n");
                  exit(1);
              }
              $$ = $1;
              $$.loc = currentSymTab->genTemp(e.type);
              $$.type = $$.loc->type;
              quad.emit(quadEntry(OP_BW_OR, $$.loc->name, $1.loc->name, $3.loc->name));
          }
        ;

logical_AND_expression:
          inclusive_OR_expression
          {
              $$ = $1;
          }
        | logical_AND_expression AND_OP M inclusive_OR_expression
          {
              backPatch($1.trueList, $3);
              $$.type = new type_t(t_BOOL);
              $$.trueList = $4.trueList;
              $$.falseList = mergeList($1.falseList, $4.falseList);
          }
        ;

logical_OR_expression:
          logical_AND_expression
          {
              $$ = $1;
          }
        | logical_OR_expression OR_OP M logical_AND_expression
          {
              backPatch($1.falseList, $3);
              $$.type = new type_t(t_BOOL);
              $$.trueList = mergeList($1.trueList, $4.trueList);
              $$.falseList = $4.falseList;
          }
        ;

conditional_expression:
          logical_OR_expression
          {
              $$ = $1;
          }
        | logical_OR_expression N '?' M expression N ':' M conditional_expression
          {
              // N has been inserted to allow non bool expressions
              // M has been inserted to get the address of instruction for backpatching
              $$.loc = currentSymTab->genTemp($5.type);
              quad.emit(quadEntry(OP_COPY, $$.loc->name, $9.loc->name));
              List * l = new List(quad.nextInstr);
              quad.emit(quadEntry(OP_GOTO_O, ""));
              backPatch($6, quad.nextInstr);
              quad.emit(quadEntry(OP_COPY, $$.loc->name, $5.loc->name));
              l = mergeList(l, new List(quad.nextInstr));
              quad.emit(quadEntry(OP_GOTO_O, ""));
              backPatch($2, quad.nextInstr);
              conv2Bool(&($1));
              backPatch($1.trueList, $4);
              backPatch($1.falseList, $8);
              backPatch(l, quad.nextInstr);
          }
        ;

assignment_expression_opt:
          /* epsilon */
          {
              $$.trueList = NULL;
              $$.falseList = NULL;
              $$.loc = NULL;
          }
        | assignment_expression
          {
              $$ = $1;
          }
        ;

assignment_expression:
          conditional_expression
          {
              $$ = $1;
          }
        | unary_expression assignment_operator assignment_expression
          { 
              if($1.type->bType == t_ARR) {
                  yyerror("Assignment of arrays. Incompatible types");
                  exit(1);
              }
              if($1.type->bType == t_PTR) {
                  if($3.type->bType == t_DOUBLE) yyerror("Assignment of pointer to double not allowed.");
                  else quad.emit(quadEntry(OP_COPY, $1.loc->name, $3.loc->name));
              } else {
                  if(!typeCheck(&($1), &($3), true)) {
                      yyerror("Incompatible types in assignment.");
                      exit(1);
                  }
                  if($1.isArrayType) {
                      $1.isArrayType = false;
                      quad.emit(quadEntry(OP_L_INDEX, $1.array->name, $1.loc->name, $3.loc->name));
                  } else if($1.isPtrType) {
                      $1.isPtrType = false;
                      quad.emit(quadEntry(OP_L_VAL_AT, $1.loc->name, $3.loc->name));
                  } else {
                      quad.emit(quadEntry(OP_COPY, $1.loc->name, $3.loc->name));
                  }
              }
              $$ = $3;
          }
        ;

assignment_operator:
          '='
        | MUL_ASSIGN
          {

          }
        | DIV_ASSIGN
          {

          }
        | MOD_ASSIGN
          {

          }
        | ADD_ASSIGN
          {

          }
        | SUB_ASSIGN
          {

          }
        | LEFT_ASSIGN
          {

          }
        | RIGHT_ASSIGN
          {

          }
        | AND_ASSIGN
          {

          }
        | XOR_ASSIGN
          {

          }
        | OR_ASSIGN
          {

          }
        ;

expression:
          assignment_expression
          {
              $$ = $1;
          }
        | expression ',' assignment_expression
          {
              $$ = $3;
          }
        ;

constant_expression:
          conditional_expression
          {
              $$ = $1;
          }
          ;

declaration:
          declaration_specifiers init_declarator_list_opt ';'
          { 
              // create a symbol table for the function
              if($2.type->bType == t_FUNC) {
                  currentSymTab = new symTable();
              }
          }
          ;

declaration_specifiers_opt:
          /* epsilon */
          {

          }
        | declaration_specifiers
          {
              $$.type = $1.type;
              $$.width = $1.width;
          }
        ;

declaration_specifiers:
          storage_class_specifier declaration_specifiers_opt
          {

          }
        | type_specifier declaration_specifiers_opt
          {
              // save the properties of current type
              $$.type = $1.type;
              $$.width = $1.width;
              quad.type = $1.type;
              quad.width = $1.width;
          }
        | type_qualifier declaration_specifiers_opt
          {

          }
        | function_specifier declaration_specifiers_opt
          {

          }
        ;

init_declarator_list_opt:
        /* epsilon */
          {

          }
        | init_declarator_list
          {
              $$ = $1;
          }
        ;

init_declarator_list:
          init_declarator
          {
              $$ = $1;
          }
        | init_declarator_list ',' init_declarator
          {
              $$ = $3;
          }
        ;

init_declarator:
          declarator
          {
              $$ = $1;     
          }
        | declarator '=' initializer
          { 
                // check the type
                typeCheck(&($1), &($3), true);
                // if its initial value was set, update its initial value in symbol table
                if($3.loc->wasInitialised) currentSymTab->update($1.loc, $3.loc->init);
                quad.emit(quadEntry(OP_COPY, $1.loc->name, $3.loc->name));
                $$ = $1;
          }
        ;

storage_class_specifier:
          EXTERN
          {

          }
        | STATIC
          {

          }
        | AUTO
          {

          }
        | REGISTER
          {

          }
        ;

type_specifier:
          VOID
          {
              $$.type = new type_t(t_VOID);
              $$.width = SIZE_OF_VOID;
          }
        | CHAR
          {
              $$.type = new type_t(t_CHAR);
              $$.width = SIZE_OF_CHAR;
          }
        | SHORT
          {

          }
        | INT
          {
              $$.type = new type_t(t_INT);
              $$.width = SIZE_OF_INT;
          }
        | LONG
          {

          }
        | FLOAT
          {

          }
        | DOUBLE
          {
              $$.type = new type_t(t_DOUBLE);
              $$.width = SIZE_OF_DOUBLE;
          }
        | SIGNED
          {

          }
        | UNSIGNED
          {

          }
        | _BOOL
          {

          }
        | _COMPLEX
          {

          }
        | _IMAGINARY
          {

          }
        | enum_specifier
          {

          }
        ;

specifier_qualifier_list_opt:
          /* epsilon */
          {

          }
        | specifier_qualifier_list
          {
              $$.type = $1.type;
              $$.width = $1.width;
          }
        ;

specifier_qualifier_list:
          type_specifier specifier_qualifier_list_opt
          {
              $$.type = $1.type;
              $$.width = $1.width;
          }
        | type_qualifier specifier_qualifier_list_opt
          {

          }
        ;

enum_specifier:
          ENUM identifier_opt '{' enumerator_list '}'
          {

          }
        | ENUM identifier_opt '{' enumerator_list ',' '}'
          {

          }
        | ENUM identifier
          {

          }
        ;

enumerator_list:
          enumerator
          {

          }
        | enumerator_list ',' enumerator
          {

          }
        ;

enumerator:
          enumeration_constant
          {

          }
        | enumeration_constant '=' constant_expression
          {

          }
        ;

enumeration_constant:
        identifier
        {

        }
        ;

type_qualifier:
          CONST
          {

          }
        | RESTRICT
          {

          }
        | VOLATILE
          {

          }
        ;

function_specifier:
          INLINE
          {

          }
          ;

declarator:
          direct_declarator
          {
              $$ = $1;
          }
        | pointer direct_declarator
          {

              // update the type
              // update its type, size, offset in symbol table
              type_t * head = new type_t(t_VOID);
              type_t * toChange;
              if($2.loc->nestedTable == NULL) toChange = $2.type;
              else toChange = $2.loc->nestedTable->entries[0]->type;

              head->next = toChange;

              type_t * ptr = head;

              int oldSize = $2.loc->size;
              if($2.loc->nestedTable != NULL) oldSize = $2.loc->nestedTable->entries[0]->size;
              int newSize = SIZE_OF_PTR;
              
              while(ptr->next->next != NULL) {
                  newSize *= ptr->size;
                  ptr = ptr->next;
              }

              type_t * ptr2 = $1.type;
              while(ptr2->next != NULL) ptr2 = ptr2->next;
              ptr2->next = ptr->next;
              ptr->next = $1.type; 
             
              if($2.loc->nestedTable == NULL) {
                  currentSymTab->offset += newSize - oldSize; 
                  $2.loc->type = head->next;
                  $2.loc->size = newSize;
                  $2.type = $2.loc->type;
              } else {
                  // if its a function, we change the offset values of all the entries after this
                  for(int i = 1; i < (int)$2.loc->nestedTable->entries.size(); ++i) {
                      $2.loc->nestedTable->entries[i]->offset += newSize - oldSize;
                  }
                  $2.loc->nestedTable->entries[0]->type = head->next;
                  $2.loc->nestedTable->entries[0]->size = newSize;
                  $2.loc->nestedTable->offset += newSize - oldSize;
                  $2.type = head->next;
              }
              $$ = $2;
              
              delete head;
          }
        ;

direct_declarator:
          identifier
          {
              // find the identifier in the symbol table, if its not present, insert it
              $$.loc = currentSymTab->lookUp(*($1.strVal));
              currentSymTab->update($$.loc, quad.type, quad.width);
              $$.type = $$.loc->type;
          }
        | '(' declarator ')'
          {
              $$ = $2;
          }
        | direct_declarator '[' type_qualifier_list_opt assignment_expression_opt ']'
          { 
              type_t * p = new type_t(t_ARR);
              if($4.loc == NULL) {
                  if($1.type->bType == t_INT || $1.type->bType == t_VOID || $1.type->bType == t_CHAR || $1.type->bType == t_DOUBLE) {
                      p = new type_t(t_PTR);
                      p->next = $1.type;
                      $1.type = p;
                      $1.loc->type = p;
                      int oldSize = $1.loc->size;
                      $1.loc->size += SIZE_OF_PTR - oldSize;
                      currentSymTab->offset += SIZE_OF_PTR - oldSize;
                      $$ = $1;
                  } else {
                      yyerror("Incomplete type for array.\n");
                      exit(1);
                  }
              } else {
                if($4.loc->type->bType == t_INT) p->size = $4.loc->init.intVal;
                else {
                    yyerror("Non integer type array size.");
                    exit(1);
                }
                int oldSize = $1.loc->size;

                p->next = $1.type;
                type_t * head = new type_t();
                head->next = $1.type;
                type_t * ptr = head;
                while(ptr->next->next != NULL) ptr = ptr->next;

                p->next = ptr->next;
                ptr->next = p;

                int newSize;
                if($4.loc != NULL) newSize = head->next->getSize();
                else newSize = SIZE_OF_PTR;


                $1.type = head->next;
                $1.loc->type = head->next;
                $1.loc->size = newSize;
 

                for(int i = (int)currentSymTab->entries.size() - 1; i >= 0; --i) {
                    if(currentSymTab->entries[i] == $1.loc) break;
                    currentSymTab->entries[i]->offset += newSize - oldSize;
                }
                currentSymTab->offset += newSize - oldSize;

                $$ = $1;
              }
          }
        | direct_declarator '[' STATIC type_qualifier_list_opt assignment_expression ']'
          {

          }
        | direct_declarator '[' type_qualifier_list STATIC assignment_expression ']'
          {

          }
        | direct_declarator '[' type_qualifier_list_opt '*' ']'
          {

          }
        | direct_declarator '(' parameter_type_list_opt ')'
          {
              // this is a function declaration
              // save the return type
              // save the nestedTable
              // update its name
              symEntry * s = globalSymTab->lookUp($1.loc->name);
              globalSymTab->update(s, new type_t(t_FUNC), SIZE_OF_FUNC);
              s->nestedTable = currentSymTab;
              currentSymTab->name = "ST (" + $1.loc->name + ")";
              quad.emit(quadEntry(OP_FUNC_START, $1.loc->name));
              $1.loc->name = "__retVal";
              $1.loc->scope = "return";
              $$.loc = s;
              $$.type = $$.loc->type;
          }
        | direct_declarator '(' identifier_list ')'
          {

          }
        ;

parameter_type_list_opt:
          /* epsilon */
            {

            }
          | parameter_type_list
            {

            }
pointer:
          '*' type_qualifier_list_opt
          {
              $$.type = new type_t(t_PTR);
          }
        | '*' type_qualifier_list_opt pointer
          {
              // type of $$ is pointer of $3
              $$.type = new type_t(t_PTR);
              $$.type->next = $3.type;
          }
        ;

type_qualifier_list_opt:
          /* epsilon */
          {

          }
        | type_qualifier_list
          {

          }
        ;

type_qualifier_list:
          type_qualifier
          {

          }
        | type_qualifier_list type_qualifier
          {

          }
        ;

parameter_type_list:
        /* epsilon */
          parameter_list
          {

          }
        | parameter_list ',' ELLIPSIS
          {

          }
        ;

parameter_list:
          parameter_declaration
          {

          }
        | parameter_list ',' parameter_declaration
          {

          }
        ;


parameter_declaration:
          declaration_specifiers declarator
          {
              // save its scope as param
              $2.loc->scope = "param";
          }
        | declaration_specifiers
          {

          }
        ;

identifier_opt:
          /* epsilon */
          {

          }
        | identifier
          {

          }
        ;

identifier_list:
          identifier
          {

          }
        | identifier_list ',' identifier
          {

          }
        ;

type_name:
          specifier_qualifier_list
          {
              // save the width and type of current type for the variables to be declared
              $$.type = $1.type;
              $$.width = $1.width;
          }
          ;

initializer:
          assignment_expression
          {
              $$ = $1;
          }
        | '{' initializer_list '}'
          {

          }
        | '{' initializer_list ',' '}'
          {

          }
        ;

initializer_list:
        designation_opt initializer
        {

        }
      | initializer_list ',' designation_opt initializer
        {

        }
      ;

designation_opt:
        /* epsilon */
        {

        }
      | designation
        {

        }
      ;
        
designation:
        designator_list '='
        {

        }
        ;

designator_list:
        designator
        {

        }
      | designator_list designator
        {

        }
      ;

designator:
        '[' constant_expression ']'
        {

        }
      | '.' identifier
        {

        }
      ;


statement:
        labeled_statement
        {

        }
      | compound_statement
        {
            $$ = $1;
        }
      | expression_statement
        {
            $$ = NULL;
        }
      | selection_statement
        {
            $$ = $1;
        }
      | iteration_statement
        {
            $$ = $1;
        }
      | jump_statement
        {
            $$ = $1;
        }
      ;

labeled_statement:
        identifier ':' statement
        {
            // Not supported          
        }
      | CASE constant_expression ':' statement
        {
            // Not supported
        }
      | DEFAULT ':' statement
        {
            // Not supported
        }
      ;

compound_statement:
      '{' block_item_list_opt '}'
        {
            $$ = $2;
        }
      ;

block_item_list_opt:
      /* epsilon */
        {
            $$ = NULL;
        }
      | block_item_list
        {
            $$ = $1;
        }
      ;

block_item_list:
        block_item
        {
            $$ = $1;
        }
      | block_item_list M block_item
        {

            backPatch($1, $2);
            $$ = $3;
        }
      ;

block_item:
        declaration
        {
            $$ = NULL;
        }
      | statement
        {
            $$ = $1;
        }
      ;

expression_statement:
      expression_opt ';'
      ;

selection_statement:
        IF '(' expression N ')' M statement
        {   
            // N has been inserted to allow non-bool expressions as condition
            // if expression is not bool then we convert it into bool 
            List * l = mergeList($7, new List(quad.nextInstr));
            quad.emit(quadEntry(OP_GOTO_O, ""));
            backPatch($4, quad.nextInstr);
            conv2Bool(&($3));
            backPatch($3.trueList, $6);
            // all dangling gotos are merged and stored
            $$ = mergeList($3.falseList, l);
        }
      | IF '(' expression N ')' M statement N ELSE M statement
        { 
            // N has been inserted to allow non-bool expressions as condition
            // if expression is not bool then we convert it into bool 
            List * l = mergeList($7, $8);
            l = mergeList(l, new List(quad.nextInstr));
            quad.emit(quadEntry(OP_GOTO_O, ""));
            backPatch($4, quad.nextInstr);
            // convert to bool expression
            conv2Bool(&($3));
            backPatch($3.trueList, $6);
            backPatch($3.falseList, $10);
            // merge the dangling gotos
            $$ = mergeList(l, $11);
        }
      | SWITCH '(' expression ')' statement
        {

        }
      ;

iteration_statement:
        WHILE '(' M expression N ')' M statement
        { 
            // N has been inserted to allow non-bool expressions as condition
            // if expression is not bool then we convert it into bool 
            List * l = mergeList($8, new List(quad.nextInstr));
            // emit a goto after statement to goto condition again
            quad.emit(quadEntry(OP_GOTO_O, ""));
            backPatch($5, quad.nextInstr);
            conv2Bool(&($4));
            backPatch($4.trueList, $7);
            backPatch(l, $3);
            $$ = $4.falseList;
        }
      | DO M statement WHILE '(' M expression')' ';'
        {
            // if expression is not bool then we convert it into bool 
            conv2Bool(&($7));
            backPatch($7.trueList, $2);
            backPatch($3, $6);
            $$ = $7.falseList;
        }
      | FOR '(' expression_opt ';' M expression_opt N ';' M expression_opt N ')' M statement
        {
            // N has been inserted to allow non-bool expressions as condition
            // if expression is not bool then we convert it into bool 
           

            List * l = mergeList($14, new List(quad.nextInstr));
            // emit a goto after body of for loop to goto increment part
            quad.emit(quadEntry(OP_GOTO_O, ""));
            backPatch(l, $9);
            backPatch($7, quad.nextInstr);
            conv2Bool(&($6));
            backPatch($6.trueList, $13);
            backPatch($11, $5);
            $$ = $6.falseList;
        }
      | FOR '(' declaration expression_opt ';' expression_opt ')' statement
        {
            // Not supported
        }
        ;

jump_statement:
        GOTO identifier ';'
        {
            // Not supported
        }
      | CONTINUE ';'
        {

        }
      | BREAK ';'
        {

        }
      | RETURN ';'
        {
            quad.emit(quadEntry(OP_RETURN, ""));
            $$ = NULL;
        }
      | RETURN expression ';'
        {
            // convert the expression to the return type of the function
            exp_t e; e.type = currentSymTab->entries[0]->type;
            typeCheck(&e, &($2), true);
            // save the expression in return value of the function
            quad.emit(quadEntry(OP_RETURN_VAL, $2.loc->name));
            $$ = NULL;
        }
      ;

expression_opt:
        /* epsilon */
        { 
            // initialise trueList and falseList
            $$.type = new type_t(t_BOOL);
            $$.trueList = NULL;
            $$.falseList = NULL;
        }
      | expression
        {
            $$ = $1;
        }
      ;

external_declaration:
        function_definition
        {

        }
      | declaration
        {
            quad.quad_v.pop_back();
            quad.nextInstr--;
        }
      ;

function_definition:
        declaration_specifiers declarator declaration_list_opt compound_statement
        {   
            // save the nestedTable of the function in the global symbol table
            $2.loc->nestedTable = currentSymTab;
            currentSymTab = new symTable();
            // backPatch all dangling gotos to the next instruction
            backPatch($4, quad.nextInstr);
            quad.emit(quadEntry(OP_FUNC_END, $2.loc->name));
        }
      ;

declaration_list_opt:
        /* epsilon */
        {

        }
      | declaration_list
        {

        }
      ;

declaration_list:
        declaration
        {

        }
      | declaration_list declaration
        {

        }
      ;


%%

void yyerror(const char * s) {
    fprintf(stderr, "%s\n",s);
}
