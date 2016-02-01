rm -rf ./cozim
iverilog -o cozim source/simulator.v source/testbench.v
vvp ./cozim
gtkwave ./test.vcd