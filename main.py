from myhdl import *
from pprint import pprint
from rhea.build.boards import get_board


def regfile(clk, we3, ra1, ra2, wa3, wd3, rd1, rd2):
    rf = [Signal(intbv(0)[32:])] * 32

    @always(clk.posedge)
    def write_port3():
        if we3:
            rf[int(wa3)].next = wd3

    @always_comb
    def read_port1():
        rd1.next = rf[int(ra1)] if ra1 != 0 else 0

    @always_comb
    def read_port2():
        rd2.next = rf[int(ra2)] if ra2 != 0 else 0

    return instances()


def adder(a, b, y):
    mask = (1 << 32) - 1

    @always_comb
    def logic():
        y.next = (a + b) & mask

    return instances()


def sl2(a, y):
    @always_comb
    def logic():
        y.next = concat(a[30:0], int('00', 2))

    return instances()


def signext(a, y):
    @always_comb
    def logic():
        y.next = concat((a[15],) * 16 + (a,))

    return instances()


def flopr(clk, reset, d, q):
    @always(clk.posedge, reset.posedge)
    def logic():
        q.next = 0 if reset else d

    return instances()


def mux2(d0, d1, s, y):
    @always_comb
    def logic():
        y.next = d1 if s else d0

    return instances()


ADD = int('010', 2)
SUB = int('110', 2)
AND = int('000', 2)
OR = int('001', 2)
SLT = int('111', 2)


def alu(a, b, alucontrol, y, zero):
    condinvb, sum = (Signal(intbv(0)[32:]),) * 2

    def logic():
        condinvb.next = ~b if alucontrol[2] else b
        sum.next = a + condinvb + alucontrol[2]

    @always_comb
    def logic():
        if alucontrol[2:0] == int('00', 2):
            y.next = a & b
        elif alucontrol[2:0] == int('01', 2):
            y.next = a | b
        elif alucontrol[2:0] == int('10', 2):
            y.next = sum
        elif alucontrol[2:0] == int('11', 2):
            y.next = concat(intbv(0)[30:], sum[31])

    @always_comb
    def calc_zero():
        zero.next = (y == 0)

    return instances()


def datapath(clk, reset, memtoreg, pcsrc, alusrc, regdst, regwrite, jump, alucontrol,
             zero, pc, instr, aluout, writedata, readdata):
    writereg = Signal(intbv(0)[5:])
    pcnext, pcnextbr, pcplus4, pcbranch = [Signal(intbv(0)[32:])] * 4
    signimm, signimmsh = [Signal(intbv(0)[32:])] * 2
    srca, srcb = [Signal(intbv(0)[32:])] * 2
    result = Signal(intbv(0)[32:])

    op_plus4 = Signal(intbv(int('100', 2))[32:])

    pcreg = flopr(clk, reset, pcnext, pc)
    pcadd1 = adder(pc, op_plus4, pcplus4)
    immsh = sl2(signimm, signimmsh)
    pcadd2 = adder(pcplus4, signimmsh, pcbranch)
    pcbrmux = mux2(pcplus4, pcbranch, pcsrc, pcnextbr)
    pcmux = mux2(pcnextbr, concat(pcplus4[32:28], instr[26:0], Signal(intbv('00')[2:])),
                 jump, pcnext)

    rf = regfile(clk, regwrite, instr[26:21], instr[21:16], writereg, result, srca, writedata)
    wrmux = mux2(instr[21:16], instr[16:11], regdst, writereg)
    resmux = mux2(aluout, readdata, memtoreg, result)
    se = signext(instr[16:0], signimm)

    srcbmux = mux2(writedata, signimm, alusrc, srcb)
    alu1 = alu(srca, srcb, alucontrol, aluout, zero)

    return instances()


def aludec(funct, aluop, alucontrol):
    @always_comb
    def logic():
        if aluop == 0:
            alucontrol.next = ADD
        elif aluop == 1:
            alucontrol.next = SUB
        else:
            if funct == int('100000', 2):
                alucontrol.next = ADD
            elif funct == int('100010', 2):
                alucontrol.next = SUB
            elif funct == int('100100', 2):
                alucontrol.next = AND
            elif funct == int('100101', 2):
                alucontrol.next = OR
            elif funct == int('101010', 2):
                alucontrol.next = SLT
            else:
                alucontrol.next = None

    return instances()


