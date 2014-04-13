%{     /* pars1.y    Pascal Parser      Gordon S. Novak Jr.  ; 30 Jul 13   */

/* Copyright (c) 2013 Gordon S. Novak Jr. and
   The University of Texas at Austin. */

/* 14 Feb 01; 01 Oct 04; 02 Mar 07; 27 Feb 08; 24 Jul 09; 02 Aug 12 */

/*
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program; if not, see <http://www.gnu.org/licenses/>.
  */


/* NOTE:   Copy your lexan.l lexical analyzer to this directory.      */

       /* To use:
                     make pars1y              has 1 shift/reduce conflict
                     pars1y                   execute the parser
                     i:=j .
                     ^D                       control-D to end input

                     pars1y                   execute the parser
                     begin i:=j; if i+j then x:=a+b*c else x:=a*b+c; k:=i end.
                     ^D

                     pars1y                   execute the parser
                     if x+y then if y+z then i:=j else k:=2.
                     ^D

           You may copy pars1.y to be parse.y and extend it for your
           assignment.  Then use   make parser   as above.
        */

        /* Yacc reports 1 shift/reduce conflict, due to the ELSE part of
           the IF statement, but Yacc's default resolves it in the right way.*/

#include <stdio.h>
#include <ctype.h>
#include "token.h"
#include "lexan.h"
#include "symtab.h"
#include "parse.h"

        /* define the type of the Yacc stack element to be TOKEN */

#define YYSTYPE TOKEN

TOKEN parseresult;

%}

/* Order of tokens corresponds to tokendefs.c; do not change */

%token IDENTIFIER STRING NUMBER   /* token types */

%token PLUS MINUS TIMES DIVIDE    /* Operators */
%token ASSIGN EQ NE LT LE GE GT POINT DOT AND OR NOT DIV MOD IN

%token COMMA                      /* Delimiters */
%token SEMICOLON COLON LPAREN RPAREN LBRACKET RBRACKET DOTDOT

%token ARRAY BEGINBEGIN           /* Lex uses BEGIN */
%token CASE CONST DO DOWNTO ELSE END FILEFILE FOR FUNCTION GOTO IF LABEL NIL
%token OF PACKED PROCEDURE PROGRAM RECORD REPEAT SET THEN TO TYPE UNTIL
%token VAR WHILE WITH


%%
 /*program    :  PROGRAM IDENTIFIER LPAREN IDENTIFIER RPAREN SEMICOLON statement DOT    { parseresult = makeprogn($1, $7);}*/
 
  program    :  PROGRAM IDENTIFIER LPAREN IDENTIFIER RPAREN SEMICOLON block DOT    { parseresult = processProgram($1, $2, $4, $5, $7);}
             ;
			 
	block	: cblock	
			| vblock
			| pblock
			| tblock
			| statement						
			;
			
	tblock 	: TYPE tspec block {$$ = $3;}
			;
			
	tspec   : IDENTIFIER EQ type SEMICOLON tspec 	{insttype($1, $3);}
			| IDENTIFIER EQ type SEMICOLON	{insttype($1, $3);}
			;
			
			
	pblock  : LABEL numberlist SEMICOLON block {$$ = $4;}
			;
	
 numberlist : NUMBER COMMA numberlist 			{instlabel($1);}
			| NUMBER							{instlabel($1);}
			;
			 
	vblock	: VAR varspecs block				{$$ = $3;}
			;
			
	cblock	: CONST eqspec block {$$ = $3;}
	
	eqspec 	: IDENTIFIER EQ expr SEMICOLON eqspec {instconst($1, $3);}
			| IDENTIFIER EQ expr SEMICOLON		{instconst($1, $3);}
			
	varspecs: vargroup SEMICOLON varspecs
			| vargroup SEMICOLON
			;
			
	vargroup: idlist COLON type 				{instvars($1, $3);}
			 
	type	: simpletype						{$$ = $1;}
			;
			
	idlist  : IDENTIFIER COMMA idlist 			{$$ = cons($1, $3);}
			| IDENTIFIER 						{$$ = cons($1, NULL);}
			;
			
	simpletype: IDENTIFIER						{/*$$ = findtype($1);*/}
			;
  statement  :  BEGINBEGIN statement endpart
													{ $$ = makeprogn($1,cons($2, $3)); }
             |  IF expr THEN statement endif   		{ $$ = makeif($1, $2, $4, $5); }
			 | 	FOR assignment TO expr DO statement	{ $$ = makefor(1, $1, $2, $3, $4, $5, $6);}
			 | REPEAT repeatTerms UNTIL expr		{$$ = makerepeat($1, $2, $3, $4);}
			 | exprORassign
	         
             ;
			 
