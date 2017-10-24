a.out: lex.yy.o y.tab.o ass6_12CS30006_translator.o  
	g++  lex.yy.o y.tab.o ass6_12CS30006_translator.o -lfl
lex.yy.o: lex.yy.c y.tab.c
	g++  -c lex.yy.c
lex.yy.c: ass6_12CS30006.l
	flex ass6_12CS30006.l
y.tab.o: y.tab.c
	g++  -c y.tab.c
y.tab.c: ass6_12CS30006.y
	yacc -dtv ass6_12CS30006.y
ass6_12CS30006_translator.o: ass6_12CS30006_translator.cxx
	g++  -c ass6_12CS30006_translator.cxx

run1: a.out test_inputs/ass6_12CS30006_test1.c 
	./a.out < test_inputs/ass6_12CS30006_test1.c > test_outputs/ass6_12CS30006_1.out

run2: a.out test_inputs/ass6_12CS30006_test2.c
	./a.out < test_inputs/ass6_12CS30006_test2.c > test_outputs/ass6_12CS30006_2.out

run3: a.out test_inputs/ass6_12CS30006_test3.c
	./a.out < test_inputs/ass6_12CS30006_test3.c > test_outputs/ass6_12CS30006_3.out

run4: a.out test_inputs/ass6_12CS30006_test4.c
	./a.out < test_inputs/ass6_12CS30006_test4.c > test_outputs/ass6_12CS30006_4.out

run5: a.out test_inputs/ass6_12CS30006_test5.c
	./a.out < test_inputs/ass6_12CS30006_test5.c > test_outputs/ass6_12CS30006_5.out
	
clean:
	rm a.out ass6_12CS30006_translator.o lex.yy.o y.tab.o y.tab.c lex.yy.c y.tab.h 