def maindec(op, memtoreg, memwrite, branch, alusrc, regdst, regwrte, jump, aluop):
    RTYPE = int('000000', 2)
    LW = int('100011', 2)
    SW = int('101011', 2)
    BEQ = int('000100', 2)
    ADDI = int('001000', 2)
    J = int('000010', 2)

    RTYPE_CTRL = int('110000010', 2)
    LW_CTRL = int('101001000', 2)
    SW_CTRL = int('001010000', 2)
    BEQ_CTRL = int('000100001', 2)
    ADDI_CTRL = int('101000000', 2)
    J_CTRL = int('000000100', 2)

    controls = Signal(intbv(0)[9:])

    @always_comb
    def logic():
        regwrte.next = controls[8]
        regdst.next = controls[7]
        alusrc.next = controls[6]
        branch.next = controls[5]
        memwrite.next = controls[4]
        memtoreg.next = controls[3]
        jump.next = controls[2]
        aluop.next = controls[2:0]

    @always_comb
    def op_decoder():
        if op == RTYPE:
            controls.next = RTYPE_CTRL
        elif op == LW:
            controls.next = LW_CTRL
        elif op == SW:
            controls.next = SW_CTRL
        elif op == BEQ:
            controls.next = BEQ_CTRL
        elif op == ADDI:
            controls.next = ADDI_CTRL
        elif op == J:
            controls.next = J_CTRL
        else:
            controls.next = None

    return instances()


def controller(op, funct, zero, memtoreg, memwrite, pcsrc, alusrc,
               regdst, regwrite, jump, alucontrol):
    aluop = Signal(intbv(0)[3])
    branch = Signal(bool(0))

    md = maindec(op, memtoreg, memwrite, branch, alusrc,
                 regdst, regwrite, jump, aluop)
    ad = aludec(funct, aluop, alucontrol)

    @always_comb
    def logic():
        pcsrc.next = branch & zero

    return instances()


def mips(clk, reset, pc, instr, memwrite, aluout, writedata, readdata):
    memtoreg, alusrc, regdst, regwrite, jump, pcsrc, zero = (Signal(bool(0)),) * 7
    alucontrol = Signal(intbv(0)[3:])

    op, funct = (Signal(intbv(0)[6:]),) * 2

    @always_comb
    def slice():
        op.next = instr[32:26]
        funct.next = instr[6:0]

    c = controller(op, funct, zero, memtoreg, memwrite, pcsrc,
                   alusrc, regdst, regwrite, jump, alucontrol)

    dp = datapath(clk, reset, memtoreg, pcsrc,
                  alusrc, regdst, regwrite, jump, alucontrol,
                  zero, pc, instr, aluout, writedata, readdata)

    return instances()


def dmem(clk, we, a, wd, rd):
    ram = [Signal(intbv(0)[32:])] * 64

    @always(clk.posedge)
    def write():
        if we:
            ram[int(a[32:2])].next = wd

    @always_comb
    def read():
        rd.next = ram[int(a[32:2])]

    return instances()


def imem(a, rd):
    rom = []

    filename = 'memfile.dat'
    file = open(filename, 'r')

    for i, line in enumerate(file.readlines()):
        rom.append(int(line, 16))
    file.close()

    @always_comb
    def logic():
        rd.next = rom[int(a)]

    return instances()


def top(clk, reset, writedata, dataadr, memwrite):
    pc, instr, readdata = (Signal(intbv(0)[32:]), ) * 3
    iadr = Signal(intbv(0)[6:])

    @always_comb
    def calc_iadr():
        iadr.next = pc[8:2]

    mips_inst = mips(clk, reset, pc, instr, memwrite, dataadr,
                     writedata, readdata)
    imem_inst = imem(iadr, instr)
    dmem_inst = dmem(clk, memwrite, dataadr, writedata, readdata)

    return instances()


def ticker(tick, clk, reset, num_intervals):
    max_clock_count = int(clk.frequency / num_intervals)
    count = Signal(intbv(0, min=0, max=max_clock_count))

    @always_seq(clk.posedge, reset=reset)
    def rtl():
        if count == max_clock_count - 1:
            count.next = 0
            tick.next = not tick
        else:
            count.next = count + 1

    return instances()


def blinker(led, clock, reset):
    num_leds = len(led)
    tick = Signal(bool(0))
    t = ticker(tick, clock, reset, 20)
    count = Signal(intbv(0, min=0, max=num_leds))

    @always_seq(tick.posedge, reset=reset)
    def rtl():
        count.next = 0 if count == num_leds - 1 else count + 1

    @always_comb
    def rtl_assign():
        for i in range(0, num_leds):
            led.next[i] = count == i

    return instances()


def compile_mojo():
    board = get_board('mojo')
    flow = board.get_flow(top=blinker)
    flow.run()
    utilization = flow.get_utilization()
    pprint(utilization)


if __name__ == '__main__':
    compile_mojo()