repeatTerms : exprORassign SEMICOLON repeatTerms { $$ = cons($1, $3);}
			| exprORassign
			;
			
exprORassign : expr
			 | assignment
		     ;
			 
  endpart    :  SEMICOLON statement endpart    { $$ = cons($2, $3); }
             |  END                            { $$ = NULL; }
             ;
			 
  endif      :  ELSE statement                 { $$ = $2; }
             |  /* empty */                    { $$ = NULL; }
             ;
			 
  assignment :  IDENTIFIER ASSIGN expr         { $$ = binop($2, $1, $3); }
             ;
  expr       :   IDENTIFIER EQ expr				{$$ = binop($2, $1, $3);}
			 | expr PLUS term                 { $$ = binop($2, $1, $3); }
			 | factor TIMES factor					{ $$ = binop($2, $1, $3);}
			 | MINUS factor						{$$ = unaryop($1, $2);}
			 | factor MINUS factor				{$$ = binop($2, $1, $3);}
			 | STRING
             |  term 
			 | factor
             ;
			 
  term       :  term TIMES factor              { $$ = binop($2, $1, $3); }
		     | term MINUS factor					{$$ = binop($2, $1, $3);}
             |  factor TIMES factor
			 |  factor
             ;
			 
  factor     :  LPAREN expr RPAREN             { $$ = $2; }
             |  IDENTIFIER LPAREN expr RPAREN { $$ = makefuncall($2, $1, $3);}
			 |  IDENTIFIER						{$$ = findid($1);/* want to replace constants with actual value here?? */}
             |  NUMBER
             ;

%%

/* You should add your own debugging flags below, and add debugging
   printouts to your programs.

   You will want to change DEBUG to turn off printouts once things
   are working.
  */

#define DEBUG        0             /* set bits here for debugging, 0 = off  */  //default 31
#define DB_CONS       1             /* bit to trace cons */
#define DB_BINOP      2             /* bit to trace binop */
#define DB_MAKEIF     4             /* bit to trace makeif */
#define DB_MAKEPROGN  8             /* bit to trace makeprogn */
#define DB_PARSERES  16             /* bit to trace parseresult */

 int labelnumber = 0;  /* sequential counter for internal label numbers */

 /* insttype will install a type name in symbol table.
   typetok is a token containing symbol table pointers. */
void  insttype(TOKEN typename, TOKEN typetok){
	printf("installing type...\n");
}
 
 /* instlabel installs a user label into the label table */
void  instlabel (TOKEN num){
	printf("installing label...\n");
	//install into label table. Index into table is the internal label
	labels[labelnumber++] = num->intval;
	int i = 0;
	for(; i < labelnumber; i++){
		printf("%d\n", labels[i]);
	}
	
}
 
 /* findid finds an identifier in the symbol table, sets up symbol table
   pointers, changes a constant to its number equivalent */
TOKEN findid(TOKEN tok){
	SYMBOL result = searchst(tok->stringval);
	TOKEN constant_val = copytoken(tok);
	//if id is in symbol table and 
	if((result != NULL) && (result->kind == CONSTSYM)){
		//printf("found constant variable in symbol table. need to replace with actual value\n\n");
		//printf("token name = %s\n", tok->stringval);
		constant_val->tokentype = NUMBERTOK;
		constant_val->datatype = result->basicdt;			//copy datatype
		//printf("datatype = %d\n", result->basicdt); 
		//integer
		if(constant_val->datatype == 0){
			constant_val->intval = result->constval.intnum;
			//printf("constant_value = %d\n\n", constant_val->intval);
		}
		//real
		else if(constant_val->datatype == 1){
			constant_val->realval = result->constval.realnum;
			//printf("constant_value = %f\n\n", constant_val->realval);
		}
		return constant_val;
	}
	return tok;
	

}
 
 /* makerepeat makes structures for a repeat statement.
   tok and tokb are (now) unused tokens that are recycled. */
