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
bsp reload
domain active {zynq_fsbl}
bsp reload
bsp config stdin "none"
bsp config stdout "none"
bsp write
bsp reload
catch {bsp regenerate}
bsp reload
domain active {freertos10_xilinx_domain}
bsp setlib -name lwip213 -ver 1.1
bsp setlib -name xilffs -ver 5.1
bsp setlib -name xilflash -ver 4.10
bsp config stdin "none"
bsp config stdout "axi_uartlite_2"
bsp config api_mode "SOCKET_API"
bsp write
bsp reload
catch {bsp regenerate}
platform generate
bsp reload
bsp config lwip_dhcp "true"
bsp write
bsp reload
catch {bsp regenerate}
platform generate -domains freertos10_xilinx_domain 
platform generate
platform active {StationVT}
