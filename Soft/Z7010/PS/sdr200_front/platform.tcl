# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct D:\projects\sdr200\Soft\Z7010\PS\sdr200_front\platform.tcl
# 
# OR launch xsct and run below command.
# source D:\projects\sdr200\Soft\Z7010\PS\sdr200_front\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {sdr200_front}\
-hw {D:\projects\sdr200\Soft\Z7010\PL\front_wrapper.xsa}\
-proc {ps7_cortexa9_0} -os {freertos10_xilinx} -out {D:/projects/sdr200/Soft/Z7010/PS}

platform write
platform generate -domains 
platform active {sdr200_front}
bsp reload
domain active {zynq_fsbl}
bsp reload
bsp config stdin "none"
bsp config stdout "none"
bsp write
bsp reload
catch {bsp regenerate}
domain active {freertos10_xilinx_domain}
bsp config stdin "none"
bsp config stdout "none"
bsp write
bsp reload
catch {bsp regenerate}
platform generate