TOKEN makerepeat(TOKEN tok, TOKEN statements, TOKEN tokb, TOKEN expr){
	TOKEN copy_tok = copytoken(tok);
	//creating label operator token
	convert(tokb, LABELOP);			//make a new number for the label. use unaryop??
	makeprogn(copy_tok, tokb);
	//creating number for label
	TOKEN new = talloc();			//use this for number of label??
	new->tokentype = NUMBERTOK;
	new->datatype = INTEGER;
	new->intval = labelnumber++;
	//connecting label to its number
	unaryop(tokb, new);
	
	//linking label to statements
	tokb->link = statements;
	
	TOKEN if_copy = copytoken(tokb);
	if_copy->whichval = IFOP;
	if_copy->operands = expr;
	if_copy->link = NULL;
	TOKEN link_pointer = statements->link;
	while(link_pointer->link != NULL)
		link_pointer = link_pointer->link;
	link_pointer->link = if_copy;
	
	//attach progn to expr
	expr->link = makeprogn(copytoken(tok), NULL);
	
	//create goto
	TOKEN gotok = copytoken(if_copy);
	gotok->whichval = GOTOOP;
	gotok->link = NULL;
	TOKEN label_num = copytoken(new);
	//label_num->intval = new->intval;
	label_num->link = NULL;
	label_num->operands = NULL;
	gotok->operands = label_num;
	
	//connect progn to goto
	expr->link->link = gotok;
	

	
	

	return copy_tok;
}
 
/* instconst installs a constant in the symbol table */
void  instconst(TOKEN idtok, TOKEN consttok){
	SYMBOL sym, typesym; int align;
	//typesym = consttok->symtype;				//this doesnt work but was provided in class notes. 
	if(consttok->datatype == 1){
		typesym = searchst("real");		//this works though...
	}
	else if(consttok->datatype == 0){
		typesym = searchst("integer");
	}
	printsymbol(typesym);
	align = alignsize(typesym);
	printf("align = %d\n", align);
	
	sym = insertsym(idtok->stringval);
	sym->kind = CONSTSYM;
	sym->offset = wordaddress(blockoffs[blocknumber], align);
	sym->size = typesym->size;
	blockoffs[blocknumber] = sym->offset + sym->size;
	sym->datatype = typesym;
	sym->basicdt = typesym->basicdt;
	if(consttok->datatype == 0)
		sym->constval.intnum = consttok->intval;
	else if(consttok->datatype == 1)
		sym->constval.realnum = consttok->realval;
}
 
   /*  Note: you should add to the above values and insert debugging
       printouts in your routines similar to those that are shown here.     */
	   
//processes first part of program
TOKEN processProgram(TOKEN tok1, TOKEN tok2, TOKEN tok3, TOKEN tok4, TOKEN tok5){
	convert(tok1, PROGRAMOP);		//fix this garbage
	link(tok1, tok2);
	tok2->link = makeprogn(tok4, tok3);
	tok4->link = tok5;
	tok3->operands = tok5;
	parseresult = tok1;
	return tok1;
}

/* instvars will install variables in symbol table.
   typetok is a token containing symbol table pointer for type. */
void  instvars(TOKEN idlist, TOKEN typetok){
	SYMBOL sym, typesym; int align;
	//typesym = typetok->symtype;				//this doesnt work but was provided in class notes. 
	typesym = searchst(typetok->stringval);		//this works though...
	align = alignsize(typesym);
	//for each id
	while(idlist != NULL){ 		
		sym = insertsym(idlist->stringval);
		sym->kind = VARSYM;
		sym->offset = wordaddress(blockoffs[blocknumber], align);
		sym->size = typesym->size;
		blockoffs[blocknumber] = sym->offset + sym->size;
		sym->datatype = typesym;
		sym->basicdt = typesym->basicdt;
		idlist = idlist->link;
	}
}
	   
