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
platform active {front_ps}
platform generate
platform generate
platform active {front_ps}
domain active {zynq_fsbl}
bsp reload
bsp config stdin "none"
bsp config stdout "none"
bsp write
bsp reload
catch {bsp regenerate}
domain active {freertos10_xilinx_domain}
bsp reload
bsp config stdin "none"
bsp config stdout "none"
bsp write
bsp reload
catch {bsp regenerate}
platform generate -domains freertos10_xilinx_domain,zynq_fsbl 
domain create -name {standalone_0} -os {standalone} -proc {ps7_cortexa9_0} -arch {32-bit} -display-name {standalone_0} -desc {} -runtime {cpp}
platform generate -domains 
platform write
domain -report -json
bsp reload
bsp config stdin "none"
bsp config stdout "none"
bsp write
bsp reload
catch {bsp regenerate}
bsp setlib -name xilffs -ver 5.1
bsp write
bsp reload
catch {bsp regenerate}
domain active {zynq_fsbl}
bsp reload
domain active {standalone_0}
bsp setlib -name xilrsa -ver 1.7
bsp write
bsp reload
catch {bsp regenerate}
domain active {zynq_fsbl}
bsp write
domain active {standalone_0}
bsp write
platform generate -domains standalone_0 
platform config -updatehw {E:/Projects/sdr200/Soft/Z7010/PL/front_wrapper.xsa}
platform clean
platform generate
domain active {freertos10_xilinx_domain}
bsp reload
bsp write
platform clean
platform clean
platform generate
