/*	Definition section */
%{
#include "global.h" // include header if needed
#define BUF_SIZE 1000

extern int yylineno;
extern int yylex();
extern char *yytext; // Get current token from lex
extern char buf[BUF_SIZE]; // Get current code line from lex
char code_buf[100];
FILE *file; // To generate .j file for Jasmin
int table_not_create =0;
void yyerror(char *s);

/* Symbol Table Structure, Variable Definition */
typedef struct Entry Entry;
struct Entry {
    int index;
    char* name;
    char* kind;
    char* type;
    int scope;
    char* attribute;
    Entry *next;
};
typedef struct Header Header;
struct Header {
    int depth;
    int entry_num;
    Entry *table_root;
    Entry *table_tail;
    Header *pre;
};
Header *header_root = NULL; // connect these headers
Header *cur_header = NULL; // current header
int depth = 0;
Value NaV;

extern int syntax_error;
extern int semantic_error;
extern int NumberOfError;
extern int syn_error_number;
extern int dump_flag;
extern char* error_msg[20];
extern char* syn_error_msg[20];
void redeclared_check(char* name,char* kind);
void undeclared_check(char* name,char* kind);
char* add_attribute(Header *header);
/* symbol table functions */
char* convert_type(Type type);
int lookup_symbol(Header *header, char* name);
void create_symbol_table();
void free_symbol_table();
void insert_symbol(Header *header, Value id, char* kind, Value type, Value R_val);
void dump_symbol();
void debug(char* s);
/* code generation functions, just an example! */
void gencode(char * s);
void do_declaration_stat(int index, Value type, Value id, Value R_val);
void do_function_definition(Entry *temp);
void do_function_call(Value id);
void do_assign_expr(Value term1, Operator op, Value term2);
void do_return_stat(Value term1);
void do_print(Value term1);
void find_return_type(Value term);
Value find_assign_type(Value term, Value term2);                
Value do_postfix_expr(Value term1, Operator op);
Value do_multiplication_expr(Value term1, Operator op, Value term2);
Value do_addition_expr(Value term1, Operator op, Value term2);
Value do_comparison_expr(Value term1, Operator op, Value term2);
Value find_original_type(Value term1,int cast);
char* str_replace(char* string, const char* substr, const char* replacement);
%}

%union {
    Value val;
    Operator op;
}

/* Token */
%token IF ELSE FOR WHILE RETURN SEMICOLON PRINT
%token <op> ADDASGN SUBASGN MULASGN DIVASGN MODASGN
%token <op> INC DEC
%token <op> MTE LTE EQ NE
%token <val> VOID INT FLOAT BOOL STRING
%token <val> TRUE FALSE
%token <val> I_CONST F_CONST STR_CONST
%token <val> ID

/* Non-terminal with return, which need to sepcify type */
%type <op> assign_op post_op mul_op add_op cmp_op 
%type <val> expression expression_stat
%type <val> postfix_expr multiplication_expr addition_expr comparison_expr
%type <val> parenthesis_clause
%type <val> constant function_call
%type <val> type
%type <val> parameter parameter_list

/* Yacc will start at this nonterminal */
%start program

/* Grammar section */
%%

program
    : program stat 
    |
    ;
stat
    : declaration
    | func_declaration
    | function_call
    | compound_stat 
    | expression_stat 
    | return_stat 
    | print_func
    | SEMICOLON
    ;
declaration
    : type ID '=' expression SEMICOLON { insert_symbol(cur_header, $2, "variable", $1, $4); }
    | type ID SEMICOLON { insert_symbol(cur_header, $2, "variable", $1, NaV); }
    ;
type
    : INT { $$ = $1; }
    | FLOAT { $$ = $1; }
    | BOOL { $$ = $1; }
    | STRING { $$ = $1; }
    | VOID { $$ = $1; }
    ;
func_declaration
    : type ID '(' { create_symbol_table(); } parameter_list ')' {insert_symbol(cur_header->pre, $2, "function", $1, NaV); } block { dump_flag = 1; } 
    ;
parameter_list
	: parameter { $$ = $1; }
	| parameter_list ',' parameter 
    | {$$ = NaV;}
	;
parameter
    : type ID { $$ = $1; insert_symbol(cur_header, $2, "parameter", $1, NaV); }
    ; 
function_call
    : ID { undeclared_check($1.string, "function"); } '(' argument_list ')' SEMICOLON {do_function_call($1);}
    ;
argument_list
    : ID { undeclared_check($1.string, "variable"); }
    | argument_list ',' ID { undeclared_check($3.string, "variable"); }
    | { }
    ;
compound_stat
    : assign_stat
    | if_stat
    | while_stat
    ;
assign_stat
    : ID { undeclared_check($1.string, "variable"); } assign_op expression SEMICOLON { do_assign_expr($1, $3, $4);}
    ;
assign_op
    : '=' {$$ = ASGN_OP;}
    | ADDASGN {$$ = ADDASGN_OP;}
    | SUBASGN {$$ = SUBASGN_OP;}
    | MULASGN {$$ = MULASGN_OP;}
    | DIVASGN {$$ = DIVASGN_OP;}
    | MODASGN {$$ = MODASGN_OP;}
    ;
if_stat
    : IF expression block
    | IF expression block ELSE block
    | IF expression block ELSE if_stat
    ;
while_stat
    : WHILE expression block
    ;
block
    : lb program rb 
    ;
lb
    : '{' 
    ;
rb
    : '}'
    ;
expression_stat
    : expression {$$ = $1;}
    ;