//returns a copy of the token
TOKEN copytoken(TOKEN tok){
	TOKEN new = talloc();
	new->tokentype = tok->tokentype;
	new->datatype = tok->datatype;
	new->symtype = tok->symtype;
	new->symentry = tok->symentry;
	new->operands = tok->operands;
	new->link = tok->link;
	new->realval = tok->realval;
	return new;
}

/* makefuncall makes a FUNCALL operator and links it to the fn and args.
   tok is a (now) unused token that is recycled. */
TOKEN makefuncall(TOKEN tok, TOKEN fn, TOKEN args)
{
	TOKEN func = copytoken(tok);
	func->tokentype = OPERATOR;
	func->datatype = STRINGTYPE;
	func->whichval = FUNCALLOP;
	func->link = NULL;
	//cons(fn, args);
	fn->link = args;
	func->operands = fn;
	
	//search symbol table for function. Need to check if arguments need to be coerced
	SYMBOL func_symbol = searchst(fn->stringval);
	int return_type = func_symbol->datatype->basicdt;
	int arg_type = func_symbol->datatype->link->basicdt;
	printf("\n\nfunction name is %s\n", fn->stringval);
	printf("function return type = %d\n", return_type);
	printf("function argument type = %d\n\n", arg_type);

	return func;
}

/* makefor makes structures for a for statement.
   sign is 1 for normal loop, -1 for downto.
   asg is an assignment statement, e.g. (:= i 1)
   endexpr is the end expression
   tok, tokb and tokc are (now) unused tokens that are recycled. */
TOKEN makefor(int sign, TOKEN tok, TOKEN asg, TOKEN tokb, TOKEN endexpr,
              TOKEN tokc, TOKEN statement)
{
	//creating label operator token
	convert(tokb, LABELOP);			//make a new number for the label. use unaryop??
	makeprogn(tok, asg);
	cons(asg, tokb);
	//creating number for label
	TOKEN new = talloc();			//use this for number of label??
	new->tokentype = NUMBERTOK;
	new->datatype = INTEGER;
	new->intval = labelnumber++;
	//connecting label to its number
	unaryop(tokb, new);
	//creating ifop
	TOKEN ifop = talloc();
	ifop->tokentype = OPERATOR;
	ifop->datatype = STRINGTYPE;
	ifop->whichval = IFOP;
	cons(tokb, ifop);
	//creating assignment statement
	TOKEN lteop = talloc();
	lteop->tokentype = OPERATOR;
	lteop->datatype = STRINGTYPE;
	lteop->whichval = LEOP;
	unaryop(ifop, lteop);
	//add operands to LEOP
	TOKEN i = copytoken(asg->operands);
	
	binop(lteop, i, endexpr);
	//connect progn to LEOP
	TOKEN newProgn = makeprogn(copytoken(i), statement);
	newProgn->link = NULL;				//null link left over from copying
	cons(lteop, newProgn);
	
	//part for incrementing loop variable
	TOKEN assignop = copytoken(ifop);
	assignop->whichval = ASSIGNOP;
	//create second operand of incrementation
	TOKEN plusop = copytoken(assignop);
	plusop->whichval = PLUSOP;
	plusop->link = NULL;
	TOKEN one = copytoken(new);
	one->intval = 1;
	binop(plusop, copytoken(i), one);
	binop(assignop, copytoken(i), plusop);
	
	statement->link = assignop;
	/* TOKEN pointer = statement->link->operands;
	//skip progn and attach incrementation to end of arguments
	while(pointer->link != NULL)
		pointer = pointer->link;
	pointer->link = assignop; */
	
	
	//create goto
	TOKEN gotok = copytoken(plusop);
	gotok->whichval = GOTOOP;
	gotok->link = NULL;
	TOKEN zero = copytoken(one);
	zero->intval = labelnumber-1;
	zero->link = NULL;
	zero->operands = NULL;
	gotok->operands = zero;
	cons(assignop, gotok);
	
	return tok;
}

