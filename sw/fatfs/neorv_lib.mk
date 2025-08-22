# Add include path for library
APP_INC += -I $(NEOSD_HOME)/sw/fatfs/source

# Compile all the sources
APP_SRC += $(NEOSD_HOME)/sw/fatfs/source/ff.c \
    $(NEOSD_HOME)/sw/fatfs/source/diskio.cpp