expression
    : comparison_expr {$$ = $1;}
    ;
constant
    : I_CONST {$$ = $1;}
    | F_CONST {$$ = $1;}
    | '"' STR_CONST '"' { $$ = $2; }
    ;
post_op
    : INC { $$ = INC_OP; }
    | DEC { $$ = DEC_OP; }
    ;
mul_op
    : '*' { $$ = MUL_OP; }
    | '/' { $$ = DIV_OP; }
    | '%' { $$ = MOD_OP; }
    ;
add_op
    : '+' { $$ = ADD_OP; }
    | '-' { $$ = SUB_OP; }
    ;
cmp_op
    : '<' { $$ = LT_OP; }
    | '>' { $$ = MT_OP; }
    | MTE { $$ = MTE_OP; }
    | LTE { $$ = LTE_OP; }
    | EQ { $$ = EQ_OP; }
    | NE { $$ = NE_OP; }
    ;
parenthesis_clause
    : constant { $$ = $1; }
    | ID { undeclared_check($1.string, "variable"); $$ = $1;}
    | '(' expression ')' { $$ = $2; }
    | TRUE { $$ = $1; }
    | FALSE { $$ = $1;  }
    | function_call { $$ = $1; }
    ;
postfix_expr
    : parenthesis_clause { $$ = $1; }
    | parenthesis_clause post_op { $$ = do_postfix_expr($1, $2); }
    ;
multiplication_expr
    : postfix_expr {$$ = $1;}
    | multiplication_expr mul_op postfix_expr { $$ = do_multiplication_expr($1, $2, $3); }
    ;
addition_expr
    : multiplication_expr {$$ = $1;}
    | addition_expr add_op multiplication_expr { $$ = do_addition_expr($1, $2, $3); }
    ;
comparison_expr
    : addition_expr {$$ = $1;}
    | comparison_expr cmp_op addition_expr { $$ = do_comparison_expr($1, $2, $3); }
    ;
return_stat
    : RETURN SEMICOLON { debug("void return"); do_return_stat(NaV); }
	| RETURN expression SEMICOLON{ do_return_stat($2); }
	;
print_func
    : PRINT '(' expression ')' SEMICOLON { do_print($3); }
    | PRINT '(' '"' STRING '"' ')' SEMICOLON { do_print($4); }
    ;

%%

/* C code section */
int main(int argc, char** argv)
{
    yylineno = 0;
    NaV.type = NAT;
    NaV.i_val = 0;
    NaV.f_val = 0.0;
    NaV.string = "";
    create_symbol_table();
    file = fopen("compiler_hw3.j","w");
    fprintf(file,   ".class public compiler_hw3\n"
                    ".super java/lang/Object\n");
    yyparse();
    // fprintf(file, "\treturn\n"
    //               ".end method\n");
    if(!syntax_error){
        dump_symbol();
        printf("\nTotal lines: %d \n",yylineno);
    }
    fclose(file);

    return 0;
}

// void yyerror(char *s)
// {
//     printf("\n|-----------------------------------------------|\n");
//     printf("| Error found in line %d: %s\n", yylineno, buf);
//     printf("| %s", s);
//     printf("\n| Unmatched token: %s", yytext);
//     printf("\n|-----------------------------------------------|\n");
//     exit(-1);
// }
void yyerror(char *s)
{
    if(!strcmp(s,"syntax error")){
        printf("%d: %s\n", yylineno, buf);
        syntax_error = 1;
        if(semantic_error){
            for (int i = 0; i< NumberOfError;i++){
                printf("\n|-----------------------------------------------|\n");
                printf("| Error found in line %d: %s\n", yylineno, buf);
                printf("| %s", error_msg[i]);
                printf("\n|-----------------------------------------------|\n\n");
                memset(error_msg[i],'\0', 200);
            }
            semantic_error = 0;
            NumberOfError = 0;
        }
        printf("\n|-----------------------------------------------|\n");
        printf("| Error found in line %d: %s\n", yylineno, buf);
        printf("| %s", s);
        printf("\n|-----------------------------------------------|\n\n");        
    } else {     
        printf("\n|-----------------------------------------------|\n");
        printf("| Error found in line %d: %s\n", yylineno, buf);
        printf("| %s", s);
        printf("\n|-----------------------------------------------|\n\n");
    }
}

/* symbol table functions */
void create_symbol_table() {
    Header *ptr = malloc(sizeof(Header));
    ptr->depth = depth++;
    ptr->entry_num = 0;
    ptr->table_root = malloc(sizeof(Entry));
    ptr->table_root->next = NULL;
    ptr->table_tail = ptr->table_root;
    if(cur_header == NULL) header_root = ptr;
    printf("create a table: %d\n", ptr->depth);
    ptr->pre = cur_header;
    cur_header = ptr;
}
void insert_symbol(Header *header, Value id, char* kind, Value type, Value R_val){
    printf("insert_symbol %s\n",id.string);
    if(header == NULL){
        debug("fuck");
        header = header_root;
    }
    if(cur_header == NULL){
        create_symbol_table();
        // header_root = cur_header;
        header = cur_header;
    }
    if(lookup_symbol(cur_header, id.string) == -1){
        Entry *temp = malloc(sizeof(Entry));
        temp->index = header->entry_num++;
        temp->name = id.string;
        id.type =type.type;
        temp->kind = kind;
        temp->type = type.string;
        temp->scope = header->depth;
        temp->next = NULL;
        if(!strcmp(kind,"function")){
            char* attr = add_attribute(cur_header);
            temp->attribute = attr;
        }
        header->table_tail->next = temp;
        header->table_tail = header->table_tail->next;
        if(!strcmp(kind,"variable")){
            do_declaration_stat(temp->index, type, id, R_val);
        }
        // else if(!strcmp(kind,"parameter")){
        //     do_declaration_stat(temp->index, type, id, R_val);
        // }
        else if(!strcmp(kind, "function")){ 
            do_function_definition(temp);
        }
        // printf("%-10d%-10s%-12s%-10s%-10d%-10s\n", temp->index, temp->id, temp->kind, temp->type, temp->scope, temp->attribute);
    } 
    else{
        redeclared_check(id.string, kind);
    }
}
char* add_attribute(Header *header){
    int n = 0;
    Entry *cur = header->table_root->next;
    char* temp = malloc(50);
    while(cur != NULL){
        if(!strcmp(cur->kind,"parameter")){
            if(n == 0){
                n++;
                strcpy(temp,cur->type);
                //attribute_gencode(cur->index, cur->type, cur, NAV);
            }
            else{
                strcat(temp,",");
                strcat(temp,cur->type);
            }
        }
        cur = cur->next;
    }
    return temp;
}

