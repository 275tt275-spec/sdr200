# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct D:\projects\sdr200\Soft\Z7020\PS\sdr\platform.tcl
# 
# OR launch xsct and run below command.
# source D:\projects\sdr200\Soft\Z7020\PS\sdr\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {sdr}\
-hw {D:\projects\sdr200\Soft\Z7020\PL\XC7Z020_wrapper.xsa}\
-proc {ps7_cortexa9_1} -os {standalone} -no-boot-bsp -out {D:/projects/sdr200/Soft/Z7020/PS}

platform write
platform generate -domains 
platform active {sdr}
bsp reload
bsp config stdin "none"
bsp config stdout "none"
bsp write
bsp reload
catch {bsp regenerate}
platform active {sdr}
platform generate
platform clean
platform generate
platform clean
platform generate
