# 确认没有多余的容器(有就删除)
    docker ps -a
    docker stop `docker ps -a| grep kazutoiris/connectal | awk '{print $1}' `
    docker rm   `docker ps -a| grep kazutoiris/connectal | awk '{print $1}' `

# 新建容器
    docker run -id kazutoiris/connectal

# 编译代码，检查语法错误
    mkdir buildDir
    bsc -u -sim -bdir buildDir -info-dir buildDir -simdir buildDir -vdir buildDir -p +:src/includes/ -aggressive-conditions -keep-fires src/WithCache.bsv
    bsc -u -sim -bdir buildDir -info-dir buildDir -simdir buildDir -vdir buildDir -p +:src/includes:src/ref:src -D CORE_NUM=2 -D VPROC=SIXSTAGE -aggressive-conditions -keep-fires src/Proc.bsv

# 编译BSC，得到模拟器(1-2分钟)
    ./docker_compile.sh

# 运行模拟器仿真(有BUG,有时候卡住,有时候1秒跑完,结果看log,simple要跑103条指令才对，如果错位就有问题)
<!-- (如果有BUG去掉命令的 > /dev/null 2>&1) -->
    ./run_asm.sh > /dev/null 2>&1
    ./run_bmarks.sh > /dev/null 2>&1
    ./run_mandelbrot.sh > /dev/null 2>&1
    ./run_excep.sh > /dev/null 2>&1
    ./run_permit.sh

    bluesim/bin/ubuntu.exe

    ./run_mc_no_atomic.sh > /dev/null 2>&1
    ./run_mc_all.sh > /dev/null 2>&1