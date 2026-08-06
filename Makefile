.PHONY: all clean zeda zm zeo roki dzco liw zx11 neuz roki-fd roki-gl pedi2 pedi2-test pedi2-app

all: zeda zm zeo roki dzco liw zx11 neuz roki-fd roki-gl pedi2 pedi2-test pedi2-app

# Run as `make SKIP_CHECKS=1` to build and install only, without running
# each library's test and example targets (used by CI, where the tests
# of X11/OpenGL libraries cannot run headlessly).

zeda:
	$(MAKE) -C zeda
	$(MAKE) -C zeda install
ifndef SKIP_CHECKS
	$(MAKE) -C zeda test
	$(MAKE) -C zeda example
endif

zm: zeda
	$(MAKE) -C zm
	$(MAKE) -C zm install
ifndef SKIP_CHECKS
	$(MAKE) -C zm test
	$(MAKE) -C zm example
endif

zeo: zeda zm
	$(MAKE) -C zeo
	$(MAKE) -C zeo install
ifndef SKIP_CHECKS
	$(MAKE) -C zeo test
	$(MAKE) -C zeo example
endif

roki: zeda zm zeo
	$(MAKE) -C roki
	$(MAKE) -C roki install
ifndef SKIP_CHECKS
	$(MAKE) -C roki test
	$(MAKE) -C roki example
endif

dzco: zeda zm
	$(MAKE) -C dzco
	$(MAKE) -C dzco install
ifndef SKIP_CHECKS
	$(MAKE) -C dzco test
	$(MAKE) -C dzco example
endif

liw: zeda
	$(MAKE) -C liw
	$(MAKE) -C liw install
ifndef SKIP_CHECKS
	$(MAKE) -C liw test
	$(MAKE) -C liw example
endif

zx11: zeda
	cd zx11 && sed -e "s/^CONFIG_USE_MAGICKWAND=y$$/CONFIG_USE_MAGICKWAND=n/" config.org > config
	$(MAKE) -C zx11
	$(MAKE) -C zx11 install
ifndef SKIP_CHECKS
	$(MAKE) -C zx11 test
	$(MAKE) -C zx11 example
endif

neuz: zeda zm
	$(MAKE) -C neuz
	$(MAKE) -C neuz install
ifndef SKIP_CHECKS
	$(MAKE) -C neuz test
endif
#	$(MAKE) -C neuz example

roki-fd: zeda zm zeo roki
	$(MAKE) -C roki-fd
	$(MAKE) -C roki-fd install
ifndef SKIP_CHECKS
	$(MAKE) -C roki-fd test
	$(MAKE) -C roki-fd example
endif

roki-gl: zeda zm zeo roki zx11
	cd roki-gl && sed -e "s/^CONFIG_USE_MAGICKWAND=y$$/CONFIG_USE_MAGICKWAND=n/" config.org > config
	$(MAKE) -C roki-gl
	$(MAKE) -C roki-gl install
ifndef SKIP_CHECKS
	$(MAKE) -C roki-gl test
	$(MAKE) -C roki-gl example
endif

pedi2: zeda zm dzco zeo roki roki-gl
	$(MAKE) -C pedi2
	$(MAKE) -C pedi2 install
#	$(MAKE) -C pedi2 test
	$(MAKE) -C pedi2 example

pedi2-test: pedi2
	cd pedi2/test && if [ ! -d gtest ]; then unzip archive/gtest-1.7.0.zip && mv gtest-1.7.0 gtest; fi
	$(MAKE) -C pedi2/test

pedi2-app: pedi2
	$(MAKE) -C pedi2/app/dynmorph
	$(MAKE) -C pedi2/app/joystick

clean:
	$(MAKE) -C zeda clean || true
	$(MAKE) -C zm clean || true
	$(MAKE) -C zeo clean || true
	$(MAKE) -C roki clean || true
	$(MAKE) -C dzco clean || true
	$(MAKE) -C liw clean || true
	$(MAKE) -C zx11 clean || true
	$(MAKE) -C neuz clean || true
	$(MAKE) -C roki-fd clean || true
	$(MAKE) -C roki-gl clean || true
	$(MAKE) -C pedi2 clean || true
	cd pedi2/test && make clean || true
	$(MAKE) -C pedi2/app/dynmorph clean || true
	$(MAKE) -C pedi2/app/joystick clean || true
	rm -f ./*/include/*/*_export.h
	rm -rf .cache compile_commands.json
