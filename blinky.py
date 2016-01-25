from myhdl import *
from pprint import pprint
from rhea.build.boards import get_board


def blinky(led, clock, reset=None):
    num_leds = len(led)
    max_count = int(clock.frequency)
    count = Signal(intbv(0, min=0, max=max_count))
    toggle = Signal(bool(0))

    @always_seq(clock.posedge, reset=reset)
    def rtl():
        if count == max_count - 1:
            count.next = 0
            toggle.next = not toggle
        else:
            count.next = count + 1

    @always_comb
    def rtl_assign():
        led.next[0] = toggle
        led.next[1] = not toggle
        for ii in range(2, num_leds):
            led.next[ii] = 0

    if reset is None:
        reset = ResetSignal(0, active=0, async=False)

        @always(clock.posedge)
        def rtl_reset():
            reset.next = not reset.active

        g = (rtl, rtl_assign, rtl_reset,)
    else:
        g = (rtl, rtl_assign,)

    return g


def compile_mojo():
    brd = get_board('mojo')
    flow = brd.get_flow(top=blinky)
    flow.run()
    info = flow.get_utilization()
    pprint(info)


if __name__ == '__main__':
    compile_mojo()
