# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct E:\Projects\sdr200\Soft\Z7010\PS\front_ps\platform.tcl
# 
# OR launch xsct and run below command.
# source E:\Projects\sdr200\Soft\Z7010\PS\front_ps\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {front_ps}\
-hw {E:\Projects\sdr200\Soft\Z7010\PL\front_wrapper.xsa}\
-proc {ps7_cortexa9_0} -os {freertos10_xilinx} -out {E:/Projects/sdr200/Soft/Z7010/PS}

platform write
platform generate -domains 
bsp reload
platform active {front_ps}
bsp reload
bsp config hypervisor_guest "false"
bsp config stdin "none"
bsp config stdout "none"
bsp config total_heap_size "262144"
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
platform generate
platform active {front_ps}
domain active {freertos10_xilinx_domain}
bsp reload
bsp reload
platform generate -domains 
platform active {front_ps}
platform config -updatehw {D:/projects/sdr200/Soft/Z7010/PL/front_wrapper.xsa}
platform clean
domain active {zynq_fsbl}
bsp reload
domain active {freertos10_xilinx_domain}
bsp reload
domain active {zynq_fsbl}
bsp reload
domain active {freertos10_xilinx_domain}
bsp reload
platform clean
platform generate
bsp reload
bsp reload
bsp reload
bsp reload
bsp reload
bsp reload
domain active {zynq_fsbl}
bsp reload
platform active {front_ps}
platform config -updatehw {D:/projects/sdr200/Soft/Z7010/PL/front_wrapper.xsa}
platform clean
platform generate
platform active {front_ps}
platform config -updatehw {D:/projects/sdr200/Soft/Z7010/PL/front_wrapper.xsa}
platform clean
platform generate
platform active {front_ps}
platform config -updatehw {D:/projects/sdr200/Soft/Z7010/PL/front_wrapper.xsa}
platform clean
platform generate
platform clean
platform generate
bsp reload
bsp reload
domain active {zynq_fsbl}
bsp reload
bsp reload
platform config -updatehw {D:/projects/sdr200/Soft/Z7010/PL/front_wrapper.xsa}
platform clean
platform generate
platform clean
platform generate
platform active {front_ps}
platform config -updatehw {D:/projects/sdr200/Soft/Z7010/PL/front_wrapper.xsa}
platform clean
platform generate
platform active {front_ps}
domain create -name {standalone_ps7_cortexa9_0} -display-name {standalone_ps7_cortexa9_0} -os {standalone} -proc {ps7_cortexa9_0} -runtime {cpp} -arch {32-bit} -support-app {zynq_fsbl}
platform generate -domains 
platform write
domain active {zynq_fsbl}
domain active {freertos10_xilinx_domain}
domain active {standalone_ps7_cortexa9_0}
platform generate -quick
bsp reload
bsp config stdin "ps7_coresight_comp_0"
bsp config stdout "ps7_coresight_comp_0"
bsp config stdin "none"
bsp write
bsp reload
catch {bsp regenerate}
platform generate -domains standalone_ps7_cortexa9_0 
