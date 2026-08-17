# Extra targets for the pedi2 custom library: its gtest suite and the
# application subdirectories, which pedi2's own makefile does not
# cover.
CUSTOM_EXTRA_TARGETS += pedi2-test pedi2-app
CUSTOM_EXTRA_CLEAN   += pedi2-clean-extra
.PHONY: pedi2-test pedi2-app pedi2-clean-extra

# The gtest suite links the C++ library variants (roki-config -lcpp,
# dzco-config -lcpp), so it must run after the CPP_LIBS pass.
pedi2-test: pedi2 $(CPP_TARGETS)
	cd pedi2/test && if [ ! -d gtest ]; then unzip archive/gtest-1.7.0.zip && mv gtest-1.7.0 gtest; fi
	$(LIBMK) pedi2/test
ifndef SKIP_CHECKS
	$(LIBMK) pedi2/test test
endif

pedi2-app: pedi2
	$(LIBMK) pedi2/app/dynmorph
	$(LIBMK) pedi2/app/joystick

pedi2-clean-extra:
	$(LIBMK) pedi2/test clean || true
	$(LIBMK) pedi2/app/dynmorph clean || true
	$(LIBMK) pedi2/app/joystick clean || true
