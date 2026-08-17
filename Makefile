# Configuration is read from config.default (+ optional config.local)
# through load_config.sh; see config.default for the variables.
UPSTREAM_LIBS   := $(shell ./load_config.sh --get UPSTREAM_LIBS)
CUSTOM_LIB      := $(shell ./load_config.sh --get CUSTOM_LIB)
CUSTOM_LIB_DEPS := $(shell ./load_config.sh --get CUSTOM_LIB_DEPS)
PREFIX          := $(shell ./load_config.sh --get PREFIX)

ALL_LIBS := $(UPSTREAM_LIBS) $(CUSTOM_LIB)

# Builds need $(PREFIX)/bin on PATH (<lib>-config, zeda-makefile-gen,
# zeda-chkdep) and $(PREFIX)/lib on LD_LIBRARY_PATH (tests), even
# without direnv.
export PATH := $(PREFIX)/bin:$(PATH)
ifeq ($(LD_LIBRARY_PATH),)
export LD_LIBRARY_PATH := $(PREFIX)/lib
else
export LD_LIBRARY_PATH := $(PREFIX)/lib:$(LD_LIBRARY_PATH)
endif

# Sub-make driver: the command-line PREFIX rides MAKEFLAGS down into
# the generated library makefiles and overrides each library's own
# config file.
LIBMK = $(MAKE) PREFIX=$(PREFIX) -C

# The <lib>-config tools bake PREFIX in at generation time and are not
# regenerated while present, so building over the artifacts of a
# different prefix requires a clean first.
PREFIX_STAMP := .milib-prefix
LAST_PREFIX := $(shell cat $(PREFIX_STAMP) 2>/dev/null)
ifeq ($(filter clean,$(MAKECMDGOALS)),)
ifneq ($(LAST_PREFIX),)
ifneq ($(LAST_PREFIX),$(PREFIX))
$(error PREFIX changed ($(LAST_PREFIX) -> $(PREFIX)); run 'make clean' first)
endif
endif
endif

.PHONY: all clean prefix-dirs zeda zm zeo roki dzco liw zx11 neuz roki-fd roki-gl $(CUSTOM_LIB)

all: $(ALL_LIBS)

# Run as `make SKIP_CHECKS=1` to build and install only, without
# running each library's test and example targets (used by CI, where
# the tests of X11/OpenGL libraries cannot run headlessly).
# Run as `make SKIP_CPP=1` to skip the C++ variant pass of the
# CPP_LIBS libraries during quick iterations; a normal `make` remains
# the source of truth.

prefix-dirs:
	@mkdir -p $(PREFIX)/bin $(PREFIX)/lib $(PREFIX)/include
	@echo $(PREFIX) > $(PREFIX_STAMP)

zeda zm zeo roki dzco liw zx11 neuz roki-fd roki-gl $(CUSTOM_LIB): prefix-dirs

# The static dependency graph of the upstream libraries. Rules for
# libraries not listed in UPSTREAM_LIBS are harmless; UPSTREAM_LIBS
# must be closed under these dependencies.

zeda:
	$(LIBMK) zeda
	$(LIBMK) zeda install
ifndef SKIP_CHECKS
	$(LIBMK) zeda test
	$(LIBMK) zeda example
endif

zm: zeda
	$(LIBMK) zm
	$(LIBMK) zm install
ifndef SKIP_CHECKS
	$(LIBMK) zm test
	$(LIBMK) zm example
endif

zeo: zeda zm
	$(LIBMK) zeo
	$(LIBMK) zeo install
ifndef SKIP_CHECKS
	$(LIBMK) zeo test
	$(LIBMK) zeo example
endif

roki: zeda zm zeo
	$(LIBMK) roki
	$(LIBMK) roki install
ifndef SKIP_CHECKS
	$(LIBMK) roki test
	$(LIBMK) roki example
endif

dzco: zeda zm
	$(LIBMK) dzco
	$(LIBMK) dzco install
ifndef SKIP_CHECKS
	$(LIBMK) dzco test
	$(LIBMK) dzco example
endif

liw: zeda
	$(LIBMK) liw
	$(LIBMK) liw install
ifndef SKIP_CHECKS
	$(LIBMK) liw test
	$(LIBMK) liw example
endif

zx11: zeda
	cd zx11 && sed -e "s/^CONFIG_USE_MAGICKWAND=y$$/CONFIG_USE_MAGICKWAND=n/" config.org > config
	$(LIBMK) zx11
	$(LIBMK) zx11 install
ifndef SKIP_CHECKS
	$(LIBMK) zx11 test
	$(LIBMK) zx11 example
endif

neuz: zeda zm
	$(LIBMK) neuz
	$(LIBMK) neuz install
ifndef SKIP_CHECKS
	$(LIBMK) neuz test
endif
#	$(LIBMK) neuz example

roki-fd: zeda zm zeo roki
	$(LIBMK) roki-fd
	$(LIBMK) roki-fd install
ifndef SKIP_CHECKS
	$(LIBMK) roki-fd test
	$(LIBMK) roki-fd example
endif

roki-gl: zeda zm zeo roki zx11 liw
	cd roki-gl && sed -e "s/^CONFIG_USE_MAGICKWAND=y$$/CONFIG_USE_MAGICKWAND=n/" config.org > config
	$(LIBMK) roki-gl
	$(LIBMK) roki-gl install
ifndef SKIP_CHECKS
	$(LIBMK) roki-gl test
	$(LIBMK) roki-gl example
endif

# C++ variants: each library in CPP_LIBS is rebuilt with CC=g++ into
# lib<name>_cpp.so after its C build (the <lib>-config tools advertise
# them via -lcpp). The generated makefiles compile objects in place,
# shared between compilers, so both passes must start from clean
# objects — these libraries always rebuild from scratch.
CPP_LIBS := $(shell ./load_config.sh --get CPP_LIBS)
ifndef SKIP_CPP
CPP_TARGETS := $(addsuffix -cpp,$(CPP_LIBS))
else
CPP_TARGETS :=
endif

ifneq ($(CPP_TARGETS),)
.PHONY: $(CPP_TARGETS)
all: $(CPP_TARGETS)
# `$(LIBMK) $* lib` would silently no-op: the clone makefiles have no
# `lib` target and the lib/ directory satisfies it — drive src/
# directly instead.
$(CPP_TARGETS): %-cpp: %
	$(LIBMK) $*/src clean
	$(LIBMK) $*/src CC=g++
	$(LIBMK) $* install
	$(LIBMK) $*/src clean
endif

ifneq ($(CUSTOM_LIB),)
# Generic rule for the configured custom library. Extra targets may be
# provided by mk/$(CUSTOM_LIB).mk, which can append phony targets to
# CUSTOM_EXTRA_TARGETS (joined into `all`) and CUSTOM_EXTRA_CLEAN
# (joined into `clean`).
$(CUSTOM_LIB): $(CUSTOM_LIB_DEPS)
	$(LIBMK) $(CUSTOM_LIB)
	$(LIBMK) $(CUSTOM_LIB) install
ifndef SKIP_CHECKS
	$(LIBMK) $(CUSTOM_LIB) example
endif

-include mk/$(CUSTOM_LIB).mk
all: $(CUSTOM_EXTRA_TARGETS)
clean: $(CUSTOM_EXTRA_CLEAN)
endif

clean:
	for l in $(ALL_LIBS); do $(LIBMK) $$l clean || true; done
	rm -f ./*/include/*/*_export.h
	rm -rf .cache compile_commands.json $(PREFIX_STAMP)
