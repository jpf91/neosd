# Add include path for library
APP_INC += -I $(NEOSD_HOME)/sw/lib/include

# Compile all the sources
APP_SRC += $(NEOSD_HOME)/sw/lib/source/neosd_block.cpp \
    $(NEOSD_HOME)/sw/lib/source/neosd_dbg.cpp \
    $(NEOSD_HOME)/sw/lib/source/neosd_app.cpp \
	$(NEOSD_HOME)/sw/lib/source/neosd.cpp