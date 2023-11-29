DIRNAME:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

TARGET?=$(shell basename ${DIRNAME})

OUTDIR:=bin/
OBJDIR:=obj/
SRCDIR:=src

CFLAGS:=-Wall -Wextra
LDFLAGS:=

CONFIG?=release
OUTDIR:=${OUTDIR}${CONFIG}/
OBJDIR:=${OBJDIR}${CONFIG}/

ifeq (${CONFIG}, release)
CFLAGS:=-O3
else ifeq (${CONFIG}, debug)
CFLAGS:=-g
else
$(error Invalid CONFIG variable ${CONFIG})
endif

CXXFLAGS:=${CFLAGS}

INCLUDE=-Iinclude/ -Isrc/include/

OBJS:=$(patsubst %.c,%.o,$(wildcard ${SRCDIR}/*.c))
OBJS:=$(subst ${SRCDIR},${OBJDIR},${OBJS})

TESTDIR=tests

TESTINCLUDE=${INCLUDE} -I${TESTDIR} -I${TESTDIR}/testsuite

TESTOBJS:=$(patsubst %.cpp,%.o,$(wildcard ${TESTDIR}/*.cpp))
TESTOBJS:=$(subst ${TESTDIR},${OBJDIR}/${TESTDIR},${TESTOBJS})

ECHO=echo

.phony: all clean dir ${TARGET}-dynamic ${TARGET}-static test

all: compile_commands.json ${TARGET}-dynamic ${TARGET}-static test

${TARGET}-dynamic : ${OUTDIR}/lib${TARGET}.so
${TARGET}-static : ${OUTDIR}/lib${TARGET}.a
test: ${OUTDIR}tests
	@${ECHO} "Running Testsuite"
	@$< -n 1000

test-static: ${OUTDIR}tests-static
	@${ECHO} "Running Testsuite"
	@$< -n 1000

${OUTDIR}/lib${TARGET}.so : dir ${OBJS}
	@${ECHO} "Linking... lib${TARGET}.so"
	@${CC} ${LDFLAGS} -shared -o $@ ${OBJS}

${OUTDIR}/lib${TARGET}.a : dir ${OBJS}
	@${ECHO} "Linking... lib${TARGET}.a"
	@ar -crs $@ ${OBJS}

${OBJDIR}/%.o : ${SRCDIR}/%.c
	@${ECHO} "Compiling... $<"
	@${CC} ${CFLAGS} ${INCLUDE} -fpic $< -c -o $@ -MMD -MP -MF $@.d

${OUTDIR}tests : ${TARGET}-dynamic ${OBJDIR}/${TESTDIR}/testsuite.o ${TESTOBJS}
	@${ECHO} "Linking Testsuite"
	@${CXX} -o $@ ${LDFLAGS} ${TESTOBJS} ${OBJDIR}/${TESTDIR}/testsuite.o -L${OUTDIR} -l${TARGET} -Wl,--rpath=${OUTDIR}

${OUTDIR}tests-static : ${TARGET}-static ${OBJDIR}/${TESTDIR}/testsuite.o ${TESTOBJS}
	@${ECHO} "Linking Testsuite"
	@${CXX} -o $@ ${LDFLAGS} ${TESTOBJS} ${OBJDIR}/${TESTDIR}/testsuite.o ${OUTDIR}/lib${TARGET}.a


${OBJDIR}/${TESTDIR}/testsuite.o :
	@${ECHO} "Compiling Testsuite"
	@${CXX} ${CXXFLAGS} ${TESTINCLUDE} ${TESTDIR}/testsuite/tests.cpp -c -o $@ -MMD -MP -MF $@.d

${OBJDIR}/${TESTDIR}/%.o : ${TESTDIR}/%.cpp
	@${ECHO} "Compiling Test group... $<"
	@${CXX} ${CXXFLAGS} ${TESTINCLUDE} $< -c -o $@ -MMD -MP -MF $@.d

compile_commands.json : Makefile
	@${ECHO} "[" > $@
	@for obj in ${OBJS}; do \
		${ECHO} -n "{" >> $@ ; \
		${ECHO} "\t\"directory\": \""`pwd`"\", " >> $@ ; \
		${ECHO} -n "\t\"arguments\": [\""${CC}"\"," >> $@ ; \
		for flag in ${CFLAGS}; do \
			${ECHO} -n "\"$$flag\", " >> $@ ; \
		done ; \
		for inc in ${INCLUDE}; do \
			${ECHO} -n "\"$$inc\", " >> $@ ; \
		done ; \
		${ECHO} -n "\"-fpic\", \"" >> $@ ; \
		${ECHO} -n $$obj | sed -e 's/\.o/\.c/' -e 's@${OBJDIR}@${SRCDIR}@' >> $@; \
		${ECHO} -n "\", \"-c\", \"-o\", \""$$obj"\", \"-MMD\", \"-MP\", \"-MF\", \""$$obj".d\"" >> $@ ; \
		${ECHO} "]," >> $@ ; \
		${ECHO} -n "\t\"file\": \""`pwd`/"" >> $@; \
		${ECHO} -n $$obj | sed -e 's/\.o/\.c/' -e 's@${OBJDIR}@${SRCDIR}@' >> $@; \
		${ECHO} "\"," >> $@ ; \
		${ECHO} -n "\t\"output\": \""`pwd`/"" >> $@; \
		${ECHO} -n $$obj >> $@; \
		${ECHO} "\" },\n" >> $@ ; \
	done
	@${ECHO} "]" >> $@

dir:
	@mkdir -p ${OBJDIR}
	@mkdir -p ${OBJDIR}/${TESTDIR}
	@mkdir -p ${OUTDIR}

clean:
	@rm -rf ${OBJDIR}
	@rm -rf ${OUTDIR}

-include ${OBJDIR}/*.d
