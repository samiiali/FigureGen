#!/bin/bash

NCDIR = /org/groups/chg/CommonLibs/NetCDF/install

all: FigureGenZ.F90
	mpif90 FigureGenZ.F90 -DNETCDF -I$(NCDIR)/include -L$(NCDIR)/lib -lnetcdf -lnetcdff -o FigureGen
