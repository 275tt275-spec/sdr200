# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct D:\projects\sdr200\Soft\Z7020\PS\StationVT\platform.tcl
# 
# OR launch xsct and run below command.
# source D:\projects\sdr200\Soft\Z7020\PS\StationVT\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {StationVT}\
-hw {D:\projects\sdr200\Soft\Z7020\PL\XC7Z020_wrapper.xsa}\
-proc {ps7_cortexa9_0} -os {freertos10_xilinx} -out {D:/projects/sdr200/Soft/Z7020/PS}

platform write
platform generate -domains 
domain create -name {ps7_cortexa9_1} -os {standalone} -proc {ps7_cortexa9_1} -arch {32-bit} -display-name {ps7_cortexa9_1} -desc {} -runtime {cpp}
platform generate -domains 
platform write
domain -report -json
bsp reload
bsp config stdin "none"
bsp config stdout "none"
bsp write
bsp reload
catch {bsp regenerate}
domain active {zynq_fsbl}
bsp reload
bsp config stdin "none"
bsp config stdout "none"
bsp write
bsp reload
catch {bsp regenerate}
domain active {freertos10_xilinx_domain}
bsp reload
bsp setlib -name lwip213 -ver 1.1
bsp config stdin "none"
bsp config stdout "none"
bsp config api_mode "SOCKET_API"
bsp config lwip_dhcp "true"
bsp write
bsp reload
catch {bsp regenerate}
platform generate
domain active {ps7_cortexa9_1}
bsp reload
bsp config extra_compiler_flags "-mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -nostartfiles -g -Wall -Wextra -fno-tree-loop-distribute-patterns"
bsp config extra_compiler_flags "-mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -nostartfiles -g -Wall -Wextra -fno-tree-loop-distribute-patterns -DUSE_AMP1"
bsp config extra_compiler_flags "-mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -nostartfiles -g -Wall -Wextra -fno-tree-loop-distribute-patterns -DUSE_AMP=1"
bsp write
bsp reload
catch {bsp regenerate}
platform active {StationVT}
domain active {zynq_fsbl}
bsp reload
bsp reload
domain create -name {standalone_a9_0} -os {standalone} -proc {ps7_cortexa9_0} -arch {32-bit} -display-name {standalone_a9_0} -desc {} -runtime {cpp}
platform generate -domains 
platform write
domain -report -json
platform generate -domains standalone_a9_0,ps7_cortexa9_1 
platform active {StationVT}
domain active {zynq_fsbl}
bsp reload
domain active {freertos10_xilinx_domain}
bsp reload
bsp reload
platform active {StationVT}
platform config -updatehw {D:/projects/sdr200/Soft/Z7020/PL/XC7Z020_wrapper.xsa}
platform clean
platform generate
platform config -updatehw {D:/projects/sdr200/Soft/Z7020/PL/XC7Z020_wrapper.xsa}
platform clean
platform generate
