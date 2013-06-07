#!/bin/bash


#...This script serves to test FigureGen and can be used each time changes are made to the code
#   As a failsafe to ensure the change did not disrput previous work. The file "Tests.txt" lists
#   each of the tests case. The code will check that a jpg is created, but cannot ensure the plot
#   appears correctly. This job still falls to human eyes.
#   This code will attempt to compile various instances of the code, so the flags below should
#   be altered for the appropriate machine setup.
FGSRC=FigureGen.F90
NOCLOBBER=1
machine=UND-athos

if [ $machine == "UND-athos" ] ; then
    FC="ifort"
    MPIFC="mpif90"
    FFLAGS="-xSSE4.2 -O3 -assume buffered_io -i-dynamic"
    MPIAVAIL=1
    MPIFLAGS="-DCMPI"
    NCAVAIL=1
    NCFLAGS="-DNETCDF"
    NCLIBS="-I/pscratch/zcobell/post_proc/NetCDF/NetCDF-4.2/include -L/pscratch/zcobell/post_proc/NetCDF/NetCDF-4.2/lib -lnetcdf -lnetcdff"
    MPIEXEC="mpirun"
    NPROC=12
    GMTLOC="/pscratch/zcobell/post_proc/GMT/GMT4.5.6/bin/"
    GSLOC="/usr/bin/"
else
    FC="gfortran"
    MPIFC="mpif90"
    FFLAGS="-O2"
    MPIAVAIL=0
    MPIFLAGS="-DCMPI"
    NCAVAIL=0
    NCFLAGS=""
    NCLIBS=""
    MPIEXEC=""
    NPROC=1
    GMTLOC=""
    GSLOC=""
fi

#...Lists of files we will need to locate for the tests
TestFileList=( fort.14 fort.13 maxele.63 fort.63 fort.74 )
TestFileListNC=( maxele.63.nc fort.63.nc fort.74.nc )

