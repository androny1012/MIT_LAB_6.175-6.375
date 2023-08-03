all: compile conflict pipeline bypass cfnc cf

compile:
	mkdir -p buildDir
	bsc -u -sim -bdir buildDir -info-dir buildDir -simdir buildDir -vdir buildDir -aggressive-conditions -keep-fires TestBench.bsv

conflict: compile
	bsc -sim -e mkTbConflictFunctional -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -o buildDir/simConflictFunctional

pipeline: compile
	bsc -sim -e mkTbPipelineFunctional -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -o buildDir/simPipelineFunctional
	bsc -sim -e mkTbPipelineScheduling -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -o buildDir/simPipelineScheduling

bypass: compile
	bsc -sim -e mkTbBypassFunctional -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -o buildDir/simBypassFunctional
	bsc -sim -e mkTbBypassScheduling -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -o buildDir/simBypassScheduling

cfnc: compile
	bsc -sim -e mkTbCFNCFunctional -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -o buildDir/simCFNCFunctional
	bsc -sim -e mkTbCFNCScheduling -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -o buildDir/simCFNCScheduling

cf: compile
	bsc -sim -e mkTbCFFunctional -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -o buildDir/simCFFunctional
	bsc -sim -e mkTbCFScheduling -bdir buildDir -info-dir buildDir -simdir buildDir -aggressive-conditions -keep-fires -o buildDir/simCFScheduling

clean:
	rm -rf buildDir

.PHONY: clean all compile conflict pipeline bypass cfnc cf
.DEFAULT_GOAL := all
