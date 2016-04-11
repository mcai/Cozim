Cozim README
===

Cozim is an FPGA based NoC Simulator written in SystemVerilog HDL.

Synthesis and downloading of Cozim to the Alinx AX301 board
---

* Download and Install Altera Quartus Prime from the Altera site.

* Open the Cozim project within Quartus Prime, and perform compilation and downloading processes.

TODOs
---
* unpacked vs packed? real? int? how to use?

* port assignment: use local variables or not?

* sequential logic or combinational logic?

* modelsim usage?

Hints
---

/home/itecgo/altera_lite/15.1/modelsim_ase/linux/vsim

sudo dpkg --add-architecture i386
sudo apt-get update

sudo apt-get install build-essential

sudo apt-get install gcc-multilib g++-multilib \
lib32z1 lib32stdc++6 lib32gcc1 \
expat:i386 fontconfig:i386 libfreetype6:i386 libexpat1:i386 libc6:i386 libgtk-3-0:i386 \
libcanberra0:i386 libpng12-0:i386 libice6:i386 libsm6:i386 libncurses5:i386 zlib1g:i386 \
libx11-6:i386 libxau6:i386 libxdmcp6:i386 libxext6:i386 libxft2:i386 libxrender1:i386 \
libxt6:i386 libxtst6:i386
