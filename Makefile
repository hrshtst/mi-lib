.PHONY: all clean zeda zm zeo roki dzco liw zx11 neuz roki-fd roki-gl pedi2

all: zeda zm zeo roki dzco liw zx11 neuz roki-fd roki-gl pedi2

zeda:
	$(MAKE) -C zeda
	$(MAKE) -C zeda install
	$(MAKE) -C zeda test
	$(MAKE) -C zeda example

zm: zeda
	$(MAKE) -C zm
	$(MAKE) -C zm install
	$(MAKE) -C zm test
	$(MAKE) -C zm example

zeo: zeda zm
	$(MAKE) -C zeo
	$(MAKE) -C zeo install
	$(MAKE) -C zeo test
	$(MAKE) -C zeo example

roki: zeda zm zeo
	$(MAKE) -C roki
	$(MAKE) -C roki install
	$(MAKE) -C roki test
	$(MAKE) -C roki example

dzco: zeda zm
	$(MAKE) -C dzco
	$(MAKE) -C dzco install
	$(MAKE) -C dzco test
	$(MAKE) -C dzco example

liw: zeda
	$(MAKE) -C liw
	$(MAKE) -C liw install
	$(MAKE) -C liw test
	$(MAKE) -C liw example

zx11: zeda
	cd zx11 && sed -e "s/^CONFIG_USE_MAGICKWAND=y$$/CONFIG_USE_MAGICKWAND=n/" config.org > config
	$(MAKE) -C zx11
	$(MAKE) -C zx11 install
	$(MAKE) -C zx11 test
	$(MAKE) -C zx11 example

neuz: zeda zm
	$(MAKE) -C neuz
	$(MAKE) -C neuz install
	$(MAKE) -C neuz test
#	$(MAKE) -C neuz example

roki-fd: zeda zm zeo roki
	$(MAKE) -C roki-fd
	$(MAKE) -C roki-fd install
	$(MAKE) -C roki-fd test
	$(MAKE) -C roki-fd example

roki-gl: zeda zm zeo roki zx11
	cd roki-gl && sed -e "s/^CONFIG_USE_MAGICKWAND=y$$/CONFIG_USE_MAGICKWAND=n/" config.org > config
	$(MAKE) -C roki-gl
	$(MAKE) -C roki-gl install
	$(MAKE) -C roki-gl test
	$(MAKE) -C roki-gl example

pedi2: zeda zm dzco zeo roki roki-gl
	$(MAKE) -C pedi2
	$(MAKE) -C pedi2 install
#	$(MAKE) -C pedi2 test
	$(MAKE) -C pedi2 example

clean:
	$(MAKE) -C zeda clean
	$(MAKE) -C zm clean
	$(MAKE) -C zeo clean
	$(MAKE) -C roki clean
	$(MAKE) -C dzco clean
	$(MAKE) -C liw clean
	$(MAKE) -C zx11 clean
	$(MAKE) -C neuz clean || true
	$(MAKE) -C roki-fd clean
	$(MAKE) -C roki-gl clean
	$(MAKE) -C pedi2 clean
	cd pedi2/test && make clean
	rm -f ./*/include/*/*_export.h
	rm -rf .cache compile_commands.json