/*link tok with other*/
TOKEN link(TOKEN tok, TOKEN other){
	tok->tokentype = OPERATOR;
	tok->link = other;
	tok->operands = other;
	return tok;
}	

/*converts one token to another type*/
TOKEN convert(TOKEN tok, int opnum){
	tok->tokentype = OPERATOR;
	tok->whichval = opnum;
	return tok;
}
	   
TOKEN cons(TOKEN item, TOKEN list)           /* add item to front of list */
  { item->link = list;
    if (DEBUG & DB_CONS)
       { printf("cons\n");
         dbugprinttok(item);
         dbugprinttok(list);
       };
    return item;
  }

TOKEN binop(TOKEN op, TOKEN lhs, TOKEN rhs)        /* reduce binary operator */
  { op->operands = lhs;          /* link operands to operator       */
    lhs->link = rhs;             /* link second operand to first    */
    rhs->link = NULL;            /* terminate operand list          */
	TOKEN op_copy = copytoken(op);
	//getting type of second argument
	SYMBOL second = searchst(rhs->stringval);
	if(second != NULL)
		printf("rhs datatype = %d\n\n", second->basicdt);
	
	//need to coerce integer to float.
	if((second != NULL) && (lhs->datatype != second->basicdt) && (rhs->datatype != STRINGTYPE)){
		//coerce lhs to float
		if(lhs->datatype == INTEGER){
			op_copy->whichval = FLOATOP;
			op_copy->operands = lhs;
			lhs->link = NULL;
			op_copy->link = rhs;
			op->operands = op_copy;
			
		}
		//coerce rhs to float
		else if(rhs->datatype == INTEGER){
			op_copy->whichval = FLOATOP;
			op_copy->operands = rhs;
			op_copy->link = NULL;
			lhs->link = op_copy;
		}
	}
	
    if (DEBUG & DB_BINOP)
       { printf("binop\n");
         dbugprinttok(op);
         dbugprinttok(lhs);
         dbugprinttok(rhs);
       };
    return op;
  }
  
/* unaryop links a unary operator op to one operand, lhs */
TOKEN unaryop(TOKEN op, TOKEN lhs){
	op->operands = lhs;
	lhs->link = NULL;
	return op;
}

TOKEN makeif(TOKEN tok, TOKEN exp, TOKEN thenpart, TOKEN elsepart)
  {  tok->tokentype = OPERATOR;  /* Make it look like an operator   */
     tok->whichval = IFOP;
     if (elsepart != NULL) elsepart->link = NULL;
     thenpart->link = elsepart;
     exp->link = thenpart;
     tok->operands = exp;
     if (DEBUG & DB_MAKEIF)
        { printf("makeif\n");
          dbugprinttok(tok);
          dbugprinttok(exp);
          dbugprinttok(thenpart);
          dbugprinttok(elsepart);
        };
     return tok;
   }

   /* makeprogn makes a PROGN operator and links it to the list of statements.
   tok is a (now) unused token that is recycled. */
TOKEN makeprogn(TOKEN tok, TOKEN statements)
  {  tok->tokentype = OPERATOR;
     tok->whichval = PROGNOP;
     tok->operands = statements;
     if (DEBUG & DB_MAKEPROGN)
       { printf("makeprogn\n");
         dbugprinttok(tok);
         dbugprinttok(statements);
       };
     return tok;
   }

int wordaddress(int n, int wordsize)
  { return ((n + wordsize - 1) / wordsize) * wordsize; }
 
yyerror(s)
  char * s;
  { 
  fputs(s,stderr); putc('\n',stderr);
  }

main()
  { int res;
    initsyms();
    res = yyparse();
    printst();
    printf("yyparse result = %8d\n", res);
    if (DEBUG & DB_PARSERES) dbugprinttok(parseresult);
    ppexpr(parseresult);           /* Pretty-print the result tree */
  }