int lookup_symbol(Header *header, char* id) { 
    // return index 0~n :redeclared
    // return -1, undeclared
    if(header->table_root == NULL){
        return -1;
    }
    Entry *cur = header->table_root->next;
    while(cur != NULL){
        if(!strcmp(cur->name,id))
        {
            return cur->index;
        }
        else{
            cur = cur->next;
        }
    }
    return -1;
}

void dump_symbol() {
    printf("\n%-10s%-10s%-12s%-10s%-10s%-10s\n\n",
           "Index", "Name", "Kind", "Type", "Scope", "Attribute");
    Entry *cur_entry = cur_header->table_root->next;
    while(cur_entry != NULL) {
        if(cur_entry->attribute != NULL) {
            printf("%-10d%-10s%-12s%-10s%-10d%s\n", cur_entry->index, cur_entry->name, cur_entry->kind, cur_entry->type, cur_entry->scope, cur_entry->attribute);
        }
        else {
            printf("%-10d%-10s%-12s%-10s%-10d\n", cur_entry->index, cur_entry->name, cur_entry->kind, cur_entry->type, cur_entry->scope);
        }
        Entry *temp = cur_entry;
        cur_entry = cur_entry->next;
        free(temp);
        temp = NULL;
    }
    printf("\n");
    cur_header->entry_num = 0;
    Header* tmp = cur_header;
    cur_header = cur_header->pre;
    free(tmp);
    tmp = NULL;
    depth = depth -1;
}

void free_symbol_table(){

}

void undeclared_check(char* name, char* kind){
        int undeclared = 1;
        Header *ptr = cur_header;
        while(ptr != NULL){
            if(lookup_symbol(ptr,name) != -1){
                undeclared = 0;
                break;
            } else {
                ptr = ptr->pre; // goto parent scope
            }
        }
        if(undeclared){
            if(!strcmp(kind, "function")){
                error_msg[NumberOfError] = malloc(200);
                sprintf(error_msg[NumberOfError++],"Undeclared function %s", name);
                semantic_error = 1;
            } else if(!strcmp(kind, "variable")){
                error_msg[NumberOfError] = malloc(200);
                sprintf(error_msg[NumberOfError++],"Undeclared variable %s", name);
                semantic_error = 1;
            }
        }
}
void redeclared_check(char* name, char* kind){
    //printf("%s\n",type);
    if(!strcmp(kind, "function")){
        sprintf(error_msg[NumberOfError++],"Redeclared function %s", name);
        semantic_error = 1;
    } else if(!strcmp(kind, "variable")){
        sprintf(error_msg[NumberOfError++],"Redeclared variable %s", name);
        semantic_error = 1;
    }
}

/* code generation functions */
void gencode(char *s) {
    fprintf(file, "%s", s);
}
// void attribute_gencode(int index, char* type, Value R_val){
//     debug("do_declaration");
//     if(index == -1){
//         debug("not found declaration");
//     }
//     switch (type.type){
//         case INT_T:
//             sprintf(code_buf,"\tiload %d\n", R_val.i_val, index);
//             strcat(attr_codebuf,code_buf);
//             break;
//         case FLOAT_T:
//             sprintf(code_buf,"\tiload %i\n", R_val.f_val, index); 
//             strcat(attr_codebuf,code_buf);
//             break;
//         case STRING_T:
//             sprintf(code_buf,"\tldc \"%s\"\n\tastore %i\n", R_val.string, index);
//             strcat(attr_codebuf,code_buf); 
//             break;
//         case BOOL_T:
//             sprintf(code_buf,"\tldc %i\n\tistore %i\n", R_val.i_val, index);
//             strcat(attr_codebuf,code_buf); 
//             break;
//         default:
//             printf("%s,%d\n",id,type.type);
//             debug("variable type is not int,float,string,bool. line 475");
//     }
// }