#...Cleaner function
if [ $# -gt 0 ] ; then
    if [ $1 == "clean" ] ; then
        rm -rf Output TEMP $FGSRC FigureGen_* *.mod
        exit 0
    fi
fi    


echo "!---------------------------------------!"
echo "!         FigureGen Testing             !"
echo "!            -Z. Cobell                 !"
echo "!                                       !"
echo "!---------------------------------------!"
echo ""
echo ""

#...Grab the most recent version (above) and compile it.
cp ../$FGSRC $FGSRC >/dev/null 2>/dev/null
if [ $? -ne 0 ] ; then
    echo "ERROR: Cannot locate source file."
    exit 1
fi 
echo "PASS - Found and retrieved the latest source."


#...Compile the various versions of FigureGen and check for errors
echo "BEGIN - COMPILE TESTS"

#...Serial w/o NetCDF
if [ -s FigureGen_NoNC_Serial ] ; then
    echo "    [1/4] SKIP - Serial FigureGen without NetCDF"
else    
    $FC $FGSRC $FFLAGS -o FigureGen_NoNC_Serial >/dev/null 2>/dev/null
    if [ $? -ne 0 ] ; then
        echo "    [1/4] ERROR: Cannot compile Serial FigureGen without NetCDF"
        exit 1
    fi    
    echo "    [1/4] PASS - Compiled Serial FigureGen without NetCDF"
fi

#...Serial w/ NetCDF
if [ $NCAVAIL == 1 ] ; then
    if [ -s FigureGen_NC_Serial ] ; then
        echo "    [2/4] SKIP - Serial FigureGen with NetCDF"
    else    
        $FC $FGSRC $FFLAGS $NCFLAGS $NCLIBS -o FigureGen_NC_Serial >/dev/null 2>/dev/null
        if [ $? -ne 0 ] ; then
            echo "    [2/4] ERROR: Cannot compile Serial FigureGen with NetCDF."
            exit 1
        fi    
        echo "    [2/4] PASS - Compiled Serial FigureGen with NetCDF"
    fi    
fi

#...Parallel w/o NetCDF
if [ $MPIAVAIL == 1 ] ; then
    if [ -s FigureGen_NoNC_Parallel ] ; then
        echo "    [3/4] SKIP - Parallel FigureGen without NetCDF"
    else    
        $MPIFC $FGSRC $FFLAGS $MPIFLAGS -o FigureGen_NoNC_Parallel >/dev/null 2>/dev/null
        if [ $? -ne 0 ] ; then
            echo "    [3/4] ERROR: Cannot compile Parallel Figuregen without NetCDF."
            exit 1
        fi    
        echo "    [3/4] PASS - Compiled Parallel FigureGen without NetCDF"
    fi    
fi

#...Parallel w/ NetCDF
if [ $MPIAVAIL == 1 -a $NCAVAIL == 1 ] ; then
    if [ -s FigureGen_NC_Parallel ] ; then
        echo "    [4/4] SKIP - Parallel FigureGen with NetCDF"
    else    
        $MPIFC $FGSRC $FFLAGS $MPIFLAGS $NCFLAGS $NCLIBS -o FigureGen_NC_Parallel >/dev/null 2>/dev/null
        if [ $? -ne 0 ] ; then
            echo "    [4/4] ERROR: Cannot compile Parallel Figuregen with NetCDF."
            exit 1
        fi    
        echo "    [4/4] PASS - Compiled Parallel FigureGen with NetCDF"
    fi    
fi

#...Clean
rm -f globalvar.mod

#...Pass all compile tests
echo "PASS - All compile tests completed sucessfully."

#...Make a directory for JPG file output
if [ ! -d Output ] ; then
    mkdir Output
fi

#...Now, search for all required base files
for FILE in ${TESTFILELIST[@]}
do
    if [ ! -s TestFiles/$FILE ] ; then
        echo "ERROR: Could not locate "$FILE
        exit 1
    fi
done    

if [ $NCAVAIL == 1 ] ; then
    for FILE in ${TESTFILELIST[@]}
    do
        if [ ! -s TestFiles/$FILE ] ; then
            echo "ERROR: Could not locate "$FILE
            exit 1
        fi
    done    
fi
echo "PASS - All test files located."

#...Now, we can begin the main testing loop.
#
#   The testing loop reads TestList.txt which contains one line for each test. The first 
#   value is the input file (*.inp), then the number of expected output files (integer), then
#   the expected output files.
IDX=0

echo "BEGIN - Plotting Tests"
for LINEIN in `cat TestList.txt`
do    
    #...Parse out the information from the line
    LINEINORIG=$LINEIN
    
    #...Check for empty line
    if [ -z $LINEINORIG ] ; then
        continue
    fi     
    
    #...Inform user of current test
    IDX=`echo $IDX + 1 | bc`
    echo "    BEGIN TEST $IDX"
    
    INPUTFILE=`echo $LINEIN | cut -d',' -f1`
    NFILES=`echo $LINEIN | cut -d',' -f2`
    for(( i = 1 ; i <= $NFILES ; i++ ))
    do
        delim=`echo $i + 2 | bc`
        OUTFILES[$i]=`echo $LINEIN | cut -d',' -f$delim`
    done

    #...Make a test directory inside the output directory
    if [ ! -d Output/Test$IDX ] ; then
        mkdir Output/Test$IDX
    fi    

    #...T E S T  1  O F  4

    #...Move into the testing directory
    if [ ! -d TEMP ] ; then
        mkdir TEMP
    else
        rm -rf TEMP
        mkdir TEMP
    fi
    cd TEMP

    #...Gather the files for a serial non-netcdf test
    ln -s ../TestFiles/* .
    ln -s ../FigureGen_NoNC_Serial FigureGen
    cp ../Tests/$INPUTFILE .
    GMTLOC=`echo "$GMTLOC" | perl -w -pe 's/\\/\\\\/g' 2>/dev/null`
    GSLOC=`echo "$GSLOC" | perl -w -pe 's/\\/\\\\/g' 2>/dev/null`
    perl -w -pi -e "s/<GMTLOC>/$GMTLOC/g" $INPUTFILE
    perl -w -pi -e "s/<GSLOC>/$GSLOC/g" $INPUTFILE
    ./FigureGen -I $INPUTFILE >/dev/null 2>/dev/null

    #...Check if the input file has NetCDF lines (search for *.nc)
    NCTST=`grep "\.nc" $INPUTFILE | wc -l`
    if [ $NCTST -gt 0 ] ; then
        ISNC=1
    else
        ISNC=0
    fi    
    
    #...Check output files
    error=0
    for(( i = 1 ; i <= $NFILES ; i++ ))
    do
        if [ ! -s ${OUTFILES[$i]} ] ; then
            error=1
        fi 
    done
    if [ $ISNC -eq 0 -a $error -eq 1 ] ; then
        echo "      [1/5] FAIL - Serial without NetCDF"
        cd ..
        if [ $NOCLOBBER != 1 ] ; then
            rm -rf TEMP
        fi    
        exit 1
    elif [ $ISNC -eq 1 -a $error -eq 1 ] ; then
        echo "      [1/5] FAIL - Serial without NetCDF (EXPECTED)"
        cd ..
        rm -rf TEMP
    else
        echo "      [1/5] PASS - Serial without NetCDF"
        for(( i = 1 ; i <= $NFILES ; i++ ))
        do    
            mv  ${OUTFILES[$i]} ../Output/Test$IDX/T1-${OUTFILES[$i]}
        done    
        cd ..
        rm -rf TEMP
    fi

    #...T E S T  2  O F  4

    #...Move into the testing directory
    if [ $NCAVAIL == 1 ] ; then
        if [ ! -d TEMP ] ; then
            mkdir TEMP
        else
            rm -rf TEMP
            mkdir TEMP
        fi
        cd TEMP

        #...Gather the files for a serial non-netcdf test
        ln -s ../TestFiles/* .
        ln -s ../FigureGen_NC_Serial FigureGen
        cp ../Tests/$INPUTFILE .
        perl -w -pi -e "s/<GMTLOC>/$GMTLOC/g" $INPUTFILE
        perl -w -pi -e "s/<GSLOC>/$GSLOC/g" $INPUTFILE
        ./FigureGen -I $INPUTFILE >/dev/null 2>/dev/null

        #...Check output files
        error=0
        for(( i = 1 ; i <= $NFILES ; i++ ))
        do
            if [ ! -s ${OUTFILES[$i]} ] ; then
                error=1
            fi 
        done
        if [ $error == 1 ] ; then
            echo "      [2/5] FAIL - Serial with NetCDF"
            cd ..
            if [ $NOCLOBBER != 1 ] ; then
                rm -rf TEMP
            fi    
            exit 1
        else
            echo "      [2/5] PASS - Serial with NetCDF"
            for(( i = 1 ; i <= $NFILES ; i++ ))
            do    
                mv  ${OUTFILES[$i]} ../Output/Test$IDX/T2-${OUTFILES[$i]}
            done    
            cd ..
            rm -rf TEMP
        fi
    else
        echo "       [2/5] SKIPPED - Serial NetCDF not available."
    fi

    #...T E S T  3  O F  4
    if [ $MPIAVAIL == 1 ] ; then
        if [ ! -d TEMP ] ; then
            mkdir TEMP
        else
            rm -rf TEMP
            mkdir TEMP
        fi
        cd TEMP

        #...Gather the files for a serial non-netcdf test
        ln -s ../TestFiles/* .
        ln -s ../FigureGen_NoNC_Parallel FigureGen
        cp ../Tests/$INPUTFILE .
        perl -w -pi -e "s/<GMTLOC>/$GMTLOC/g" $INPUTFILE
        perl -w -pi -e "s/<GSLOC>/$GSLOC/g" $INPUTFILE
        $MPIEXEC -np $NPROC ./FigureGen -I $INPUTFILE >/dev/null 2>/dev/null

        #...Check output files
        error=0
        for(( i = 1 ; i <= $NFILES ; i++ ))
        do
            if [ ! -s ${OUTFILES[$i]} ] ; then
                error=1
            fi 
        done
        if [ $ISNC -eq 0 -a $error -eq 1 ] ; then
            echo "      [3/4] FAIL - Parallel without NetCDF"
            cd ..
            if [ $NOCLOBBER != 1 ] ; then
                rm -rf TEMP
            fi    
            exit 1
        elif [ $ISNC -eq 1 -a $error -eq 1 ] ; then
            echo "      [3/5] FAIL - Parallel without NetCDF (EXPECTED)"
            cd ..
            rm -rf TEMP
        else
            echo "      [3/5] PASS - Parallel without NetCDF"
            for(( i = 1 ; i <= $NFILES ; i++ ))
            do    
                mv  ${OUTFILES[$i]} ../Output/Test$IDX/T3-${OUTFILES[$i]}
            done    
            cd ..
            rm -rf TEMP
        fi
    else    
        echo "      [3/5] SKIPPED - Parallel without NetCDF not available"
    fi

    #...T E S T  4  O F  4

    if [ $MPIAVAIL == 1 -a $NCAVAIL ] ; then
        if [ ! -d TEMP ] ; then
            mkdir TEMP
        else
            rm -rf TEMP
            mkdir TEMP
        fi
        cd TEMP

        #...Gather the files for a serial non-netcdf test
        ln -s ../TestFiles/* .
        ln -s ../FigureGen_NC_Parallel FigureGen
        cp ../Tests/$INPUTFILE .
        perl -w -pi -e "s/<GMTLOC>/$GMTLOC/g" $INPUTFILE
        perl -w -pi -e "s/<GSLOC>/$GSLOC/g" $INPUTFILE
        $MPIEXEC -np $NPROC ./FigureGen -I $INPUTFILE >/dev/null 2>/dev/null

        #...Check output files
        error=0
        for(( i = 1 ; i <= $NFILES ; i++ ))
        do
            if [ ! -s ${OUTFILES[$i]} ] ; then
                error=1
            fi 
        done
        if [ $error == 1 ] ; then
            echo "      [4/5] FAIL - Parallel with NetCDF"
            cd ..
            if [ $NOCLOBBER != 1 ] ; then
                rm -rf TEMP
            fi
            exit 1
        else
            echo "      [4/5] PASS - Parallel with NetCDF"
            for(( i = 1 ; i <= $NFILES ; i++ ))
            do    
                mv  ${OUTFILES[$i]} ../Output/Test$IDX/T4-${OUTFILES[$i]}
            done    
            cd ..
            rm -rf TEMP
        fi
    else    
        echo "      [4/5] SKIPPED - Parallel with NetCDF not available"
    fi

    #...Compute MD5SUM for each image generated to make sure images match. Hold serial version as Gold.
    cd Output/Test$IDX
    for(( i = 1 ; i <= $NFILES ; i++ ))
    do
        if [ -s T1-${OUTFILES[$i]} ] ; then
            MD5SUM1=`md5sum T1-${OUTFILES[$i]} | cut -d" " -f1`
        else
            MD5SUM1=`md5sum T2-${OUTFILES[$i]} | cut -d" " -f1` #...In the NetCDF plotting case, default to NetCDF-Serial
        fi    
        if [ $NCAVAIL == 1 ] ; then
            MD5SUM2=`md5sum T2-${OUTFILES[$i]} | cut -d" " -f1`
            if [ "$MD5SUM1" != "$MD5SUM2" ] ; then
                echo "ERROR - Inconsistant images constructed. Serial with NetCDF."
                exit 1
            fi
        fi
        if [ $MPIAVAIL == 1 -a $ISNC -eq 0 ] ; then
            MD5SUM2=`md5sum T3-${OUTFILES[$i]} | cut -d" " -f1`
            if [ "$MD5SUM1" != "$MD5SUM2" ] ; then
                echo "ERROR - Inconsistant images constructed. Parallel without NetCDF."
                exit 1
            fi
        fi
        if [ $MPIAVAIL == 1 -a $NCAVAIL == 1 ] ; then
            MD5SUM2=`md5sum T4-${OUTFILES[$i]} | cut -d" " -f1`
            if [ "$MD5SUM1" != "$MD5SUM2" ] ; then
                echo "ERROR - Inconsistant images constructed. Parallel with NetCDF."
                exit 1
            fi
        fi    
    done
    if [ $NCAVAIL == 0 -a $MPIAVAIL == 0 ] ; then
        echo "      [5/5] SKIP - Cannot compare MD5SUM with a single image."
    else    
        echo "      [5/5] PASS - Computed MD5SUM matches for all images."
    fi    
    cd ../..

done




