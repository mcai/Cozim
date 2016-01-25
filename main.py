from myhdl import *
from pprint import pprint
from rhea.build.boards import get_board


def Ticker(tick, clock, reset, num_intervals):
    max_clock_count = int(clock.frequency / num_intervals)
    count = Signal(intbv(0, min=0, max=max_clock_count))

    @always_seq(clock.posedge, reset=reset)
    def rtl():
        if count == max_clock_count - 1:
            count.next = 0
            tick.next = not tick
        else:
            count.next = count + 1

    return rtl


def Blinker(led, clock, reset):
    num_leds = len(led)
    tick = Signal(bool(0))

    ticker = Ticker(tick, clock, reset, 20)

    count = Signal(intbv(0, min=0, max=num_leds))

    @always_seq(tick.posedge, reset=reset)
    def rtl():
        if count == num_leds - 1:
            count.next = 0
        else:
            count.next = count + 1

    @always_comb
    def rtl_assign():
        for i in range(0, num_leds):
            led.next[i] = count == i

    return ticker, rtl, rtl_assign


def compile_mojo():
    brd = get_board('mojo')
    flow = brd.get_flow(top=Blinker)
    flow.run()
    info = flow.get_utilization()
    pprint(info)


if __name__ == '__main__':
    compile_mojo()
