rm -Rf xilinx
. /home/itecgo/Tools/FPGA/Xilinx/14.7/ISE_DS/settings64.sh
python ./blinky.py
python ./mojo.py -i xilinx/mojov3.bin -r -v -d /dev/ttyACM0
