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