void do_declaration_stat(int index, Value type, Value id, Value R_val){
    debug("do_declaration");
    int global = 0;
    if(cur_header->depth == 0){
        global = 1;
    }
    char* asm_type = convert_type(type.type);
    if(index == -1){
        debug("not found declaration");
    }
    if(global){
        switch (type.type){
            case INT_T:
                sprintf(code_buf,".field public static %s %s = %d\n",id.string, asm_type, R_val.i_val); 
                gencode(code_buf);
                break;
            case FLOAT_T:
                sprintf(code_buf,".field public static %s %s = %f\n",id.string, asm_type, R_val.f_val);
                gencode(code_buf); 
                break;
            case STRING_T:
                sprintf(code_buf,".field public static %s %s = \"%s\"\n",id.string, asm_type, R_val.string);
                gencode(code_buf); 
                break;
            case BOOL_T:
                sprintf(code_buf,".field public static %s %s = \"%d\"\n",id.string, asm_type, R_val.i_val);
                gencode(code_buf); 
                break;
            default:
                printf("%d\n",type.type);
                debug("variable type is not int,float,string,bool. line 455");
                break;
        }
    }
    else if(!strcmp(R_val.string,"calculated")){ 
        switch (type.type){
            case INT_T:
                sprintf(code_buf,"\tistore %d\n", index);
                gencode(code_buf); 
                break;
            case FLOAT_T:
                sprintf(code_buf,"\tfstore %i\n", index); 
                gencode(code_buf);
                break;
            case STRING_T:
                sprintf(code_buf,"\tastore %i\n", index);
                gencode(code_buf); 
                break;
            case BOOL_T:
                sprintf(code_buf,"\tistore %i\n",  index);
                gencode(code_buf); 
                break;
            default:
                printf("%s,%d\n",id.string,type.type);
                debug("variable type is not int,float,string,bool. line 475");
        }
    }
    else{
        switch (type.type){
            case INT_T:
                sprintf(code_buf,"\tldc %d\n\tistore %d\n", R_val.i_val, index);
                gencode(code_buf); 
                break;
            case FLOAT_T:
                sprintf(code_buf,"\tldc %f\n\tfstore %i\n", R_val.f_val, index); 
                gencode(code_buf);
                break;
            case STRING_T:
                sprintf(code_buf,"\tldc \"%s\"\n\tastore %i\n", R_val.string, index);
                gencode(code_buf); 
                break;
            case BOOL_T:
                sprintf(code_buf,"\tldc %i\n\tistore %i\n", R_val.i_val, index);
                gencode(code_buf); 
                break;
            default:
                printf("%s,%d\n",id.string,type.type);
                debug("variable type is not int,float,string,bool. line 475");
        }
    }
}
void debug(char* s){
    printf("%s\n",s);
}
char* convert_type(Type type){
    switch (type){
        case INT_T:
            return "I";
            break;
        case FLOAT_T:
            return "F";
            break;
        case STRING_T:
            return "Ljava/lang/String;";
            break;
        case BOOL_T:
            return "Z";
            break;
        case VOID_T:
            return "V";
            break;     
        default :
            debug("type is not I, F, STRING, Z, V");
            break;
    }
}
void do_function_definition(Entry* temp){
    char* parameter = str_replace(temp->attribute,",","");
    parameter = str_replace(parameter,"int","I");
    parameter = str_replace(parameter,"float","F");
    parameter = str_replace(parameter,"bool", "Z");
    parameter = str_replace(parameter,"string","Ljava/lang/String;");
    if(!strcmp(temp->name,"main")){
        parameter = "[Ljava/lang/String;";
    }
    char* return_type = str_replace(temp->type,"int","I");
    return_type = str_replace(return_type,"float","F");
    return_type = str_replace(return_type,"bool", "Z");
    return_type = str_replace(return_type,"void", "V");
    return_type = str_replace(return_type,"string","Ljava/lang/String;");
    sprintf(code_buf,".method public static %s(%s)%s\n", temp->name,parameter,return_type);
    gencode(code_buf);
    sprintf(code_buf,".limit stack 50\n");
    gencode(code_buf);
    sprintf(code_buf,".limit locals 50\n");
    gencode(code_buf);
    //gencode(attr_codebuf);

}
char* str_replace(char* string, const char* substr, const char* replacement) {
	char* tok = NULL;
	char* newstr = NULL;
	char* oldstr = NULL;
	int   oldstr_len = 0;
	int   substr_len = 0;
	int   replacement_len = 0;

	newstr = strdup(string);
	substr_len = strlen(substr);
	replacement_len = strlen(replacement);

	if (substr == NULL || replacement == NULL) {
		return newstr;
	}

	while ((tok = strstr(newstr, substr))) {
		oldstr = newstr;
		oldstr_len = strlen(oldstr);
		newstr = (char*)malloc(sizeof(char) * (oldstr_len - substr_len + replacement_len + 1));

		if (newstr == NULL) {
			free(oldstr);
			return NULL;
		}

		memcpy(newstr, oldstr, tok - oldstr);
		memcpy(newstr + (tok - oldstr), replacement, replacement_len);
		memcpy(newstr + (tok - oldstr) + replacement_len, tok + substr_len, oldstr_len - substr_len - (tok - oldstr));
		memset(newstr + oldstr_len - substr_len + replacement_len, 0, 1);

		free(oldstr);
	}
	return newstr;
}
void do_assign_expr(Value term1, Operator op, Value term2){
    debug("do_assign_expr.");
    int toint = 0;
    int tofloat = 0;
    Value result;    
    // if(result.type == INT_T){
    //     if(term2.type == FLOAT_T){
    //         toint = 1;
    //     }
    // }
    // else if(result.type == FLOAT_T){
    //     if(term2.type == INT_T){
    //         tofloat = 1;
    //     }
    // }
    // else {
    //     debug("term1 is string");
    // }
    switch (op){
        case ASGN_OP:
            find_assign_type(term1,term2); //Lval must be a variable
            break;
        case ADDASGN_OP:
            term2 = do_addition_expr(term1,ADD_OP,term2);
            find_assign_type(term1,term2);  
            break;
        case SUBASGN_OP:
            term2 = do_addition_expr(term1,SUB_OP,term2);
            find_assign_type(term1,term2);
            break;
        case MULASGN_OP:
            term2 = do_multiplication_expr(term1,MUL_OP,term2);
            find_assign_type(term1,term2);
            break;
        case DIVASGN_OP:
            term2 = do_multiplication_expr(term1,DIV_OP,term2);
            find_assign_type(term1,term2);
            break;
        case MODASGN_OP:
            term2 = do_multiplication_expr(term1,MOD_OP,term2);
            find_assign_type(term1,term2);
            break;
        default:
            break;
    }
    int R_int;
    float R_float;
    int cast = 0;
    if(term2.type == ID_T){
        term2 = find_original_type(term2, cast);
    }
    if(term1.type == INT_T){
        if(term2.type == INT_T)
            R_int = term2.i_val;
        else{
            R_int = (int)term2.f_val;
        }
    }
    else if(term1.type == FLOAT_T){
        if(term2.type == INT_T)
            R_float = (float)term2.i_val;
        else{
            R_float = term2.f_val;
        }
    }
    switch(op){
        case ASGN_OP:
            if(term1.type == INT_T){
                term1.i_val = R_int;
            }
            else {
                term1.f_val = R_float;
            }
            break;
        case ADDASGN_OP:
            if(term1.type == INT_T){
                term1.i_val += R_int;
            }
            else {
                term1.f_val += R_float;
            }
            break;
        case SUBASGN_OP:
            if(term1.type == INT_T){
                term1.i_val -= R_int;
            }
            else {
                term1.f_val -= R_float;
            }
            break;
        case MULASGN_OP:
            if(term1.type == INT_T){
                term1.i_val *= R_int;
            }
            else {
                term1.f_val *= R_float;
            }
            break;
        case DIVASGN_OP:
            if(term1.type == INT_T){
                term1.i_val /= R_int;
            }
            else {
                term1.f_val /= R_float;
            }
            break;
        case MODASGN_OP:
            if(term1.type == INT_T){
                term1.i_val %= R_int;
            }
            else {
                debug("cannot MODASGN float type");
            }
            break;
        default:
            debug("NOT ASSIGN OP!!!");
            break;
    }
}
void do_return_stat(Value term1){
    printf("return type %d.\n",term1.type);

    if(term1.type == VOID_T || term1.type == NAT){
        sprintf(code_buf,"\treturn\n.end method\n");
        gencode(code_buf);
    }
    else{
        switch(term1.type){
            case ID_T:
                find_return_type(term1);                
                break;
            case INT_T:
                sprintf(code_buf,"\tldc %d\n",term1.i_val);
                gencode(code_buf);
                sprintf(code_buf,"\tireturn\n");
                gencode(code_buf);
                break;
            case FLOAT_T:
                sprintf(code_buf,"\tldc %f\n",term1.f_val);
                gencode(code_buf);
                sprintf(code_buf,"\tfreturn\n");
                gencode(code_buf);
                break;
            case STRING_T:
                sprintf(code_buf,"\tldc \"%s\"\n",term1.string);
                gencode(code_buf);
                sprintf(code_buf,"\tareturn\n");
                gencode(code_buf);
                break;
            case BOOL_T:
                sprintf(code_buf,"\tldc %d\n",term1.i_val);
                gencode(code_buf);
                sprintf(code_buf,"\tireturn\n");
                gencode(code_buf);
                break;
        }
        sprintf(code_buf,".end method\n");
        gencode(code_buf);
    }
}
void do_print(Value term1){
    debug("do_print");
    switch(term1.type){
        case ID_T:
            term1 = find_original_type(term1,0);
            break;
        case INT_T:
            sprintf(code_buf,"\tldc %d\n",term1.i_val);
            gencode(code_buf);
            break;
        case FLOAT_T:
            sprintf(code_buf,"\tldc %f\n",term1.f_val);
            gencode(code_buf);
            break;
        case STRING_T:
            sprintf(code_buf,"\tldc %s\n",term1.string);
            gencode(code_buf);
            break;
    }
    sprintf(code_buf,"\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
    gencode(code_buf);
    sprintf(code_buf,"\tswap\n\tinvokevirtual java/io/PrintStream/println(%s)V\n", convert_type(term1.type));
    gencode(code_buf);
}
Value do_postfix_expr(Value term1, Operator op){
    Value result;
    if(!strcmp(term1.string,"calculated")){

    }
    else{
        switch (term1.type){
            case ID_T:
                term1 = find_original_type(term1,0);
                break;
            case INT_T:
                sprintf(code_buf,"\tldc %d\n",term1.i_val);
                gencode(code_buf);
                break;
            default:
                debug("error type in postfix expr.");
                break;
        }
    }
    switch(op){
        case INC_OP:
            gencode("\tiinc\n");
            break;
        case DEC_OP:
            gencode("\tldc -1\n");
            gencode("\tiadd\n");
            break;
        default:
            debug("NOT INC , DEC OP!!!");
            break;
    }
    result.string = "calculated";
    return term1;
}
Value do_multiplication_expr(Value term1, Operator op, Value term2){
    debug("do_multiplication");
    Value result;
    int cast = 0;
    if(!strcmp(term1.string,"calculated")){
        debug("calculated, don't need to load Lvalue.");
        if(term1.type == FLOAT_T){
            cast = 1;
        }
    }
    else{
        switch (term1.type){
            case ID_T:
                term1 = find_original_type(term1,0);
                break;
            case INT_T:
                sprintf(code_buf,"\tldc %d\n",term1.i_val);
                gencode(code_buf);
                break;
            case FLOAT_T:
                sprintf(code_buf,"\tldc %f\n",term1.f_val);
                gencode(code_buf);
                cast = 1;
                break;
            default:
                debug("error type of addition");
                break;
        }
    }
    switch (term2.type){
        case ID_T:
            term2 = find_original_type(term2, cast);
            break;
        case INT_T:
            if(!strcmp(term2.string,"calculated")){
                debug("calculated, don't need to reload Rvalue.");
                if(!strcmp(term1.string,"calculated")){
                    if(term1.type == FLOAT_T){
                        gencode("\ti2f\n");
                    }   
                    else{
                        debug("both are calculated.");
                    }  
                }
                else{
                    if(term1.type == FLOAT_T){
                        gencode("\tswap\n");
                        gencode("\ti2f\n");
                    }
                }              
            }
            else{
                sprintf(code_buf,"\tldc %d\n",term2.i_val);
                gencode(code_buf);
                if(term1.type == FLOAT_T){
                    sprintf(code_buf,"\ti2f\n");
                    gencode(code_buf);
                }
            }
            break;
        case FLOAT_T:
            if(!strcmp(term2.string,"calculated")){
                if(!strcmp(term1.string,"calculated")){
                    if(term1.type == INT_T){
                        gencode("\tswap\n");
                        gencode("\ti2f\n");
                    }
                }
            }
            else{
                if(term1.type == INT_T){
                    gencode("\ti2f\n");
                }
                sprintf(code_buf,"\tldc %f\n",term2.f_val);
                gencode(code_buf);
            }
            break;
        default:
            debug("error type of addition");
            break;
    }
    printf("term1:%d term2:%d \n",term1.type,term2.type);
    if(term1.type == FLOAT_T || term2.type == FLOAT_T){
        result.type = FLOAT_T;
    }
    else {
        result.type = INT_T;
    }
    printf("result type: %d\n",result.type);
    switch (op){
        case MUL_OP:
            if(result.type == INT_T){
                sprintf(code_buf,"\timul\n");
                gencode(code_buf);
                // result.i_val = L_int + R_int;
            }
            else {
                sprintf(code_buf,"\tfmul\n");
                gencode(code_buf);
                // result.f_val = L_float + R_float;
            }
            break;
        case DIV_OP:
            if(result.type == INT_T){
                sprintf(code_buf,"\tidiv\n");
                gencode(code_buf);
                // result.i_val = L_int - R_int;
            }
            else {
                sprintf(code_buf,"\tfdiv\n");
                gencode(code_buf);
                // result.f_val = L_float - R_float;
            }
            break;
        case MOD_OP:
            if(result.type == INT_T){
                sprintf(code_buf,"\tirem\n");
                gencode(code_buf);
                // result.i_val = L_int - R_int;
            }
            else {
                debug("float cannot be modulized!!");
                // result.f_val = L_float - R_float;
            }
            break;
        default:
            debug("NOT * / % OP!!!");
            break;
    }
    result.string = "calculated";
    return result;
}
Value do_addition_expr(Value term1, Operator op, Value term2){
    debug("do_addition");
    Value result;
    int cast = 0;
    if(!strcmp(term1.string,"calculated")){
        debug("calculated, don't need to load Lvalue.");
        if(term1.type == FLOAT_T){
            cast = 1;
        }
    }
    else{
        switch (term1.type){
            case ID_T:
                term1 = find_original_type(term1,0);
                break;
            case INT_T:
                sprintf(code_buf,"\tldc %d\n",term1.i_val);
                gencode(code_buf);
                break;
            case FLOAT_T:
                sprintf(code_buf,"\tldc %f\n",term1.f_val);
                gencode(code_buf);
                cast = 1;
                break;
            default:
                debug("error type of addition");
                break;
        }
    }
    switch (term2.type){
        case ID_T:
            term2 = find_original_type(term2, cast);
            break;
        case INT_T:
            if(!strcmp(term2.string,"calculated")){
                debug("calculated, don't need to reload Rvalue.");
                if(!strcmp(term1.string,"calculated")){
                    if(term1.type == FLOAT_T){
                        gencode("\ti2f\n");
                    }   
                    else{
                        debug("both are calculated.");
                    }  
                }
                else{
                    if(term1.type == FLOAT_T){
                        gencode("\tswap\n");
                        gencode("\ti2f\n");
                    }
                }              
            }
            else{
                sprintf(code_buf,"\tldc %d\n",term2.i_val);
                gencode(code_buf);
                if(term1.type == FLOAT_T){
                    sprintf(code_buf,"\ti2f\n");
                    gencode(code_buf);
                }
            }
            break;
        case FLOAT_T:
            if(!strcmp(term2.string,"calculated")){
                if(!strcmp(term1.string,"calculated")){
                    if(term1.type == INT_T){
                        gencode("\tswap\n");
                        gencode("\ti2f\n");
                    }
                }
            }
            else{
                if(term1.type == INT_T){
                    gencode("\ti2f\n");
                }
                sprintf(code_buf,"\tldc %f\n",term2.f_val);
                gencode(code_buf);
            }
            break;
        default:
            debug("error type of addition");
            break;
    }
    printf("term1:%d term2:%d \n",term1.type,term2.type);
    if(term1.type == FLOAT_T || term2.type == FLOAT_T){
        result.type = FLOAT_T;
    }
    else {
        result.type = INT_T;
    }
    printf("result type: %d\n",result.type);
    switch (op){
        case ADD_OP:
            if(result.type == INT_T){
                gencode("\tiadd\n");
            }
            else if(result.type == FLOAT_T){
                gencode("\tfadd\n");
            }
            else{
                debug("result type is not int or float\n");
            }
            break;
        case SUB_OP:
            if(result.type == INT_T){
                gencode("\tisub\n");
            }
            else {
                gencode("\tfsub\n");
            }
            break;
        default:
            debug("NOT + - OP!!!");
            break;
    }
    result.string = "calculated";
    return result;
}

Value do_comparison_expr(Value term1, Operator op, Value term2){
//     debug("do compare");
//     Value result;
//     result.type = BOOL_T;
//     Type t;
//     int L_int;
//     float L_float;
//     int R_int;
//     float R_float;

//     if(term1.type == ID_T){
//         term1 = find_original_type(term1);
//     }
//     if(term2.type == ID_T){
//         term2 = find_original_type(term2);
//     }

//     if(term1.type == INT_T){
//         if(term2.type == INT_T){
//             L_int = term1.i_val;
//             R_int = term2.i_val;
//             t = INT_T;
//         }
//         else{
//             L_float = (float)term2.i_val;
//             R_float = term2.f_val;
//             t = FLOAT_T;
//         }
//     }
//     else if(term1.type == FLOAT_T){
//         if(term2.type == INT_T){
//             L_float = term1.f_val;
//             R_float = (float)term2.i_val;
//             t = FLOAT_T;
//         }
//         else{
//             L_float = term1.f_val;
//             R_float = term2.f_val;
//             t = FLOAT_T;
//         }
//     }
//     switch (op){
//         case EQ_OP:
//             if(t == INT_T){
//                 result.i_val = (int)(L_int == R_int);
//             }
//             else {
//                 result.i_val = (int)(L_float == R_float);
//             }
//             break;
//         case NE_OP:
//             if(t == INT_T){
//                 result.i_val = (int)(L_int != R_int);
//             }
//             else {
//                 result.i_val = (int)(L_float != R_float);
//             }
//             break;
//         case LT_OP:
//             if(t == INT_T){
//                 result.i_val = (int)(L_int < R_int);
//             }
//             else {
//                 result.i_val = (int)(L_float < R_float);
//             }
//             break;
//         case LTE_OP:
//             if(t == INT_T){
//                 result.i_val = (int)(L_int <= R_int);
//             }
//             else {
//                 result.i_val = (int)(L_float <= R_float);
//             }
//             break;
//         case MT_OP:
//             if(t == INT_T){
//                 result.i_val = (int)(L_int > R_int);
//             }
//             else {
//                 result.i_val = (int)(L_float > R_float);
//             }
//             break;
//         case MTE_OP:
//             if(t == INT_T){
//                 result.i_val = (int)(L_int >= R_int);
//             }
//             else {
//                 result.i_val = (int)(L_float >= R_float);
//             }
//             break;
//         default:
//             debug("NOT A CMP_OP!!!");
//             break;
//     }

//     return result;
}

Value find_original_type(Value term, int cast){
    debug("find_original_type");
    Header *ptr = cur_header;
        while(ptr != NULL){
            Entry* cur_entry = ptr->table_root->next;
            while(cur_entry != NULL){
                if(!strcmp(cur_entry->name,term.string))
                {
                    if(!strcmp(cur_entry->type,"int")){
                        term.type = INT_T;
                        if(ptr->depth == 0){
                            sprintf(code_buf,"\tgetstatic compiler_hw3/%s %s\n",term.string,convert_type(INT_T));
                            gencode(code_buf);
                            if(cast){
                                sprintf(code_buf,"\ti2f\n");
                                gencode(code_buf);
                            }
                        }
                        else{
                            sprintf(code_buf,"\tiload %d\n",cur_entry->index);
                            gencode(code_buf);
                            if(cast){
                                sprintf(code_buf,"\ti2f\n");
                                gencode(code_buf);
                            }
                        }
                    }
                    else if(!strcmp(cur_entry->type,"float")){
                        term.type = FLOAT_T;
                        if(ptr->depth == 0){
                            sprintf(code_buf,"\tgetstatic compiler_hw3/%s %s\n",term.string,convert_type(FLOAT_T));
                            gencode(code_buf);
                        }
                        else{
                            sprintf(code_buf,"\tfload %d\n",cur_entry->index);
                            gencode(code_buf);
                        }
                    }
                    else{
                        debug("original type is not int or float.");
                    }
                    //printf("ID_T original type is:%d\n",term1.type);
                    return term;
                }
                else{
                    cur_entry = cur_entry->next;
                }
            }
            ptr = ptr->pre;
        }
        debug("not found ID_T original type");
}
Value find_assign_type(Value term, Value term2){
    debug("find_assign_type");
    printf("term1: %d term2: %d\n",term.type,term2.type);
    Header *ptr = cur_header;
        while(ptr != NULL){
            Entry* cur_entry = ptr->table_root->next;
            while(cur_entry != NULL){
                if(!strcmp(cur_entry->name,term.string)){
                    if(!strcmp(cur_entry->type,"int")){
                        term.type = INT_T;
                        if(ptr->depth == 0){
                            if(term2.type == FLOAT_T){
                                sprintf(code_buf,"\tf2i\n");
                                gencode(code_buf);
                            }
                            sprintf(code_buf,"\tputstatic compiler_hw3/%s %s\n",term.string,convert_type(INT_T));
                            gencode(code_buf);
                        }
                        else{
                            if(term2.type == FLOAT_T){
                                sprintf(code_buf,"\tf2i\n");
                                gencode(code_buf);
                            }
                            sprintf(code_buf,"\tistore %d\n",cur_entry->index);
                            gencode(code_buf);
                        }
                    }
                    else if(!strcmp(cur_entry->type,"float")){
                        term.type = FLOAT_T;
                        if(ptr->depth == 0){
                            if(term2.type == INT_T){
                                sprintf(code_buf,"\ti2f\n");
                                gencode(code_buf);
                            }
                            sprintf(code_buf,"\tputstatic compiler_hw3/%s %s\n",term.string,convert_type(FLOAT_T));
                            gencode(code_buf);
                        }
                        else{
                            if(term2.type == INT_T){
                                sprintf(code_buf,"\ti2f\n");
                                gencode(code_buf);
                            }
                            sprintf(code_buf,"\tfstore %d\n",cur_entry->index);
                            gencode(code_buf);
                        }
                    }
                    else{
                        debug("original type is not int or float.");
                    }
                    //printf("ID_T original type is:%d\n",term1.type);
                    return term;
                }
                else{
                    cur_entry = cur_entry->next;
                }
            }
        }
            ptr = ptr->pre;
        debug("not found ID_T original type");   
}

void find_return_type(Value term){
    debug("find_return_type");
    Header *ptr = cur_header;
        while(ptr != NULL){
            Entry* cur_entry = ptr->table_root->next;
            while(cur_entry != NULL){
                if(!strcmp(cur_entry->name,term.string)){
                    if(ptr->depth == 0){
                        if(!strcmp(cur_entry->type,"int")){
                            sprintf(code_buf,"\tgetstatic compiler_hw3/%s I\n",term.string);
                            gencode(code_buf);
                            sprintf(code_buf,"\tireturn\n");
                            gencode(code_buf);
                        }
                        else if(!strcmp(cur_entry->type,"float")){
                            sprintf(code_buf,"\tgetstatic compiler_hw3/%s F\n",term.string);
                            gencode(code_buf);
                            sprintf(code_buf,"\tfreturn\n");
                            gencode(code_buf);
                        }
                        else if(!strcmp(cur_entry->type,"string")){
                            sprintf(code_buf,"\tgetstatic compiler_hw3/%s Ljava/lang/String;\n",term.string);
                            gencode(code_buf);
                            sprintf(code_buf,"\tareturn\n");
                            gencode(code_buf);
                        }
                        else if(!strcmp(cur_entry->type,"bool")){
                            sprintf(code_buf,"\tgetstatic compiler_hw3/%s Z;\n",term.string);
                            gencode(code_buf);
                            sprintf(code_buf,"\tireturn\n");
                            gencode(code_buf);
                        }
                        else{
                            debug("original type is not int,float,string,bool.");
                        }
                    }
                    else{
                        if(!strcmp(cur_entry->type,"int")){
                            sprintf(code_buf,"\tiload %d\n",cur_entry->index);
                            gencode(code_buf);
                            sprintf(code_buf,"\tireturn\n");
                            gencode(code_buf);
                        }
                        else if(!strcmp(cur_entry->type,"float")){
                            sprintf(code_buf,"\tfload %d\n",cur_entry->index);
                            gencode(code_buf);
                            sprintf(code_buf,"\tfreturn\n");
                            gencode(code_buf);
                        }
                        else if(!strcmp(cur_entry->type,"string")){
                            sprintf(code_buf,"\taload %d\n",cur_entry->index);
                            gencode(code_buf);
                            sprintf(code_buf,"\tareturn\n");
                            gencode(code_buf);
                        }
                        else if(!strcmp(cur_entry->type,"bool")){
                            sprintf(code_buf,"\tiload %d\n",cur_entry->index);
                            gencode(code_buf);
                            sprintf(code_buf,"\tireturn\n");
                            gencode(code_buf);
                        }
                        else{
                            debug("original type is not int,float,string,bool.");
                        }
                    }
                    // sprintf(code_buf,".end method\n");
                    // gencode(code_buf);
                    break;
                    //printf("ID_T original type is:%d\n",term1.type);
                }
                else{
                    cur_entry = cur_entry->next;
                    }
                }
            ptr = ptr->pre;
        }
        debug("not found ID_T original type");
}
void do_function_call(Value id){
    Entry *cur = header_root->table_root->next;
    char* name = malloc(50);
    char* type = malloc(50);
    char* argument = malloc(50);
    while(cur != NULL){
        if(!strcmp(cur->kind,"function")){
            strcpy(name,cur->name);
            strcpy(type,cur->type);
            strcpy(argument,cur->attribute);
            break;
        }
        cur = cur->next;
    }
    argument = str_replace(argument,",","");
    argument = str_replace(argument,"int","I");
    argument = str_replace(argument,"float","F");
    argument = str_replace(argument,"bool", "Z");
    argument = str_replace(argument,"string","Ljava/lang/String;");
    type = str_replace(type,"int","I");
    type = str_replace(type,"float","F");
    type = str_replace(type,"bool", "Z");
    type = str_replace(type,"void", "V");
    type = str_replace(type,"string","Ljava/lang/String;");
    sprintf(code_buf,"invokestatic compiler_hw3/%s(%s)%s",name,argument,type);
    gencode(code_buf);

}